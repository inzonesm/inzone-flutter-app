import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/screen/settings/settings_screen.dart';

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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
              ),
            ),
            Positioned(
              left: 16,
              bottom: -40,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                  image: profileImageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(profileImageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profileImageUrl.isEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: const Icon(Icons.account_circle, size: 80),
                      )
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 50), // 사진 공간 확보
        Row(
          crossAxisAlignment: CrossAxisAlignment.center, // 핵심: center로
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 0),
                    child: Text(
                      name,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  // Padding(
                  //   padding: const EdgeInsets.only(left: 24, right: 0),
                  //   child: Text(
                  //     username,
                  //     style: theme.textTheme.titleLarge,
                  //   ),
                  // ),
                  const SizedBox(height: 8), // name과 bio 사이 간격
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      bio.isEmpty ? "No bio set yet" : bio,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatColumn(postCount.toString(), "Posts", context),
                    const SizedBox(width: 20),
                    _buildStatColumn(
                        followingCount.toString(), "Following", context),
                    const SizedBox(width: 20),
                    _buildStatColumn(
                        followersCount.toString(), "Followers", context),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        actionButtons,
      ],
    );
  }

  Widget _buildStatColumn(String value, String label, BuildContext context) {
    return Column(
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
