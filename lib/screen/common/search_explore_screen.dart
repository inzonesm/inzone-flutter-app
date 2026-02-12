import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/profile/avatar_story_component.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:inzone/screen/common/characters_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Search Session Tracker
class SearchSessionTracker {
  static final Map<String, DateTime> _sessionStartTimes = {};
  static final Map<String, List<String>> _sessionQueries = {};
  static final Map<String, int> _sessionResultClicks = {};
  static final Map<String, Set<String>> _sessionCategories = {};

  static void startSession(String userId) {
    final sessionId = _generateSessionId(userId);
    _sessionStartTimes[sessionId] = DateTime.now();
    _sessionQueries[sessionId] = [];
    _sessionResultClicks[sessionId] = 0;
    _sessionCategories[sessionId] = <String>{};
  }

  static void trackQuery(
      String userId, String query, int resultCount, String category) {
    final sessionId = _generateSessionId(userId);
    _sessionQueries[sessionId]?.add(query);
    _sessionCategories[sessionId]?.add(category);

    // Track individual search query
    AppsFlyerService().trackSearchQuery(
      query: query,
      userId: userId,
      resultCount: resultCount,
      category: category,
    );
  }

  static void trackResultClick(
      String userId, String query, int resultIndex, String contentType) {
    final sessionId = _generateSessionId(userId);
    _sessionResultClicks[sessionId] =
        (_sessionResultClicks[sessionId] ?? 0) + 1;

    // Track search result interaction
    AppsFlyerService().logEvent('search_result_clicked', {
      'user_id': userId,
      'search_query': query,
      'result_index': resultIndex,
      'content_type': contentType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static void endSession(String userId) {
    final sessionId = _generateSessionId(userId);
    final startTime = _sessionStartTimes[sessionId];

    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inSeconds;
      final queries = _sessionQueries[sessionId] ?? [];
      final clicks = _sessionResultClicks[sessionId] ?? 0;
      final categories = _sessionCategories[sessionId] ?? <String>{};

      if (duration > 5 && queries.isNotEmpty) {
        AppsFlyerService().logEvent('search_session_summary', {
          'user_id': userId,
          'session_duration_sec': duration,
          'total_searches': queries.length,
          'total_result_clicks': clicks,
          'unique_categories_searched': categories.length,
          'search_queries': queries.join('|'),
          'categories_explored': categories.join(','),
          'click_through_rate':
              queries.isNotEmpty ? clicks / queries.length : 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Clean up session data
      _sessionStartTimes.remove(sessionId);
      _sessionQueries.remove(sessionId);
      _sessionResultClicks.remove(sessionId);
      _sessionCategories.remove(sessionId);
    }
  }

  static String _generateSessionId(String userId) {
    return '${userId}_${DateTime.now().day}';
  }
}

class SearchExploreScreen extends StatefulWidget {
  const SearchExploreScreen({super.key});

  @override
  State<SearchExploreScreen> createState() => _SearchExploreScreenState();
}

class _SearchExploreScreenState extends State<SearchExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool isLoading = true;
  bool isSearching = false;
  bool isSearchLoading = false;
  String searchQuery = '';
  List<InZoneAvatar> avatars = [];
  List<AvatarCard> avatarCards = [];
  List<AvatarStoryComponent> avatarStoryComponents = [];
  List<InZonePost> recommendedPosts = [];
  List<InZonePost> searchResults = [];
  List<String> searchHistory = [];

  // Search analytics tracking
  late DateTime _screenStartTime;
  late String _currentUserId;
  int _totalSearches = 0;
  int _totalResultClicks = 0;
  final Set<String> _uniqueQueries = <String>{};
  String _lastSearchQuery = '';

  Timer? _debounce;

  static const String searchHistoryKey = 'search_history';

  @override
  void initState() {
    super.initState();

    // Initialize search analytics
    _screenStartTime = DateTime.now();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    // Start search session tracking
    SearchSessionTracker.startSession(_currentUserId);

    // Track search screen session start
    AppsFlyerService().logEvent('search_screen_session_start', {
      'user_id': _currentUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _loadInitialData();
    try {
      _loadSearchHistory();
    } catch (e) {
      debugPrint('Error loading search history: $e');
    }
  }

  @override
  void dispose() {
    SearchSessionTracker.endSession(_currentUserId);

    final sessionDuration =
        DateTime.now().difference(_screenStartTime).inSeconds;

    if (sessionDuration > 5) {
      AppsFlyerService().logEvent('search_screen_session_end', {
        'user_id': _currentUserId,
        'session_duration_sec': sessionDuration,
        'total_searches_performed': _totalSearches,
        'total_result_clicks': _totalResultClicks,
        'unique_queries_searched': _uniqueQueries.length,
        'search_efficiency':
            _totalSearches > 0 ? _totalResultClicks / _totalSearches : 0,
        'last_search_query': _lastSearchQuery,
        'search_abandon_rate': _calculateSearchAbandonRate(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Track search discovery patterns
      AppsFlyerService().logEvent('search_discovery_patterns', {
        'user_id': _currentUserId,
        'search_frequency':
            _totalSearches / (sessionDuration / 60), // searches per minute
        'query_diversity':
            _uniqueQueries.length / (_totalSearches.clamp(1, 100)),
        'engagement_depth':
            _totalResultClicks / (sessionDuration / 60), // clicks per minute
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  double _calculateSearchAbandonRate() {
    if (_totalSearches == 0) return 0.0;
    final searchesWithoutClicks = _totalSearches - _totalResultClicks;
    return searchesWithoutClicks / _totalSearches;
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(searchHistoryKey);
      if (history != null && mounted) {
        setState(() {
          searchHistory = history;
        });
      }
    } catch (e) {
      debugPrint('Error loading search history: $e');
      if (mounted) {
        setState(() {
          searchHistory = [];
        });
      }
    }
  }

  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(searchHistoryKey, searchHistory);
    } catch (e) {
      debugPrint('Error saving search history: $e');
    }
  }

  Future<void> _clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(searchHistoryKey);
      if (mounted) {
        setState(() {
          searchHistory.clear();
        });
      }
    } catch (e) {
      debugPrint('Error clearing search history: $e');
    }
  }

  Future<void> _removeSearchHistoryItem(int index) async {
    if (index >= 0 && index < searchHistory.length) {
      setState(() {
        searchHistory.removeAt(index);
      });
      await _saveSearchHistory();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final characters = await InZoneDatabase.getCarouselCharacters();
      if (characters != null && mounted) {
        _processAvatars(characters);
      }

      final response = await InZoneDatabase.getFeed();
      if (response != null && response['posts'] != null && mounted) {
        List<dynamic> posts = response['posts'];
        setState(() {
          recommendedPosts =
              posts.map((post) => InZonePost.fromJson(post)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _processAvatars(List<dynamic> fetchedCharacters) {
    avatarCards.clear();
    avatarStoryComponents.clear();
    try {
      for (var characterData in fetchedCharacters) {
        InZoneAvatar avatar = InZoneAvatar.fromDirectJson(characterData);
        avatarCards.add(AvatarCard(avatar: avatar));
        avatarStoryComponents.add(AvatarStoryComponent(avatar: avatar));
      }
      setState(() {
        avatarCards.shuffle();
        avatarStoryComponents.shuffle();
      });
    } catch (e) {
      debugPrint('Error processing avatars: $e');
    }
  }

  void _onSearchTextChanged(String text) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    if (text.trim().isEmpty) {
      setState(() {
        isSearching = false;
        isSearchLoading = false;
        searchResults.clear();
        searchQuery = '';
      });
      return;
    }

    setState(() {
      isSearchLoading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 700), () {
      _performSearch(text);
    });
  }

  void _onSearchSubmitted(String text) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    if (text.trim().isNotEmpty) {
      setState(() {
        isSearchLoading = true;
      });

      AppsFlyerService().logEvent('search_submitted', {
        'user_id': _currentUserId,
        'query': text.trim(),
        'submission_method': 'enter_key',
        'query_length': text.trim().length,
        'session_search_count': _totalSearches + 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      _performSearch(text);
    }
  }

  Future<List<InZonePost>> _searchPostsApi(String query, {int k = 20}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url =
          'https://ai-apis-912424781531.us-east1.run.app/search/posts?keywords=$encodedQuery&k=$k';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("API search response: $data");

        if (data != null && data['results'] != null) {
          return (data['results'] as List).map((result) {
            final postData = result['post'];
            final id = result['id'] as String;
            final String userName = result['user_name'] ?? 'AI User';
            final String userId = result['user_id'] ?? 'unknown_user';
            final collection = result['collection'] as String? ?? 'General';
            
            final textContent = postData['text_content'] ?? '';
            final imageContent =
                List<String>.from(postData['image_content'] ?? []);
            final videoContent =
                List<String>.from(postData['video_content'] ?? []);

            return InZonePost(
              id: id,
              userName: userName,
              comments: [],
              datePosted: DateTime.now().toUtc(),
              likes: 0,
              textContent: textContent,
              imageContent: imageContent,
              videoContent: videoContent,
              userReference: userId, // Use the actual user_id instead of hardcoded 'ai_user'
              category: collection,
              mainCategory: collection,
              isAi: collection == 'aiPosts',
            );
          }).toList();
        }
      }

      debugPrint('API search error: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Exception during API search: $e');
      return [];
    }
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        isSearching = false;
        isSearchLoading = false;
        searchResults.clear();
        searchQuery = '';
      });
      return;
    }

    // Update search analytics
    _totalSearches++;
    _uniqueQueries.add(query.trim());
    _lastSearchQuery = query.trim();

    setState(() {
      searchHistory.remove(query);
      searchHistory.insert(0, query);
      if (searchHistory.length > 5) {
        searchHistory.removeLast();
      }

      isSearching = true;
      isSearchLoading = true;
      searchQuery = query;
    });

    final searchStartTime = DateTime.now();

    final results = await _searchPostsApi(query);

    final searchDuration =
        DateTime.now().difference(searchStartTime).inMilliseconds;

    if (mounted) {
      setState(() {
        searchResults = results;
        isSearchLoading = false;
      });
    }

    // Track search query and results
    SearchSessionTracker.trackQuery(
        _currentUserId, query.trim(), results.length, 'posts');

    // Track detailed search analytics
    AppsFlyerService().logEvent('search_completed', {
      'user_id': _currentUserId,
      'query': query.trim(),
      'result_count': results.length,
      'search_duration_ms': searchDuration,
      'query_length': query.trim().length,
      'has_results': results.isNotEmpty,
      'session_search_number': _totalSearches,
      'unique_queries_so_far': _uniqueQueries.length,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Track search quality metrics
    if (results.isEmpty) {
      AppsFlyerService().logEvent('search_no_results', {
        'user_id': _currentUserId,
        'failed_query': query.trim(),
        'query_length': query.trim().length,
        'session_search_number': _totalSearches,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      AppsFlyerService().logEvent('search_success', {
        'user_id': _currentUserId,
        'successful_query': query.trim(),
        'result_count': results.length,
        'search_effectiveness': results.length > 10
            ? 'high'
            : results.length > 5
                ? 'medium'
                : 'low',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    _saveSearchHistory();
  }

  void _clearSearch() {
    if (searchQuery.isNotEmpty) {
      AppsFlyerService().logEvent('search_cleared', {
        'user_id': _currentUserId,
        'cleared_query': searchQuery,
        'had_results': searchResults.isNotEmpty,
        'result_count': searchResults.length,
        'session_search_count': _totalSearches,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    _searchController.clear();

    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    setState(() {
      isSearching = false;
      isSearchLoading = false;
      searchQuery = '';
      searchResults.clear();
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColorfulSafeArea(
        topColor: Theme.of(context).canvasColor,
        left: false,
        right: false,
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Top search bar and back button
            Padding(
              padding: const EdgeInsets.only(
                  top: 8.0, left: 8.0, right: 16.0, bottom: 8.0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        if (_searchFocusNode.hasFocus) {
                          _searchFocusNode.unfocus();
                          _clearSearch();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: Theme.of(context).cardColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_ios,
                              size: 18,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      cursorColor:
                          Theme.of(context).textTheme.bodyMedium?.color,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        suffixIcon: isSearchLoading
                            ? Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: _clearSearch,
                                    splashRadius: 16,
                                  )
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                      ),
                      onChanged: _onSearchTextChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearchSubmitted,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? SearchLoading(context)
                  : isSearching
                      ? _buildSearchResults()
                      : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (isSearchLoading) {
      return SearchResultsLoading(context);
    }

    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No results found for "$searchQuery"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: GestureDetector(
            onTap: () {
              // Track search result click
              _totalResultClicks++;
              SearchSessionTracker.trackResultClick(
                _currentUserId,
                searchQuery,
                index,
                'post',
              );

              AppsFlyerService().logEvent('search_result_interaction', {
                'user_id': _currentUserId,
                'search_query': searchQuery,
                'result_position': index + 1,
                'content_type': 'post',
                'content_id': searchResults[index].id,
                'interaction_type': 'view',
                'session_click_number': _totalResultClicks,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
            },
            child: PostCard(
              post: searchResults[index],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        // Characters Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Characters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      // Navigate to characters screen
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const CharactersScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Text(
                        'More',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Use AvatarStoryComponent instead of custom implementation
        SliverToBoxAdapter(
          child: avatarStoryComponents.isNotEmpty
              ? _buildAvatarStories()
              : const SizedBox.shrink(),
        ),

        // Search History Section
        if (searchHistory.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                  left: 16, right: 16, bottom: searchHistory.isEmpty ? 8 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (searchHistory.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _clearSearchHistory();
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        if (searchHistory.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.history, size: 18),
                  title: Text(
                    searchHistory[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    // Track search history interaction
                    AppsFlyerService().logEvent('search_history_clicked', {
                      'user_id': _currentUserId,
                      'clicked_query': searchHistory[index],
                      'history_position': index + 1,
                      'session_search_count': _totalSearches,
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    });

                    _searchController.text = searchHistory[index];
                    _performSearch(searchHistory[index]);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _removeSearchHistoryItem(index);
                    },
                  ),
                );
              },
              childCount: searchHistory.length,
            ),
          ),

        // Recommended Posts Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Recommended Posts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index < recommendedPosts.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: PostCard(
                    post: recommendedPosts[index],
                  ),
                );
              }
              return null;
            },
            childCount: recommendedPosts.length,
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

  Widget _buildAvatarStories() {
    return SizedBox(
      height: 130,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: avatarStoryComponents,
          ),
        ),
      ),
    );
  }
}
