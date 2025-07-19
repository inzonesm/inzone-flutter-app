import 'package:flutter/material.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/data/inzone_post.dart';

class UserPostsTab extends StatelessWidget {
  final List<InZonePost> posts;
  final String profileImageUrl;
  final bool isLoading;

  const UserPostsTab({
    super.key,
    required this.posts,
    required this.profileImageUrl,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      // While parent is fetching data, show an empty box.
      // The parent screen (e.g., ProfileScreen) is responsible for showing a loading indicator.
      return const SizedBox();
    }

    if (posts.isEmpty) {
      return const Center(
        child: Text(
          'No posts found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // Use CustomScrollView with SliverOverlapInjector for proper NestedScrollView integration
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(15.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == posts.length) {
                  // Add some space at the bottom of the list.
                  return const SizedBox(height: 100);
                }
                return Column(
                  children: [
                    PostCard(
                      post: posts[index],
                      profileImageUrl: profileImageUrl,
                      showHue: false,
                      onTap: (postId) {},
                      inProfile: true,
                    ),
                    if (index < posts.length - 1) const SizedBox(height: 15),
                  ],
                );
              },
              childCount: posts.length + 1,
            ),
          ),
        ),
      ],
    );
  }
}
