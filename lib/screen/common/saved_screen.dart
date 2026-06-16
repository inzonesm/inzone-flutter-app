import 'package:flutter/material.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inzone/components/profile/avatar_card.dart';
import 'package:shimmer/shimmer.dart';

import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:toasty_box/toast_service.dart';

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

      // Clear existing posts
      posts.clear();
      categoriesList.clear();

      // Debug: Check raw SharedPreferences data
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.getString('likedPostDetails');

      // Get all liked posts
      List<InZonePost> savedPosts = await LikedPostsPreferences.getLikedPosts();

      if (savedPosts.isEmpty) {
      } else {
        // Print details of the first post to debug

        // Print all post IDs for debugging
      }

      if (!mounted) return;

      // Process saved posts - add each one to the list
      for (var post in savedPosts) {
        // Add the post widget to the list with padding
        posts.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: PostCard(
                post: post,
                showHue: false,
                onTap: (postId) {},
                onDeleted: (postId) {
                  setState(() {
                    posts.removeWhere((w) =>
                        w is Padding &&
                        (w.child is SizedBox && (w.child as SizedBox).child is PostCard &&
                            ((w.child as SizedBox).child as PostCard).post.id == postId));
                  });
                },
                onUpdated: (updatedPost) {
                  setState(() {
                    for (var i = 0; i < posts.length; i++) {
                      final w = posts[i];
                      if (w is Padding && w.child is SizedBox) {
                        final sb = w.child as SizedBox;
                        if (sb.child is PostCard) {
                          final pc = sb.child as PostCard;
                          if (pc.post.id == updatedPost.id) pc.post = updatedPost;
                        }
                      }
                    }
                  });
                },
              ),
            ),
          ),
        );

        // Add unique categories
        if (!categoriesList.contains(post.category) &&
            post.category.isNotEmpty) {
          categoriesList.add(post.category);
        }
      }

      // Stop loading and update UI sys
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      // Handle errors
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
      appBar: AppBar(
        // Empty AppBar with no title
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // Minimize AppBar height
      ),
      body: SafeArea(
        left: false,
        right: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await getSavedPosts(); // Refresh saved posts
          },
          child: isLoading
              ? _buildLoadingState()
              : posts.isEmpty
                  ? _buildEmptyState()
                  : _buildPostsList(),
        ),
      ),
    );
  }

  // Loading state with shimmer effect
  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ...List.generate(5, (index) => buildShimmerPostCard()),
        ],
      ),
    );
  }

  // Empty state when no posts are saved
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                "No saved posts yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Like posts to save them here",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // List of posts when available
  Widget _buildPostsList() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Top spacing
            const SizedBox(height: 16),

            // Display all posts
            ...posts,

            // Add spacing
            const SizedBox(height: 20),

            // Clear List button
            ElevatedButton(
              onPressed: () async {
                // Show confirmation dialog
                bool confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Clear All Saved Posts?"),
                        content: const Text(
                            "This will remove all your saved posts. This action cannot be undone."),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          TextButton(
                            child: const Text("Clear All",
                                style: TextStyle(color: Colors.red)),
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirm) {
                  // Clear all saved posts
                  await LikedPostsPreferences.clearAllLikedPosts();

                  if (!mounted) return;
                  // Show confirmation
                  ToastService.showToast(
                    context,
                    backgroundColor: Theme.of(context).canvasColor,
                    leading: const Icon(
                      Icons
                          .check_circle, // or Icons.x_circle, Icons.error, etc.
                      color: Colors
                          .redAccent, // or Colors.greenAccent, Colors.orange
                    ),
                    message: "All saved posts cleared",
                  );

                  // Refresh the screen
                  getSavedPosts();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                "Clear List",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Bottom spacing
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
