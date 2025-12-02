import 'dart:io';

import 'package:flutter/material.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/posts/category_selector_bar.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:inzone/data/inzone_post.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<PostCard> posts = [];
  List<String> categoriesList = [];
  List<Widget> finalHomeScreen = [];
  bool isLoading = true;
  bool isLoadingMore = false; // For lazy loading indication
  List<AvatarCard> avatarCards = [];
  late DateTime _startTime; // To store the start time
  int pageOpened = 0;
  int _currentPage = 0; // Keep track of the current page for pagination
  final int _pageSize = 100; // Load 10 posts per batch
  bool isSearching = false;
  final ScrollController _scrollController = ScrollController();
  TextEditingController searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now().toUtc();
    getFeed(); // Initial data fetch
    _scrollController
        .addListener(_onScroll); // Attach scroll listener for lazy loading
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose of the scroll controller
    DateTime endTime = DateTime.now().toUtc();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('explore_screen', {
      "timeSpent": timeSpent.inSeconds,
      "pageOpenedCount": pageOpened,
    });
    super.dispose();
  }

  void _onScroll() {
    // Load more posts when scrolled to the bottom
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !isLoadingMore) {
      _loadMorePosts();
    }
  }

  Future<void> getFeed({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 0; // Reset the page count for refresh
      posts.clear();
      finalHomeScreen.clear();
    }

    setState(() {
      isLoading = true;
    });

    categoriesList.clear();
    avatarCards.clear();

    // Fetch data from InZoneDatabase
    final response = await InZoneDatabase.getFeed();

    // Ensure the response contains the expected structure
    if (response != null &&
        response.containsKey('posts') &&
        response.containsKey('characters')) {
      // Parse the posts and avatars
      List<dynamic> fetchedPosts = response['posts'];
      List<dynamic> fetchedCharacters = response['characters'];

      for (var characterJson in fetchedCharacters) {
        InZoneAvatar avatar = InZoneAvatar.fromJson(characterJson);
        avatarCards.add(AvatarCard(avatar: avatar));
      }

      _addPostsToScreen(fetchedPosts);
    } else {
      throw Exception('Invalid response structure');
    }
  }

  Future<void> _loadMorePosts() async {
    setState(() {
      isLoadingMore = true;
    });

    // Fetch the next batch of posts
    final response = await InZoneDatabase.getFeed(); // You can paginate here
    if (response != null && response.containsKey('posts')) {
      List<dynamic> fetchedPosts = response['posts'];
      _addPostsToScreen(fetchedPosts);
    }

    setState(() {
      isLoadingMore = false;
    });
  }

  void _addPostsToScreen(List<dynamic> fetchedPosts) async {
    for (var postJson
        in fetchedPosts.skip(_currentPage * _pageSize).take(_pageSize)) {
      InZonePost post = InZonePost.fromJson(postJson);
      posts.add(PostCard(
        post: post,
        onTap: (postId) {
          print('You tapped on post with ID: $postId');
        },
        onDeleted: (postId) {
          setState(() {
            posts.removeWhere((pc) => pc.post.id == postId);
            finalHomeScreen.removeWhere((w) => w is PostCard && (w as PostCard).post.id == postId);
          });
        },
        onUpdated: (updatedPost) {
          setState(() {
            for (var pc in posts) {
              if (pc.post.id == updatedPost.id) {
                pc.post = updatedPost;
              }
            }
            for (var w in finalHomeScreen) {
              if (w is PostCard && w.post.id == updatedPost.id) {
                w.post = updatedPost;
              }
            }
          });
        },
      ));
      if (!categoriesList.contains(post.category) && post.category.isNotEmpty) {
        categoriesList.add(post.category);
      }

      // Add unique categories to the list
    }
    // final responseHuman = await InZoneDatabase.getHumanFeed();
    // // Ensure the response contains the expected structure
    // if (responseHuman != null ) {
    //   print(responseHuman);
    //   List<dynamic> fetchedHumanPosts = responseHuman['posts'];
    //   for (var postJson in fetchedHumanPosts.skip(_currentPage * _pageSize).take(_pageSize)) {
    //
    //     if (postJson.containsKey("aiName")) {
    //       InZonePost post = InZonePost.fromJsonForHumans(postJson);
    //       InZoneAvatar avatar = InZoneAvatar.fromRepostJson(postJson);
    //       finalHomeScreen.add(RepostCard(post: post, repost: avatar, aiChat: postJson["aiChatContent"],
    //
    //       ));
    //     } else {
    //       InZonePost post = InZonePost.fromJsonForHumans(postJson);
    //       posts.add(PostCard(
    //         post: post,
    //         onTap: (postId) {
    //           print('You tapped on post with ID: $postId');
    //         },
    //       ));
    //       if (!categoriesList.contains(post.category) && post.category.isNotEmpty) {
    //         categoriesList.add(post.category);
    //       }
    //     }
    //
    //
    //     // Add unique categories to the list
    //
    //   }
    //   finalHomeScreen.shuffle();
    // }
    setState(() {
      isLoading = false;
    });
    posts.shuffle();

    for (int i = 0; i < posts.length; i++) {
      if (i % 7 == 0 && i != 0) {
        finalHomeScreen.add(SizedBox(
          height: 550, // Adjust height as necessary
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                child: Text(
                  "Most Popular",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: avatarCards.map((avatarCard) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.0),
                        child: avatarCard,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ));
      }
      finalHomeScreen.add(posts.elementAt(i));
    }
    _currentPage++; // Increment the page count after adding posts
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Theme.of(context).canvasColor,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Conditionally render the back button
                if (Navigator.canPop(context))
                  IconButton(
                    icon: Icon(
                      Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
                      color: Colors.black,
                    ),
                    onPressed: _handleBackButtonPress,
                  ),
                if (!isSearching)
                  Text(
                    "Explore",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                if (isSearching)
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (searchText) async {
                        // Trigger the feed fetching function when user submits the text
                        await getFeed();
                        setState(() {
                          isSearching =
                              false; // Exit search mode after submission
                        });
                      },
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isSearching = !isSearching; // Toggle search mode
                    });
                  },
                  child: Icon(
                    isSearching ? Icons.close : Icons.search,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          )),
      body: SafeArea(
        left: false,
        right: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await getFeed();
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10),
                  child: SizedBox(
                    height: 550, // Adjust the height to suit your layout
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment
                          .start, // Aligns the text to the start
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 10),
                          child: Text(
                            "Most Popular",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(
                            height:
                                10), // Add some spacing between text and avatar row
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection:
                                Axis.horizontal, // Set horizontal scrolling
                            child: Row(
                              children: avatarCards,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                isLoading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 10),
                        child: buildShimmerCategoryBar(),
                      )
                    : categoriesList.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: CategorySelectorBar(
                                categories: categoriesList, onTap: (value) {}),
                          )
                        : const Text(
                            "No categories available"), // Fallback for empty categories
                const SizedBox(height: 20),
                isLoading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: List.generate(
                              10, (index) => buildShimmerPostCard()),
                        ),
                      )
                    : posts.isNotEmpty
                        ? Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: posts,
                            ),
                          )
                        : const Text(
                            "No posts available"), // Fallback for empty posts
              ],
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

  void _handleBackButtonPress() {
    // Check if we can pop the current screen
    if (context.canPop()) {
      context.pop();
    } else {
      // If we can't pop, we might be at the root, show exit confirmation
      _showExitConfirmationDialog(context);
    }
  }

  void _showExitConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Are you sure you want to exit?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Then exit the app
                SystemNavigator.pop();
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }
}
