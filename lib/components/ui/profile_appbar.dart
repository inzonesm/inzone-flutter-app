import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inzone/screen/settings/settings_screen.dart';
import 'package:random_avatar/random_avatar.dart';

class ProfileAppbar extends StatelessWidget {
  final String name;
  final String bio;
  final String username;
  final String profileImageUrl;
  final int postCount;
  final int followingCount;
  final int followersCount;
  final Widget actionButtons;
  final bool isProfilePage;

  const ProfileAppbar({
    super.key,
    required this.name,
    required this.bio,
    required this.username,
    required this.postCount,
    required this.followingCount,
    required this.followersCount,
    required this.actionButtons,
    this.isProfilePage = false,
    required this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: isProfilePage
            ? null
            : const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 0.5)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  username,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(CupertinoIcons.ellipsis_vertical),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Avatar and stats
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: profileImageUrl.isEmpty
                      ? RandomAvatar(name, height: 80, width: 80)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // name을 왼쪽 정렬
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatColumn(
                                postCount.toString(), "posts", context),
                            _buildStatColumn(followingCount.toString(),
                                "following", context),
                            _buildStatColumn(followersCount.toString(),
                                "followers", context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                bio.isEmpty ? "No bio set yet" : bio,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),

            actionButtons,
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(150);
}

class CustomAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  CustomAppBarDelegate({required this.child, this.height = 100});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
