import 'package:flutter/material.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/cards/repost_card.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/posts/category_selector_bar.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final ScrollController controller;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Widget> feedItems = [];
  List<Widget> originalFeedItems = []; // Store the original order of feed items
  List<String> categoriesList = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  List<AvatarCard> avatarCards = [];
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
    _startTime = DateTime.now();
    loadFeed();
    loadAvatars();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('home_screen', {
      "timeSpent": timeSpent.inSeconds,
      "pageOpenedCount": pageOpened,
    });
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.controller.position.pixels >=
            widget.controller.position.maxScrollExtent - 200 &&
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

  void _processAvatars(List<dynamic> fetchedCharacters) {
    avatarCards.clear();
    try {
      for (var characterData in fetchedCharacters) {
        // Use the new factory method
        InZoneAvatar avatar = InZoneAvatar.fromDirectJson(characterData);
        avatarCards.add(AvatarCard(avatar: avatar));
      }
      avatarCards.shuffle();
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
    return SizedBox(
      height: 580,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(
              "Most Popular",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: avatarCards.map((avatarCard) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: avatarCard,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostWidget(dynamic post, int index) {
    String postType = post['post_type'] ?? 'unknown';

    // Insert avatar carousel after certain number of posts
    if (index > 0 && index % 20 == 0 && avatarCards.isNotEmpty) {
      return _buildAvatarCarousel();
    }

    try {
      // Extract the category for the post
      String category = _extractCategoryFromPost(post);

      switch (postType) {
        case 'repost':
          // Build repost card
          InZonePost postObj = InZonePost.fromJsonForHumans(post);
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
          InZoneAvatar avatar = InZoneAvatar.fromRepostJson(post);
          return RepostCard(
            post: postObj,
            repost: avatar,
            aiChat: post["ai_chat_content"] ?? "",
          );

        case 'ai_post':
          // Build AI post card
          InZonePost postObj = InZonePost.fromJsonForHumans(post);
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
          InZonePost postObj = InZonePost.fromJsonForHumans(post);
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
          InZonePost postObj = InZonePost.fromJsonForHumans(post);
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
      appBar: CustomAppBar(
        isHome: true,
        userName: "John Doe",
        userPoints: "100",
        profileImageUrl: "https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
        onSearchTap: () {},
        onProfileTap: () {},
        onPointsTap: () {},
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: SafeArea(
          left: false,
          right: false,
          top: false,
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                reloadCount++; // Increment reload count on manual refresh
              });
              await loadFeed(isRefresh: true);
              return;
            },
            child: ListView.builder(
              controller: widget.controller,
              itemCount: isLoading
                  ? 2
                  : 1 +
                      posts.length +
                      (isLoadingMore ? 1 : 0), // +1 for category bar
              itemBuilder: (context, index) {
                if (isLoading) {
                  return index == 0
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10.0, horizontal: 10),
                          child: buildShimmerCategoryBar(),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: List.generate(
                                10, (index) => buildShimmerPostCard()),
                          ),
                        );
                } else if (index == 0) {
                  // Category bar when not loading
                  return categoriesList.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: CategorySelectorBar(
                            categories: categoriesList,
                            onTap: (selectedCat) {
                              _filterPostsByCategory(selectedCat);
                            },
                          ),
                        )
                      : const Text("No categories available");
                } else if (index == posts.length + 1 && isLoadingMore) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  // Render the post directly from the posts list
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 0),
                    child: _buildPostWidget(posts[index - 1], index - 1),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget buildShimmerPostCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }

  Widget buildShimmerCategoryBar() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}
