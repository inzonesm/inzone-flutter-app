import 'package:flutter/material.dart';
import 'dart:async';

import 'package:inzone/components/avatar_card.dart';
import 'package:inzone/components/post_card.dart';
import 'package:shimmer/shimmer.dart';

import 'data/inzone_post.dart';
import 'inzone_database.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Widget> posts = [];
  List<String> categoriesList = [];
  bool isLoading = true;
  List<AvatarCard> avatarCards = [];

  // Method to retrieve saved posts from SharedPreferences
  Future<void> getSavedPosts() async {
    try {
      // Show loading indicator
      setState(() {
        isLoading = true;
      });

      posts.clear();
      categoriesList.clear();

      List<InZonePost> savedPosts = await LikedPostsPreferences.getLikedPosts();
print(savedPosts);
      // Process saved posts
      for (var post in savedPosts) {
        // Add the post widget to the list
        posts.add(
          PostCard(
            post: post,
            onTap: (postId) {
              print('You tapped on post with ID: $postId');
            },
          ),
        );

        // Add unique categories
        if (!categoriesList.contains(post.category) && post.category.isNotEmpty) {
          categoriesList.add(post.category);
        }
      }

      // Stop loading and update UI
      setState(() {
        isLoading = false;
        if (posts.isEmpty) {
          posts.add(const Text("No saved posts available."));
        }
        categoriesList = categoriesList.reversed.toList();  // Reverse categories if needed
      });
    } catch (e) {
      // Handle errors
      print("Error occurred while fetching saved posts: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Shimmer effect while loading (can be customized for your UI)
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

  @override
  void initState() {
    super.initState();
    getSavedPosts();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      // appBar: PreferredSize(
      //   preferredSize: const Size.fromHeight(60),
      //   child: AppBar(
      //     elevation: 0,
      //     backgroundColor: Theme.of(context).canvasColor,
      //     iconTheme: const IconThemeData(color: Colors.black),
      //     title: const Text(
      //       "Favorites",
      //       textAlign: TextAlign.center,
      //       style: TextStyle(
      //         fontWeight: FontWeight.bold,
      //         color: Colors.black,
      //       ),
      //     ),
      //   ),
      // ),
      body: SafeArea(
        left: false,
        right: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await getSavedPosts(); // Refresh saved posts
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20,),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: posts.reversed.toList(),
                  ),
                )
                    : const Text("No saved posts available"), // Fallback for empty posts
              ],
            ),
          ),
        ),
      ),
    );
  }
}
