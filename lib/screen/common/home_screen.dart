import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/cards/repost_card.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/profile/avatar_story_component.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/screen/common/search_explore_screen.dart';
import 'package:toasty_box/toast_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.controller});
  final ScrollController? controller;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  List<Widget> feedItems = [];
  List<Widget> originalFeedItems = []; // Store the original order of feed items
  List<String> categoriesList = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  List<AvatarCard> avatarCards = [];
  List<AvatarStoryComponent> avatarStoryComponents = [];

  late DateTime _startTime;
  int pageOpened = 0;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool hasMorePosts = true;
  String? selectedCategory; // Track the currently selected category
  int reloadCount = 0; // Track number of reloads
  int _currentVisibleIndex = 0; // Track current visible card index

  // Store the actual posts data from API
  List<dynamic> posts = [];
  List<dynamic> originalPosts = []; // For category filtering
  final Set<String> _viewedPosts =
      {}; // Track posts whose view count has been incremented

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _startTime = DateTime.now();
    loadFeed();
    loadAvatars();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // Only dispose the controller if we created it internally
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('home_screen', {
      "timeSpent": timeSpent.inSeconds,
      "pageOpenedCount": pageOpened,
    });
    super.dispose();
  }

  void _onScroll() {
    // Calculate approximate current visible index based on scroll position
    // Assuming average card height of ~200px
    double scrollPosition = _scrollController.position.pixels;
    int estimatedVisibleIndex = (scrollPosition / 200).floor();

    // Update current visible index if it has changed significantly
    if (estimatedVisibleIndex != _currentVisibleIndex) {
      _currentVisibleIndex = estimatedVisibleIndex;

      // Ensure we have enough posts loaded ahead
      int totalItemsWithAds = posts.length + (posts.length ~/ 10);
      int remainingItems = totalItemsWithAds - _currentVisibleIndex;

      // If we're within 5 items of the end, load more
      if (remainingItems <= 5 && !isLoadingMore && hasMorePosts) {
        _loadMorePosts();
      }
    }

    // Original logic: 화면 끝에서 더 일찍(500픽셀 전) 데이터 로딩을 시작
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !isLoadingMore &&
        hasMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> loadAvatars() async {
    try {
      final characters = await InZoneDatabase.getCarouselCharacters();
      if (mounted && characters != null) {
        _processAvatars(characters);
      }
    } catch (e) {}
  }

  Future<void> loadFeed({bool isRefresh = false}) async {
    if (!mounted) return;

    // Prevent concurrent loading requests
    if (isLoading && isRefresh) return;

    if (isRefresh) {
      setState(() {
        _currentPage = 0;
        posts.clear();
        originalPosts.clear();
        categoriesList.clear();
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
      // Use page=1 for initial load to ensure consistent behavior
      final response =
          await InZoneDatabase.getFeed(page: isRefresh ? 1 : reloadCount);

      if (!mounted) return;

      if (response != null) {
        if (response.containsKey('posts')) {
          List<dynamic> newPosts = response['posts'] ?? [];

          setState(() {
            posts.addAll(newPosts);
            originalPosts =
                List.from(posts); // Store original posts for filtering

            // Extract categories from posts
            for (var post in newPosts) {
              String category = _extractCategoryFromPost(post);
              if (category.isNotEmpty && !categoriesList.contains(category)) {
                categoriesList.add(category);
              }
            }

            _currentPage++;
            hasMorePosts = newPosts.isNotEmpty;
          });
        } else {
          // Handle empty response gracefully
          setState(() {
            if (isRefresh) {
              // If it was a refresh, reset to empty state
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
      // Don't increment reloadCount here - it causes issues with pagination
    });

    try {
      // Always use current page number for pagination rather than reloadCount
      final response = await InZoneDatabase.getFeed(page: _currentPage + 1);

      if (!mounted) return;

      if (response != null) {
        if (response.containsKey('posts')) {
          List<dynamic> newPosts = response['posts'] ?? [];

          if (newPosts.isEmpty) {
            // No more posts to load
            setState(() {
              hasMorePosts = false;
              isLoadingMore = false;
            });
            return;
          }

          setState(() {
            posts.addAll(newPosts);
            originalPosts = List.from(posts); // Update original posts

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
            hasMorePosts = newPosts.isNotEmpty;
          });
        } else {
          setState(() {
            hasMorePosts = false;
          });
        }
      } else {
        setState(() {
          hasMorePosts = false;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
      // Ensure we don't keep showing loading state if there's an error
      setState(() {
        hasMorePosts = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _preloadNextPage() async {
    if (isLoadingMore || !mounted) return;

    bool wasLoading = isLoadingMore;
    isLoadingMore = true;

    try {
      // Use _currentPage + 1 instead of reloadCount for better pagination
      await InZoneDatabase.getFeed(page: _currentPage + 1);
    } catch (e) {
      print('Error preloading next page: $e');
    } finally {
      if (mounted) {
        isLoadingMore = wasLoading;
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
      avatarCards.shuffle();
      avatarStoryComponents.shuffle();
    } catch (e) {}
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

    // Check if this position should show an ad (every 11th item: 10, 21, 32, etc.)
    if ((index + 1) % 11 == 0) {
      // 광고를 위한 더미 포스트 생성
      InZonePost adPost = InZonePost(
        category: '',
        userName: '',
        comments: [],
        datePosted: DateTime.now(),
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
          );
          return PostCard(
            post: postObj,
            onTap: (postId) {},
            inProfile: false,
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
          );
          return PostCard(
            post: postObj,
            onTap: (postId) {},
            inProfile: false,
          );
      }
    } catch (e) {
      return const SizedBox
          .shrink(); // Return empty widget for problematic posts
    }
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
        child: isLoading
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    CustomAppBar(
                      isHome: true,
                      userPoints: "100",
                      profileImageUrl: null,
                      onSearchTap: () {
                        try {
                          // context.push(Routes.searchExplore);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SearchExploreScreen(),
                            ),
                          );
                        } catch (e) {
                          print('Error navigating to search: $e');
                          ToastService.showToast(
                            context,
                            backgroundColor: Theme.of(context).canvasColor,
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
            : CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                // Cache extent to prebuild the next ~3 cards (assuming ~200px per card)
                cacheExtent: 600.0,
                slivers: [
                  // iOS 스타일 리프레시 컨트롤
                  CupertinoSliverRefreshControl(
                    onRefresh: () async {
                      try {
                        // Only increment reload count if the previous load finished
                        if (!isLoading && !isLoadingMore) {
                          setState(() {
                            reloadCount++;
                          });
                          await loadFeed(isRefresh: true);
                        } else {
                          // Cancel refresh if already loading
                          setState(() {
                            // Just complete the refresh without doing anything
                          });
                        }
                      } catch (e) {
                        // Handle refresh errors gracefully
                        print('Error during refresh: $e');
                        setState(() {
                          isLoading = false;
                          isLoadingMore = false;
                        });
                      }
                    },
                    refreshTriggerPullDistance: 120.0,
                    refreshIndicatorExtent: 60.0,
                    builder: (
                      BuildContext context,
                      RefreshIndicatorMode refreshState,
                      double pulledExtent,
                      double refreshTriggerPullDistance,
                      double refreshIndicatorExtent,
                    ) {
                      return Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const CupertinoActivityIndicator(radius: 14.0),
                            Positioned(
                              left: MediaQuery.of(context).size.width / 2 + 20,
                              child: Container(
                                width: 100,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Theme.of(context).cardColor,
                                ),
                                child:
                                    const SizedBox(), // Remove CategoryLoading from here
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Add Avatar Carousel above category selector bar
                  SliverPersistentHeader(
                    floating: true,
                    pinned: false,
                    delegate: CustomAppBarDelegate(
                      child: CustomAppBar(
                        isHome: true,
                        userPoints: "100",
                        profileImageUrl: null,
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
                              backgroundColor: Theme.of(context).canvasColor,
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
                        onProfileTap: () {},
                        onPointsTap: () {},
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: avatarStoryComponents.isNotEmpty
                        ? _buildAvatarStories()
                        : const SizedBox.shrink(),
                  ),
                  // SliverToBoxAdapter(
                  //   child: Padding(
                  //     padding: const EdgeInsets.only(top: 10.0),
                  //     child: categoriesList.isNotEmpty
                  //         ? Padding(
                  //       padding: const EdgeInsets.only(bottom: 10.0),
                  //       child: CategorySelectorBar(
                  //         categories: categoriesList,
                  //         onTap: (selectedCat) {
                  //           _filterPostsByCategory(selectedCat);
                  //         },
                  //       ),
                  //     )
                  //         : CategoryLoading(context),
                  //   ),
                  // ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // Calculate total items including ads
                        int totalItemsWithAds =
                            posts.length + (posts.length ~/ 10);

                        if (index == totalItemsWithAds && isLoadingMore) {
                          return const SizedBox(height: 1);
                        } else if (index ==
                            totalItemsWithAds + (isLoadingMore ? 1 : 0)) {
                          // Bottom padding for navigation bar
                          return const SizedBox(height: 100);
                        }

                        // If within range, build the post widget
                        if (index < totalItemsWithAds) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 0),
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

class _AdPostCard extends StatefulWidget {
  final InZonePost adPost;
  final int index;

  const _AdPostCard({
    required this.adPost,
    required this.index,
  });

  @override
  State<_AdPostCard> createState() => _AdPostCardState();
}

class _AdPostCardState extends State<_AdPostCard> {
  bool isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // 광고 로딩 시작
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (mounted) {
      setState(() {
        isAdLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (!isAdLoaded) AdPostLoading(context),
        AnimatedOpacity(
          opacity: isAdLoaded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: PostCard(
            post: widget.adPost,
            onTap: (postId) {},
            isAd: true,
            inProfile: false,
          ),
        ),
      ],
    );
  }
}
