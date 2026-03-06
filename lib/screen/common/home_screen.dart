import 'package:go_router/go_router.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/cards/repost_card.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/profile/avatar_story_component.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/screen/notifications/notification_center_screen.dart';
import 'package:inzone/services/notification_badge_service.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/screen/common/search_explore_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.controller});
  final ScrollController? controller;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  List<Widget> feedItems = [];
  List<Widget> originalFeedItems = []; // Store the original order of feed items
  List<String> categoriesList = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  List<InZoneAvatar> avatars = [];
  List<AvatarCard> avatarCards = [];
  List<AvatarStoryComponent> avatarStoryComponents = [];
  InZoneAvatar? popupAvatar;
  String? popupMessage;
  bool _isLoadingPopupMessage = false;
  Timer? _avatarTimer;

  late DateTime _startTime;
  int pageOpened = 0;
  int _currentPage = 1; // Start from page 1 (backend pagination starts at 1)
  final int _pageSize = 10; //
  bool hasMorePosts = true;
  String? selectedCategory; // Track the currently selected category
  int reloadCount = 0; // Track number of reloads
  final int _currentVisibleIndex = 0; // Track current visible card index
  Timer? _scrollThrottleTimer;

  // Scroll tracking variables
  double _lastScrollPosition = 0;
  DateTime _lastScrollTime = DateTime.now();
  int _scrollSessionDuration = 0;

  // Store the actual posts data from API
  List<dynamic> posts = [];
  List<dynamic> originalPosts = []; // For category filtering
  final Set<String> _viewedPosts =
      {}; // Track posts whose view count has been incremented

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _startTime = DateTime.now().toUtc();
    loadFeed();
    loadAvatars();
    _startAvatarTimer();
    _scrollController.addListener(_onScroll);

    // Track session start
    final userId = AppsFlyerService().getCurrentUserId();
    if (userId != null) {
      AppsFlyerService().trackSessionStart(
        userId: userId,
        deviceModel: _getPlatform(),
      );
    }
  }

  void _startAvatarTimer() {
    _avatarTimer?.cancel();

    _avatarTimer = Timer(const Duration(seconds: 30), () async {
      Timer(const Duration(seconds: 30), _dismissAvatarPopup);

      if (!mounted || avatars.isEmpty || popupAvatar != null) return;

      final random = Random();
      final avatar = avatars[random.nextInt(avatars.length)];

      // Show the avatar's static greeting immediately so the popup
      // is never empty, then try to replace it with an AI-generated message.
      setState(() {
        popupAvatar = avatar;
        popupMessage = avatar.greeting?.isNotEmpty == true
            ? avatar.greeting
            : "Hey! Tap here to chat with ${avatar.name}";
        _isLoadingPopupMessage = false;
      });

      // Try to upgrade with an AI-generated message in the background.
      String? aiMsg = await InZoneDatabase.generateFollowUp(avatar.username);
      aiMsg ??= await InZoneDatabase.generateGreeting(avatar.username);

      if (aiMsg != null && mounted && popupAvatar?.id == avatar.id) {
        setState(() {
          popupMessage = aiMsg;
        });
      }
    });
  }

  void _dismissAvatarPopup() {
    if (!mounted) return;
    setState(() {
      popupAvatar = null;
      popupMessage = null;
    });
  }

  String _getPlatform() {
    if (Platform.isIOS) {
      return "iOS";
    } else if (Platform.isAndroid) {
      return "Android";
    } else {
      return "Unknown";
    }
  }

  @override
  void dispose() {
    // Only dispose the controller if we created it internally
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    _refreshController.dispose(); // Dispose the RefreshController
    _scrollThrottleTimer?.cancel();

    // Track session end
    DateTime endTime = DateTime.now().toUtc();
    Duration timeSpent = endTime.difference(_startTime);
    final userId = AppsFlyerService().getCurrentUserId();
    if (userId != null) {
      AppsFlyerService().trackSessionEnd(
        userId: userId,
        sessionDurationSeconds: timeSpent.inSeconds,
      );
    }

    // Keep existing analytics
    InZoneDatabase.logEvent('home_screen', {
      "timeSpent": timeSpent.inSeconds,
      "pageOpenedCount": pageOpened,
    });

    _avatarTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollThrottleTimer?.isActive ?? false) return;

    _scrollThrottleTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_scrollController.hasClients) return;
      _trackScrollBehavior();

      // SIMPLIFIED: Only trigger when very close to the absolute bottom
      // Removed the "remaining items" check which was causing premature loading
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          hasMorePosts) {
        print(
            '🎯 Scroll trigger: Near bottom (within 200px), loading more posts...');
        _loadMorePosts();
      }
    });
  }

  void _trackScrollBehavior() {
    if (!_scrollController.hasClients) return;
    final currentPosition = _scrollController.position.pixels;
    final currentTime = DateTime.now();

    final deltaPosition = currentPosition - _lastScrollPosition;
    final deltaTime = currentTime.difference(_lastScrollTime).inMilliseconds;

    if (deltaTime > 0) {
      final scrollSpeed =
          deltaPosition.abs() / deltaTime * 1000; // pixels per second
      final scrollDirection = deltaPosition > 0 ? 'down' : 'up';

      if (scrollSpeed > 100 && deltaPosition.abs() > 50) {
        final userId = AppsFlyerService().getCurrentUserId();
        if (userId != null) {
          _scrollSessionDuration += deltaTime;

          AppsFlyerService().trackScrollBehavior(
            screenName: 'home_feed',
            scrollSpeedPxPerSec: scrollSpeed,
            scrollDirection: scrollDirection,
            durationSeconds: (_scrollSessionDuration / 1000).round(),
            userId: userId,
          );
        }
      }
    }

    _lastScrollPosition = currentPosition;
    _lastScrollTime = currentTime;
  }

  void _onRefresh() async {
    try {
      if (!isLoading && !isLoadingMore) {
        setState(() {
          reloadCount++;
        });
        await loadFeed(isRefresh: true);
      }
    } catch (e) {
      print('Error during refresh: $e');
    } finally {
      _refreshController.refreshCompleted();
    }
  }

  void _onLoading() async {
    try {
      if (!isLoadingMore && hasMorePosts) {
        await _loadMorePosts();
      }
    } catch (e) {
      print('Error loading more: $e');
    } finally {
      _refreshController.loadComplete();
    }
  }

  Future<void> loadAvatars() async {
    try {
      final characters = await InZoneDatabase.getCarouselCharacters();
      if (mounted && characters != null) {
        await _processAvatars(characters);
        if (mounted) setState(() {});
      }
    } catch (e) {}
  }

  Future<void> loadFeed({bool isRefresh = false}) async {
    if (!mounted) return;

    // Prevent concurrent loading requests
    if (isLoading && isRefresh) return;

    if (isRefresh) {
      setState(() {
        _currentPage = 1; // Reset to page 1 for new batch
        posts.clear();
        originalPosts.clear();
        categoriesList.clear();
        avatars.clear();
        avatarCards.clear();
        avatarStoryComponents.clear();
        hasMorePosts = true;
        selectedCategory = null; // Reset selected category on refresh
        _viewedPosts.clear(); // Clear viewed posts tracking on refresh
      });
      loadAvatars();
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Collect currently loaded post IDs to exclude from backend
      List<String> currentPostIds = posts
          .map(
              (post) => post['id']?.toString() ?? post['_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // CONSISTENT PAGINATION: Always use page 1 for fresh batch
      // _currentPage tracks client-side pagination within the batch
      final response = await InZoneDatabase.getFeed(
        page: 1,
        batchNumber:
            reloadCount, // NEW: Pass batch number to get different recommendations
        excludeIds: currentPostIds, // Exclude already-loaded posts
      );

      if (!mounted) return;

      if (response != null) {
        if (response.containsKey('posts')) {
          List<dynamic> newPosts = response['posts'] ?? [];

          // Check for duplicates before adding
          Set<String> existingIds = posts
              .map((post) =>
                  post['id']?.toString() ?? post['_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();

          List<dynamic> uniqueNewPosts = newPosts.where((post) {
            String id = post['id']?.toString() ?? post['_id']?.toString() ?? '';
            return id.isNotEmpty && !existingIds.contains(id);
          }).toList();

          if (uniqueNewPosts.length != newPosts.length) {
            print(
                '⚠️ WARNING: Filtered out ${newPosts.length - uniqueNewPosts.length} duplicate posts!');
          }

          setState(() {
            posts.addAll(uniqueNewPosts);
            originalPosts = List.from(posts);

            for (var post in newPosts) {
              String category = _extractCategoryFromPost(post);
              if (category.isNotEmpty && !categoriesList.contains(category)) {
                categoriesList.add(category);
              }
            }

            // Keep _currentPage at 1 since we just loaded page 1
            // Next scroll will load page 2
            hasMorePosts = true; // Always true for infinite scroll
          });

          print(
              '✅ LOADED Initial Page 1 of Batch $reloadCount: ${newPosts.length} posts (Total now: ${posts.length})');
          // Show first 3 post IDs for verification
          for (int i = 0; i < newPosts.length.clamp(0, 3); i++) {
            String id = newPosts[i]['id']?.toString() ??
                newPosts[i]['_id']?.toString() ??
                'unknown';
            print(
                '   Post ${i + 1}: ${id.length >= 8 ? id.substring(0, 8) : id}...');
          }
        } else {
          setState(() {
            if (isRefresh) {
              posts.clear();
              originalPosts.clear();
            }
          });
        }
      } else {
        // Handle null response gracefully
        setState(() {
          if (isRefresh) {
            // If it was a refresh and failed, reset to empty state
            posts.clear();
            originalPosts.clear();
          }
        });
      }
    } catch (e) {
      print('Error loading feed: $e');
      // Handle error case - don't leave UI in loading state
      if (mounted) {
        setState(() {
          // If error during refresh, ensure UI is updated
          if (isRefresh) {
            posts.clear();
            originalPosts.clear();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (isLoadingMore || !mounted) return;

    setState(() {
      isLoadingMore = true;
    });

    print(
        '📄 _loadMorePosts: Requesting page ${_currentPage + 1} of batch $reloadCount');
    print(
        '   Current state: ${posts.length} posts loaded, _currentPage=$_currentPage');

    try {
      // Collect currently loaded post IDs to exclude from backend
      List<String> currentPostIds = posts
          .map(
              (post) => post['id']?.toString() ?? post['_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // PAGINATION FIX: Keep same batch, just load next page
      // page: _currentPage + 1 = next page in current batch
      // batchNumber: reloadCount = stay in same batch
      final response = await InZoneDatabase.getFeed(
        page: _currentPage + 1,
        batchNumber: reloadCount, // Keep same batch for consistent pagination
        excludeIds: currentPostIds, // Exclude already-loaded posts
      );

      if (!mounted) return;

      if (response != null) {
        if (response.containsKey('posts')) {
          List<dynamic> newPosts = response['posts'] ?? [];

          print(
              '📥 Received ${newPosts.length} posts for page ${_currentPage + 1}');

          if (newPosts.isEmpty) {
            // Reached end of current batch (all 3 pages loaded)
            // Now fetch a NEW batch for infinite scroll
            print(
                '📱 Reached end of batch (page ${_currentPage + 1}), fetching new batch...');
            print('   Total posts so far: ${posts.length}');

            try {
              // Increment batch number to get new recommendations
              reloadCount++;

              // Collect currently loaded post IDs to exclude from backend
              List<String> currentPostIds = posts
                  .map((post) =>
                      post['id']?.toString() ?? post['_id']?.toString() ?? '')
                  .where((id) => id.isNotEmpty)
                  .toList();

              // Fetch NEW batch, starting from page 1
              final freshResponse = await InZoneDatabase.getFeed(
                page: 1,
                batchNumber: reloadCount, // NEW batch number
                excludeIds: currentPostIds, // Exclude already-loaded posts
              );

              if (!mounted) return;

              if (freshResponse != null && freshResponse.containsKey('posts')) {
                List<dynamic> freshPosts = freshResponse['posts'] ?? [];

                if (freshPosts.isNotEmpty) {
                  // Check for duplicates before adding new batch
                  Set<String> existingIds = posts
                      .map((post) =>
                          post['id']?.toString() ??
                          post['_id']?.toString() ??
                          '')
                      .where((id) => id.isNotEmpty)
                      .toSet();

                  List<dynamic> uniqueFreshPosts = freshPosts.where((post) {
                    String id =
                        post['id']?.toString() ?? post['_id']?.toString() ?? '';
                    return id.isNotEmpty && !existingIds.contains(id);
                  }).toList();

                  if (uniqueFreshPosts.length != freshPosts.length) {
                    print(
                        '⚠️ WARNING: Filtered out ${freshPosts.length - uniqueFreshPosts.length} duplicate posts in new batch!');
                  }

                  setState(() {
                    // Reset page counter for new batch
                    _currentPage = 1;

                    // APPEND new posts (infinite scroll)
                    posts.addAll(uniqueFreshPosts);
                    originalPosts = List.from(posts);

                    // Extract categories from fresh posts
                    for (var post in freshPosts) {
                      String category = _extractCategoryFromPost(post);
                      if (category.isNotEmpty &&
                          !categoriesList.contains(category)) {
                        categoriesList.add(category);
                      }
                    }

                    isLoadingMore = false;
                    hasMorePosts = true;
                  });

                  print(
                      '✅ LOADED NEW Batch $reloadCount, Page 1: ${freshPosts.length} posts (Total now: ${posts.length})');
                  // Show first 3 post IDs for verification
                  for (int i = 0; i < freshPosts.length.clamp(0, 3); i++) {
                    String id = freshPosts[i]['id']?.toString() ??
                        freshPosts[i]['_id']?.toString() ??
                        'unknown';
                    print(
                        '   Post ${posts.length - freshPosts.length + i + 1}: ${id.length >= 8 ? id.substring(0, 8) : id}...');
                  }
                } else {
                  print('⚠️ New batch was empty');
                  setState(() {
                    isLoadingMore = false;
                  });
                }
              } else {
                print('⚠️ No response from new batch request');
                setState(() {
                  isLoadingMore = false;
                });
              }
            } catch (e) {
              print('Error fetching new batch: $e');
              setState(() {
                isLoadingMore = false;
              });
            }
            return;
          }

          // Successfully loaded next page in current batch
          // Check for duplicates before adding
          Set<String> existingIds = posts
              .map((post) =>
                  post['id']?.toString() ?? post['_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();

          List<dynamic> uniqueNewPosts = newPosts.where((post) {
            String id = post['id']?.toString() ?? post['_id']?.toString() ?? '';
            return id.isNotEmpty && !existingIds.contains(id);
          }).toList();

          if (uniqueNewPosts.length != newPosts.length) {
            print(
                '⚠️ WARNING: Filtered out ${newPosts.length - uniqueNewPosts.length} duplicate posts in _loadMorePosts!');
          }

          // Check if we got any unique posts after filtering
          if (uniqueNewPosts.isEmpty) {
            print(
                '⚠️ All posts were duplicates after filtering. No new posts to add.');
            setState(() {
              isLoadingMore = false;
              // Don't stop pagination - just skip this page
            });
            return;
          }

          setState(() {
            posts.addAll(uniqueNewPosts);
            originalPosts = List.from(posts);

            // Extract additional categories
            for (var post in newPosts) {
              String category = _extractCategoryFromPost(post);
              if (category.isNotEmpty && !categoriesList.contains(category)) {
                categoriesList.add(category);
              }
            }

            // If a category is selected, reapply the filter
            if (selectedCategory != null) {
              _filterPostsByCategory(selectedCategory!);
            }

            _currentPage++;
            hasMorePosts = true;
          });

          print(
              '✅ LOADED Page $_currentPage of Batch $reloadCount: ${newPosts.length} posts (Total now: ${posts.length})');
          // Show first 3 post IDs for verification
          for (int i = 0; i < newPosts.length.clamp(0, 3); i++) {
            String id = newPosts[i]['id']?.toString() ??
                newPosts[i]['_id']?.toString() ??
                'unknown';
            print(
                '   Post ${posts.length - newPosts.length + i + 1}: ${id.length >= 8 ? id.substring(0, 8) : id}...');
          }
        } else {
          // No posts in response
          print('⚠️ Response had no posts key');
          setState(() {
            isLoadingMore = false;
          });
          return;
        }
      } else {
        // Null response - just mark as not loading
        print('⚠️ Null response from getFeed');
        setState(() {
          isLoadingMore = false;
        });
        return;
      }
    } catch (e) {
      print('Error loading more posts: $e');
      // Just log the error and stop loading
      setState(() {
        isLoadingMore = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _processAvatars(List<dynamic> fetchedCharacters) async {
    avatars.clear();
    avatarCards.clear();
    avatarStoryComponents.clear();
    try {
      avatars = [];

      for (var characterData in fetchedCharacters) {
        InZoneAvatar avatar = InZoneAvatar.fromDirectJson(characterData);
        avatars.add(avatar);
      }

      // Sort avatars so the ones the user chatted with most recently come first.
      final chatTimestamps = await InZoneDatabase.getChatTimestamps();
      avatars.sort((a, b) {
        final tA = chatTimestamps[a.username] ?? chatTimestamps[a.id] ?? 0;
        final tB = chatTimestamps[b.username] ?? chatTimestamps[b.id] ?? 0;
        // Descending: most recent first. Avatars with no history go to the end.
        return tB.compareTo(tA);
      });

      for (var avatar in avatars) {
        avatarCards.add(AvatarCard(avatar: avatar));
        avatarStoryComponents.add(AvatarStoryComponent(avatar: avatar));
      }
    } catch (e) {
      print('DEBUG: Error in _processAvatars: $e');
    }
  }

  // Extract the first category from a post
  String _extractCategoryFromPost(dynamic post) {
    // Check if category is an array
    if (post.containsKey('category')) {
      var category = post['category'];
      if (category is List && category.isNotEmpty) {
        // Return the first category from the array
        return category[0].toString();
      } else if (category is String && category.isNotEmpty) {
        // Handle case where category is a string
        return category;
      }
    }
    return '';
  }

  // Filter posts by category
  void _filterPostsByCategory(String? category) {
    setState(() {
      selectedCategory = category;

      if (category == null) {
        // If no category is selected, restore original order
        posts = List.from(originalPosts);
        return;
      }

      // Filter posts by the selected category
      List<dynamic> filteredPosts = originalPosts.where((post) {
        String postCategory = _extractCategoryFromPost(post).toLowerCase();
        String searchCategory = category.toLowerCase();

        return postCategory == searchCategory ||
            postCategory.contains(searchCategory) ||
            searchCategory.contains(postCategory);
      }).toList();

      List<dynamic> otherPosts = originalPosts.where((post) {
        String postCategory = _extractCategoryFromPost(post).toLowerCase();
        String searchCategory = category.toLowerCase();

        return !(postCategory == searchCategory ||
            postCategory.contains(searchCategory) ||
            searchCategory.contains(postCategory));
      }).toList();

      // Combine filtered posts with other posts
      posts = [...filteredPosts, ...otherPosts];
    });
  }

  Widget _buildAvatarCarousel() {
    final PageController pageController = PageController(viewportFraction: 0.8);

    return SizedBox(
      height: 580,
      child: PageView.builder(
        controller: pageController,
        itemCount: avatarCards.length,
        itemBuilder: (context, index) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: avatarCards[index],
          );
        },
      ),
    );
  }

  Widget _buildAvatarStories() {
    return SizedBox(
      height: 130,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: avatarStoryComponents.map((avatarCard) {
              return avatarCard;
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPostWidget(dynamic post, int index) {
    // Calculate the actual post index (accounting for inserted ads)
    int actualPostIndex = index - (index ~/ 11);

    // Return empty widget if we've run out of posts
    if (actualPostIndex >= posts.length) {
      return const SizedBox.shrink();
    }

    // Get the actual post data using the calculated index
    dynamic actualPost = posts[actualPostIndex];

    if ((index + 1) % 11 == 0) {
      InZonePost adPost = InZonePost(
        category: '',
        userName: '',
        comments: [],
        datePosted: DateTime.now().toUtc(),
        likes: 0,
        id: 'ad_$index',
        imageContent: [],
        videoContent: [],
        textContent: '',
        userReference: '',
        mainCategory: '',
        isAi: false,
      );

      return _AdPostCard(
        adPost: adPost,
        index: index,
      );
    }

    String postType = actualPost['post_type'] ?? 'unknown';

    // Insert avatar carousel after certain number of posts (adjust for ads)
    if (actualPostIndex > 0 &&
        actualPostIndex % 20 == 0 &&
        avatarCards.isNotEmpty) {
      return _buildAvatarCarousel();
    }

    // Increment view count when post is built (not for ads or carousels)
    String postId =
        actualPost['id']?.toString() ?? actualPost['_id']?.toString() ?? '';

    // LOG: Track which post is being displayed
    String postContentPreview = '';
    if (actualPost.containsKey('post')) {
      var postData = actualPost['post'];
      if (postData is Map && postData.containsKey('text_content')) {
        String textContent = postData['text_content']?.toString() ?? '';
        postContentPreview = textContent.length > 30
            ? textContent.substring(0, 30)
            : textContent;
      }
    }

    print(
        '📺 DISPLAY Post #${actualPostIndex + 1}/${posts.length} | ListViewIdx: $index | ID: ${postId.length >= 8 ? postId.substring(0, 8) : postId}... | Type: $postType | Preview: "$postContentPreview${postContentPreview.isNotEmpty ? "..." : ""}"');

    if (postId.isNotEmpty &&
        postType != 'unknown' &&
        !_viewedPosts.contains(postId)) {
      _viewedPosts.add(postId);
      _incrementViewCount(postId, postType);
    }

    try {
      // Extract the category for the post
      String category = _extractCategoryFromPost(actualPost);

      switch (postType) {
        case 'repost':
          // Build repost card
          InZonePost postObj = InZonePost.fromJsonForHumans(actualPost);
          // Ensure correct category is set
          postObj = InZonePost(
            category: category,
            userName: postObj.userName,
            comments: postObj.comments,
            datePosted: postObj.datePosted,
            likes: postObj.likes,
            id: postObj.id,
            imageContent: postObj.imageContent,
            videoContent: postObj.videoContent,
            textContent: postObj.textContent,
            userReference: postObj.userReference,
            mainCategory: postObj.mainCategory,
            isAi: false,
          );
          InZoneAvatar avatar = InZoneAvatar.fromRepostJson(actualPost);
          return RepostCard(
            post: postObj,
            repost: avatar,
            aiChat: actualPost["ai_chat_content"] ?? "",
          );

        case 'ai_post':
          // Build AI post card
          InZonePost postObj = InZonePost.fromJsonForHumans(actualPost);
          postObj = InZonePost(
            category: category,
            userName: postObj.userName,
            comments: postObj.comments,
            datePosted: postObj.datePosted,
            likes: postObj.likes,
            id: postObj.id,
            imageContent: postObj.imageContent,
            videoContent: postObj.videoContent,
            textContent: postObj.textContent,
            userReference: postObj.userReference,
            mainCategory: postObj.mainCategory,
            isAi: true,
          );
          return PostCard(
            post: postObj,
            onTap: (postId) {},
            inProfile: false,
            onDeleted: (postId) {
              setState(() {
                posts.removeWhere((p) =>
                    (p is Map && p['id'] == postId) ||
                    (p is InZonePost && p.id == postId));
                feedItems
                    .removeWhere((w) => w is PostCard && (w).post.id == postId);
              });
            },
            onUpdated: (updatedPost) {
              setState(() {
                for (int i = 0; i < posts.length; i++) {
                  final p = posts[i];
                  if ((p is Map && p['id'] == updatedPost.id) ||
                      (p is InZonePost && p.id == updatedPost.id)) {
                    posts[i] = updatedPost;
                  }
                }
                for (var w in feedItems) {
                  if (w is PostCard && w.post.id == updatedPost.id)
                    w.post = updatedPost;
                }
              });
            },
          );

        case 'human_post':
          // Build human post card
          InZonePost postObj = InZonePost.fromJsonForHumans(actualPost);
          postObj = InZonePost(
            category: category,
            userName: postObj.userName,
            comments: postObj.comments,
            datePosted: postObj.datePosted,
            likes: postObj.likes,
            id: postObj.id,
            imageContent: postObj.imageContent,
            videoContent: postObj.videoContent,
            textContent: postObj.textContent,
            userReference: postObj.userReference,
            mainCategory: postObj.mainCategory,
            isAi: false,
            characterInfo: postObj.characterInfo,
          );
          return PostCard(
            post: postObj,
            onTap: (postId) {},
            inProfile: false,
            onDeleted: (postId) {
              setState(() {
                posts.removeWhere((p) =>
                    (p is Map && p['id'] == postId) ||
                    (p is InZonePost && p.id == postId));
                feedItems
                    .removeWhere((w) => w is PostCard && (w).post.id == postId);
              });
            },
            onUpdated: (updatedPost) {
              setState(() {
                for (int i = 0; i < posts.length; i++) {
                  final p = posts[i];
                  if ((p is Map && p['id'] == updatedPost.id) ||
                      (p is InZonePost && p.id == updatedPost.id)) {
                    posts[i] = updatedPost;
                  }
                }
                for (var w in feedItems) {
                  if (w is PostCard && w.post.id == updatedPost.id)
                    w.post = updatedPost;
                }
              });
            },
          );

        default:
          // For unknown post types, try to render as a regular post
          InZonePost postObj = InZonePost.fromJsonForHumans(actualPost);
          postObj = InZonePost(
            category: category,
            userName: postObj.userName,
            comments: postObj.comments,
            datePosted: postObj.datePosted,
            likes: postObj.likes,
            id: postObj.id,
            imageContent: postObj.imageContent,
            videoContent: postObj.videoContent,
            textContent: postObj.textContent,
            userReference: postObj.userReference,
            mainCategory: postObj.mainCategory,
            isAi: false,
            characterInfo: postObj.characterInfo,
          );
          return PostCard(
            post: postObj,
            onTap: (postId) {},
            inProfile: false,
            onDeleted: (postId) {
              setState(() {
                posts.removeWhere((p) =>
                    (p is Map && p['id'] == postId) ||
                    (p is InZonePost && p.id == postId));
                feedItems
                    .removeWhere((w) => w is PostCard && (w).post.id == postId);
              });
            },
            onUpdated: (updatedPost) {
              setState(() {
                for (int i = 0; i < posts.length; i++) {
                  final p = posts[i];
                  if ((p is Map && p['id'] == updatedPost.id) ||
                      (p is InZonePost && p.id == updatedPost.id)) {
                    posts[i] = updatedPost;
                  }
                }
                for (var w in feedItems) {
                  if (w is PostCard && w.post.id == updatedPost.id)
                    w.post = updatedPost;
                }
              });
            },
          );
      }
    } catch (e) {
      return const SizedBox
          .shrink(); // Return empty widget for problematic posts
    }
  }

  Widget refreshIcon() {
    return Image.asset(
      'assets/icons/dark.png',
      width: 35,
      height: 35,
    );
  }

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Widget _buildPopupAvatar() {
    final a = popupAvatar; // capture once

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.25), // noticeable
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final scale = Tween<double>(
          begin: 0.92,
          end: 1.0,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: a == null
          ? const SizedBox(key: ValueKey('no_popup'))
          : Dismissible(
              key: ValueKey('popup_${a.id}'), // unique key per avatar
              direction: DismissDirection.horizontal,
              dismissThresholds: const {
                DismissDirection.startToEnd: 0.25,
                DismissDirection.endToStart: 0.25,
              },
              onDismissed: (_) {
                _dismissAvatarPopup();
              },
              child: Container(
                key: const ValueKey('popup'),
                width: 320,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFFEF6D38)
                        : const Color(0xFFEF6D38),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () async {
                    _dismissAvatarPopup();
                    await context.pushNamed(
                      'chat',
                      extra: ChatUser(
                        name: a.name,
                        email: a.id,
                        chatId: null,
                        isHuman: false,
                        profilePictureURL: a.profilePicture,
                        greeting: popupMessage,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(2.0),
                        child: ClipOval(
                          child: Image.network(
                            a.profilePicture,
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  a.name.isNotEmpty
                                      ? a.name.substring(0, 1).toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
                        child: _isLoadingPopupMessage
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : Text(
                                popupMessage ?? a.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
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
        child: Stack(children: [
          isLoading
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      StreamBuilder<int>(
                        stream: NotificationBadgeService
                            .getUnreadNotificationCount(),
                        builder: (context, snapshot) {
                          final notificationCount = snapshot.data ?? 0;
                          return CustomAppBar(
                            isHome: true,
                            isDebug:
                                false, // Changed to false to show notification button
                            userPoints: "100",
                            profileImageUrl: null,
                            notificationCount:
                                notificationCount, // Real-time unread count
                            onNotificationTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationCenterScreen(),
                                ),
                              );
                            },
                            onSearchTap: () {
                              try {
                                // context.push(Routes.searchExplore);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SearchExploreScreen(),
                                  ),
                                );
                              } catch (e) {
                                print('Error navigating to search: $e');
                                ToastService.showToast(
                                  context,
                                  backgroundColor:
                                      Theme.of(context).canvasColor,
                                  shadowColor: Colors.transparent,
                                  leading: const Icon(
                                    Icons
                                        .error_outline, // or Icons.check_circle, Icons.warning_amber_rounded, etc.
                                    color: Colors
                                        .redAccent, // or Colors.greenAccent, Colors.orange
                                  ),
                                  message: 'Cannot navigate to search: $e',
                                );
                              }
                            },
                            onProfileTap: () {},
                            onPointsTap: () {},
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 0.0, bottom: 35.0),
                        child: CategoryLoading(context),
                      ),
                      ...List<Widget>.generate(
                          5, (index) => PostLoading(context)),
                    ],
                  ),
                )
              : SmartRefresher(
                  enablePullDown: true,
                  controller: _refreshController,
                  onRefresh: _onRefresh,
                  // Use AlwaysScrollableScrollPhysics for consistent behavior
                  physics: const AlwaysScrollableScrollPhysics(),
                  header: ClassicHeader(
                    releaseIcon: refreshIcon(),
                    refreshingIcon: refreshIcon(),
                    completeIcon: refreshIcon(),
                    idleIcon: refreshIcon(),
                    failedIcon: refreshIcon(),
                    refreshingText: "",
                    releaseText: "",
                    completeText: "",
                    idleText: "",
                    failedText: "",
                  ),
                  child: CustomScrollView(
                    controller: _scrollController,
                    // Use AlwaysScrollableScrollPhysics for consistency
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Cache extent to prebuild the next ~3 cards (assuming ~200px per card)
                    cacheExtent: 600.0,
                    slivers: [
                      SliverPersistentHeader(
                        floating: true,
                        pinned: false,
                        delegate: CustomAppBarDelegate(
                          child: StreamBuilder<int>(
                            stream: NotificationBadgeService
                                .getUnreadNotificationCount(),
                            builder: (context, snapshot) {
                              final notificationCount = snapshot.data ?? 0;
                              return CustomAppBar(
                                isHome: true,
                                isDebug:
                                    false, // Changed to false to show notification button
                                userPoints: "100",
                                profileImageUrl: null,
                                notificationCount:
                                    notificationCount, // Real-time unread count
                                onNotificationTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NotificationCenterScreen(),
                                    ),
                                  );
                                },
                                onSearchTap: () {
                                  try {
                                    // context.push(Routes.searchExplore);

                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SearchExploreScreen(),
                                      ),
                                    );
                                  } catch (e) {
                                    print('Error navigating to search: $e');
                                    ToastService.showToast(
                                      context,
                                      backgroundColor:
                                          Theme.of(context).canvasColor,
                                      shadowColor: Colors.transparent,
                                      leading: const Icon(
                                        Icons
                                            .error_outline, // or Icons.check_circle, Icons.warning_amber_rounded, etc.
                                        color: Colors
                                            .redAccent, // or Colors.greenAccent, Colors.orange
                                      ),
                                      message: "Error navigating to search: $e",
                                    );
                                  }
                                },
                                onProfileTap: () {
                                  context.go(Routes.profile_tab);
                                },
                                onPointsTap: () {},
                              );
                            },
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: avatarStoryComponents.isNotEmpty
                            ? _buildAvatarStories()
                            : const SizedBox.shrink(),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            // Calculate total items including ads
                            int totalItemsWithAds =
                                posts.length + (posts.length ~/ 10);

                            if (index == totalItemsWithAds && isLoadingMore) {
                              // Show loading indicator at the bottom
                              return Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              );
                            } else if (index ==
                                totalItemsWithAds + (isLoadingMore ? 1 : 0)) {
                              // Bottom padding for navigation bar
                              return const SizedBox(height: 100);
                            }

                            // If within range, build the post widget
                            if (index < totalItemsWithAds) {
                              return Padding(
                                key: ValueKey('post_$index'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0, vertical: 0),
                                child: _buildPostWidget(null, index),
                              );
                            }

                            return const SizedBox.shrink(); // Safety fallback
                          },
                          childCount: posts.isEmpty
                              ? 1 // Just show bottom padding if no posts
                              : posts.length +
                                  (posts.length ~/ 10) +
                                  (isLoadingMore ? 1 : 0) +
                                  1, // +ads +loading +bottom padding
                          // Enable automatic keep alives to maintain built widgets
                          addAutomaticKeepAlives: true,
                          // Enable repaint boundaries for better performance
                          addRepaintBoundaries: true,
                          // Prebuild next 3 items by setting semantic index
                          addSemanticIndexes: true,
                        ),
                      ),
                    ],
                  ),
                ),
          Positioned(right: 5, bottom: 125, child: _buildPopupAvatar())
        ]),
      ),
    );
  }

  // Helper method to get the current user's name
  Future<String> _getUserName() async {
    try {
      Map<String, dynamic>? userProfile =
          await InZoneDatabase.getCurrentUserProfile();
      if (userProfile != null) {
        return userProfile["Name"] ?? userProfile["name"] ?? "User";
      }
    } catch (e) {
      print('Error getting user name: $e');
    }
    return "User";
  }

  // Method to increment view count for a post when it gets built
  Future<void> _incrementViewCount(String postId, String postType) async {
    try {
      String collectionName;

      // Map post type to collection name
      switch (postType) {
        case 'ai_post':
          collectionName = 'aiPosts';
          break;
        case 'human_post':
          collectionName = 'humanPosts';
          break;
        case 'repost':
          collectionName = 'reposts';
          break;
        default:
          // Skip view count increment for unknown post types or ads
          return;
      }

      // Directly increment the viewcount field using Firebase SDK
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(postId)
          .update({
        'viewcount': FieldValue.increment(1),
      });

      print('View count incremented for $collectionName/$postId');
    } catch (e) {
      // Silently handle errors - don't disrupt user experience
      print('Error incrementing view count for $postId: $e');
    }
  }
}

// Custom ad card that manages its own state
class _AdPostCard extends StatefulWidget {
  final InZonePost adPost;
  final int index;

  const _AdPostCard({required this.adPost, required this.index});

  @override
  _AdPostCardState createState() => _AdPostCardState();
}

class _AdPostCardState extends State<_AdPostCard> {
  bool _isAdLoaded = false;

  void _onAdLoaded() {
    if (mounted) {
      setState(() {
        _isAdLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PostCard(
      post: widget.adPost,
      isAd: true,
      onAdLoaded: _onAdLoaded,
    );
  }
}

class CustomAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const CustomAppBarDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 70.0;

  @override
  double get minExtent => 70.0;

  @override
  bool shouldRebuild(CustomAppBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
