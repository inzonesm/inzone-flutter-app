import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/screen/settings/settings_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final List<Map<String, String>> savedCharacters;
  final bool areCharactersLoading;
  final Function(String, String, String)? onCharacterTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

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
    this.savedCharacters = const [],
    this.areCharactersLoading = true,
    this.onCharacterTap,
    this.onFollowersTap,
    this.onFollowingTap,
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
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: profileImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: profileImageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          color: null, // Remove any color overlay
                          colorBlendMode:
                              BlendMode.srcOver, // Use default blend mode
                          errorWidget: (context, url, error) {
                            debugPrint('Error loading profile image: $error');
                            return const Icon(Icons.account_circle, size: 80);
                          },
                          placeholder: (context, url) => const SizedBox(),
                        )
                      : const Icon(Icons.account_circle, size: 80),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10, top: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              actionButtons,
            ],
          ),
        ),
        const SizedBox(height: 30),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      bio.isEmpty ? "No bio set yet" : bio,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatColumn(
                            postCount.toString(), "Posts", context, null),
                        const SizedBox(width: 20),
                        _buildStatColumn(followingCount.toString(), "Following",
                            context, onFollowingTap),
                        const SizedBox(width: 20),
                        _buildStatColumn(followersCount.toString(), "Followers",
                            context, onFollowersTap),
                      ],
                    ),
                  ),
                  if (savedCharacters.isNotEmpty)
                    _buildSavedCharactersSection(context)
                  else
                    const SizedBox(height: 20),

                  // const Padding(
                  //   padding: EdgeInsets.only(left: 24, right: 0),
                  //   child: Text(
                  //     "This is profile page for the users",
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSavedCharactersSection(BuildContext context) {
    if (areCharactersLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (savedCharacters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20.0),
            itemCount: savedCharacters.length,
            itemBuilder: (context, index) {
              final character = savedCharacters[index];
              return GestureDetector(
                onTap: () {
                  if (onCharacterTap != null &&
                      character['id'] != null &&
                      character['name'] != null &&
                      character['image'] != null) {
                    onCharacterTap!(character['id']!, character['name']!,
                        character['image']!);
                  }
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: character['image']!,
                            fit: BoxFit.cover,
                            color: null,
                            colorBlendMode: BlendMode.srcOver,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.withOpacity(0.2),
                              child: const Icon(FeatherIcons.user, size: 24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        character['name']!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(
      String value, String label, BuildContext context, VoidCallback? onTap) {
    Widget content = Row(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: content,
        ),
      );
    }

    return content;
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
