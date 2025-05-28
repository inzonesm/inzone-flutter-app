import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/cards/repost_card.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/profile/avatar_story_component.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';

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

  // Store the actual posts data from API
  List<dynamic> posts = [];
  List<dynamic> originalPosts = []; // For category filtering

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
    // 화면 끝에서 더 일찍(500픽셀 전) 데이터 로딩을 시작
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
        reloadCount++; // Increment reload count on refresh
      });
      loadAvatars();
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Fetch data from InZoneDatabase with reload count parameter
      final response = await InZoneDatabase.getFeed(page: reloadCount);

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
        } else {}
      } else {}
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
      reloadCount++; // Increment reload count when loading more posts
    });

    try {
      // 배치로 더 많은 데이터를 로드
      final response = await InZoneDatabase.getFeed(page: reloadCount);

      if (!mounted) return;

      if (response != null) {
        if (response.containsKey('posts')) {
          List<dynamic> newPosts = response['posts'] ?? [];

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

            // 다음 페이지가 필요할 것으로 예상되면 미리 준비
            if (hasMorePosts && (_currentPage % 2 == 0)) {
              // 미리 다음 페이지 데이터 준비 (비동기적으로)
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted && !isLoadingMore && hasMorePosts) {
                  _preloadNextPage();
                }
              });
            }
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
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  // 다음 페이지 데이터 미리 로드 (백그라운드)
  Future<void> _preloadNextPage() async {
    // 이미 로딩 중이면 중복 실행 방지
    if (isLoadingMore || !mounted) return;

    // 실제로 UI에 로딩 상태를 표시하지 않고 내부적으로만 로딩
    bool wasLoading = isLoadingMore;
    isLoadingMore = true;
    reloadCount++;

    try {
      await InZoneDatabase.getFeed(page: reloadCount);
      // 결과는 실제로 사용하지 않고, 캐시에만 저장
    } catch (e) {
      // 조용히 오류 처리
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
    int actualPostIndex = index - (index ~/ 8);

    // Return empty widget if we've run out of posts
    if (actualPostIndex >= posts.length) {
      return const SizedBox.shrink();
    }

    // Get the actual post data using the calculated index
    dynamic actualPost = posts[actualPostIndex];

    // Check if this position should show an ad (every 8th item: 7, 15, 23, etc.)
    if ((index + 1) % 8 == 0) {
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

      // 각 광고마다 개별적인 상태를 가지는 별도의 위젯 사용
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
                      onSearchTap: () {},
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
                slivers: [
                  // iOS 스타일 리프레시 컨트롤
                  CupertinoSliverRefreshControl(
                    onRefresh: () async {
                      setState(() {
                        reloadCount++;
                      });
                      await loadFeed(isRefresh: true);
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
                        onSearchTap: () {},
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
                            posts.length + (posts.length ~/ 7);

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
                              (posts.length ~/ 7) +
                              (isLoadingMore ? 1 : 0) +
                              1, // +ads +loading +bottom padding
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
}

// 광고 포스트 카드 위젯 - 각 광고마다 개별적인 상태를 가짐
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
        // 광고 로딩 중 Shimmering 효과 표시
        if (!isAdLoaded) AdPostLoading(context),

        // 실제 광고 PostCard (애니메이션 효과로 서서히 나타남)
        AnimatedOpacity(
          opacity: isAdLoaded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: PostCard(
            post: widget.adPost,
            onTap: (postId) {},
            isAd: true,
          ),
        ),
      ],
    );
  }
}
