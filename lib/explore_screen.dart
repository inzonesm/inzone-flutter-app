import 'dart:io';

import 'package:flutter/material.dart';
import 'package:inzone/components/avatar_card.dart';
import 'package:inzone/components/category_selector_bar.dart';
import 'package:inzone/components/post_card.dart';

import 'package:flutter/material.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/inzone_database.dart';
import 'package:shimmer/shimmer.dart';

import '../data/inzone_post.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Widget> posts = [];
  List<AvatarCard> avatarList = [];
  List<String> categoriesList = [];
  bool isLoading = true;
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<AvatarCard> avatarCards = [];
  late DateTime _startTime; // To store the start time
  int pageOpened = 0;
  getFeed() async {
    try {
      // Show shimmer effect by setting isLoading to true
      setState(() {
        isLoading = true;
      });

      // Clear existing posts and categories before fetching new data
      posts.clear();
      categoriesList.clear();

      // Fetch data from InZoneDatabase
      final response = await InZoneDatabase.getFeed();

      // Ensure the response contains the expected structure
      if (response != null &&
          response.containsKey('posts') &&
          response.containsKey('characters')) {
        // Parse the posts from the response
        List<dynamic> fetchedPosts = response['posts'];
        List<dynamic> fetchedCharacters = response['characters'];

        // Process posts
        for (var postJson in fetchedPosts) {
          // Parse the post from the JSON and create the PostCard widget
          InZonePost post = InZonePost.fromJson(postJson);
          posts.add(
            PostCard(
              post: post,
              onTap: (postId) {
                print('You tapped on post with ID: $postId');
              },
            ),
          );

          // Add unique categories to the list
          if (!categoriesList.contains(post.category) &&
              post.category.isNotEmpty) {
            categoriesList.add(post.category);
          }
        }

        // Add default posts if fetched posts are less than 2
        if (posts.length < 2) {
          List<InZonePost> tempPosts = [
            // Your hardcoded posts here...
          ];

          for (var post in tempPosts) {
            posts.add(
              PostCard(
                post: post,
                onTap: (postId) {},
              ),
            );

            if (!categoriesList.contains(post.category) &&
                post.category.isNotEmpty) {
              categoriesList.add(post.category);
            }
          }
        }

        avatarCards = fetchedCharacters.map((characterJson) {
          InZoneAvatar avatar = InZoneAvatar.fromJson(characterJson);
          return AvatarCard(avatar: avatar);
        }).toList();

        // Insert avatar cards at intervals in the posts list
        int interval = 10;
        for (int i = interval; i < posts.length; i += interval) {
          posts.insert(
            i,
            SizedBox(
              height: 450, // Adjust height as necessary
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
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: avatarCards.map((avatarCard) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: avatarCard,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Update state to stop showing shimmer and update UI
        setState(() {
          isLoading = false;
          posts.shuffle(); // Optionally shuffle the posts
          categoriesList =
              categoriesList.reversed.toList(); // Reverse categories if needed
        });
      } else {
        // Handle the case when response does not contain the expected structure
        throw Exception('Invalid response structure');
      }
    } catch (e) {
      // Handle any errors during the data fetching
      print("Error occurred while fetching data: $e");

      // Stop showing shimmer and show any existing data or error state
      setState(() {
        isLoading = false;
      });
    }
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

  @override
  void initState() {
    getFeed();
    super.initState();
    _startTime = DateTime.now();
    pageOpened+=1;
  }
  @override
  void dispose() {
    // TODO: implement dispose

    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('explore_screen', {"timeSpent" : timeSpent.inSeconds, "pageOpenedCount" : pageOpened});

    super.dispose();
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
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                if (!isSearching)
                  Text(
                    "Explore",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                if (isSearching)
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
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
}
