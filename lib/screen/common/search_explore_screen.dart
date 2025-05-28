import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/profile/avatar_story_component.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:inzone/router/routes.dart';
import 'package:inzone/screen/common/characters_screen.dart';

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

  // 디바운스 타이머
  Timer? _debounce;

  // 최근 검색어 저장 키
  static const String searchHistoryKey = 'search_history';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // SharedPreferences 문제가 발생하지 않도록 예외 처리와 함께 호출
    try {
      _loadSearchHistory();
    } catch (e) {
      debugPrint('Error loading search history: $e');
    }
  }

  // 저장된 검색 기록 불러오기
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
      // 실패한 경우 빈 리스트로 초기화
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

  // 검색 기록 전체 삭제
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
      // Load characters
      final characters = await InZoneDatabase.getCarouselCharacters();
      if (characters != null && mounted) {
        _processAvatars(characters);
      }

      // Load recommended posts
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
        // Use the new factory method
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

  // 텍스트 변경 시 디바운스 처리
  void _onSearchTextChanged(String text) {
    // 이전 타이머가 있으면 취소
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    // 검색어가 비어있으면 바로 결과 초기화
    if (text.trim().isEmpty) {
      setState(() {
        isSearching = false;
        isSearchLoading = false;
        searchResults.clear();
        searchQuery = '';
      });
      return;
    }

    // 검색 로딩 상태 활성화
    setState(() {
      isSearchLoading = true;
    });

    // 검색어가 있으면 타이머 시작 (700ms)
    _debounce = Timer(const Duration(milliseconds: 700), () {
      // 타이머가 끝나면 검색 실행
      _performSearch(text);
    });
  }

  // 엔터 키 또는 검색 버튼 클릭 시
  void _onSearchSubmitted(String text) {
    // 이미 활성화된 타이머가 있으면 취소
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    // 검색어가 비어있지 않으면 로딩 상태 활성화
    if (text.trim().isNotEmpty) {
      setState(() {
        isSearchLoading = true;
      });

      // 바로 검색 실행
      _performSearch(text);
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        isSearching = false;
        isSearchLoading = false;
        searchResults.clear();
        searchQuery = '';
      });
      return;
    }

    // 검색어 추가 및 중복 제거 (같은 검색어는 맨 앞으로 이동)
    setState(() {
      // 기존 항목이 있으면 제거
      searchHistory.remove(query);
      // 새로운 항목을 맨 앞에 추가
      searchHistory.insert(0, query);
      // 최대 5개까지만 유지
      if (searchHistory.length > 5) {
        searchHistory.removeLast();
      }

      isSearching = true;

      // Mock search results using the recommended posts
      // In a real app, you would call an API to search posts
      searchResults = recommendedPosts
          .where((post) =>
              post.textContent.toLowerCase().contains(query.toLowerCase()) ||
              post.userName.toLowerCase().contains(query.toLowerCase()) ||
              post.category.toLowerCase().contains(query.toLowerCase()))
          .toList();

      // 검색 완료, 로딩 상태 비활성화
      isSearchLoading = false;
      searchQuery = query;
    });

    // 검색 기록 저장
    _saveSearchHistory();
  }

  void _clearSearch() {
    _searchController.clear();

    // 이전 타이머가 있으면 취소
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
            // Top search bar and back button - 항상 표시됨
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

            // Expanded content area - 로딩 중이면 shimmer 효과 표시
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
      return SearchLoading(context);
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
        return PostCard(
          post: searchResults[index],
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
                        MaterialPageRoute(
                          builder: (context) => const CharactersScreen(),
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    // 타이머 해제
    _debounce?.cancel();
    super.dispose();
  }
}
