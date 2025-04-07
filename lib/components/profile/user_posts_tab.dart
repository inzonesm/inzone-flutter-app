import 'package:flutter/material.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';

class UserPostsTab extends StatefulWidget {
  final String userId;
  final bool ai;

  const UserPostsTab({super.key, required this.userId, required this.ai});

  @override
  State<UserPostsTab> createState() => _UserPostsTabState();
}

class _UserPostsTabState extends State<UserPostsTab> {
  List<Widget> postWidgets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserPosts();
  }

  Future<void> fetchUserPosts() async {
    if (!mounted) return; // Check if widget is still mounted before proceeding

    setState(() {
      isLoading = true;
    });

    try {
      List? posts = [];
      if (widget.ai) {
        posts = await InZoneDatabase.getAIUserPosts(widget.userId);
      } else {
        posts = await InZoneDatabase.getUserPosts(widget.userId);
      }

      if (!mounted) return; // Check again after the async operation

      if (posts != null && posts.isNotEmpty) {
        setState(() {
          // Convert each post JSON to a PostCard widget
          postWidgets = [];
          posts ??= [];
          for (var postJson in posts!) {
            try {
              // Verify postJson is not null
              if (postJson == null) {
                continue;
              }

              // Create an InZonePost from the JSON
              final post = InZonePost.fromJson(postJson);

              // Return a PostCard widget
              postWidgets.add(PostCard(
                post: post,
                showHue: false,
                onTap: (postId) {},
              ));
            } catch (e) {}
          }
        });
      } else {}
    } finally {
      if (mounted) {
        // Check if still mounted before final setState
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (postWidgets.isEmpty) {
      return const Center(
        child: Text(
          'No posts found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchUserPosts,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: ListView.separated(
          itemCount: postWidgets.length,
          separatorBuilder: (context, index) => const SizedBox(height: 15),
          itemBuilder: (context, index) {
            return postWidgets[index];
          },
        ),
      ),
    );
  }
}
