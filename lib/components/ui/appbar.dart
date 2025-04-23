import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? greeting;
  final String? title;
  final String? subtitle;
  final String? userPoints;
  final String? profileImageUrl;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onPointsTap;
  final bool isHome;
  final bool isGroup;
  final bool isChat;
  final bool isImage;
  final bool isSettings;
  final String userName;

  const CustomAppBar(
      {super.key,
      this.greeting,
      this.title,
      this.subtitle,
      this.userPoints,
      this.profileImageUrl,
      this.onSearchTap,
      this.onProfileTap,
      this.onPointsTap,
      this.isHome = false,
      this.isGroup = false,
      this.isChat = false,
      this.isImage = true,
      this.isSettings = false,
      this.userName = "Loading"});

  @override
  Widget build(BuildContext context) {
    GestureDetector(
      onTap: onProfileTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
          image: profileImageUrl != null
              ? DecorationImage(
                  image: NetworkImage(profileImageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: profileImageUrl == null
            ? const Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              )
            : null,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: isSettings ? 12 : 24.0, vertical: 12.0),
        child: isHome
            ? Row(
                children: [
                  if (isSettings)
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(CupertinoIcons.back),
                    ),
                  Text(
                    isGroup
                        ? 'Groups'
                        : isChat
                            ? 'Chats'
                            : isSettings
                                ? title ?? 'InZone'
                                : 'InZone',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  if (isGroup)
                    GestureDetector(
                      onTap: onSearchTap,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Theme.of(context).iconTheme.color,
                          size: 24,
                        ),
                      ),
                    ),
                  if (isGroup) const SizedBox(width: 12),
                  // points display
                  if (isGroup)
                    GestureDetector(
                      onTap: onPointsTap,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Theme.of(context).cardColor,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(
                                Icons.local_police,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              userPoints ?? '0',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isChat)
                    GestureDetector(
                      onTap: onPointsTap,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Theme.of(context).cardColor,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(
                                CupertinoIcons.chat_bubble_2,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '0',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            : isGroup
                ? Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.back,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      isImage
                          ? GestureDetector(
                              onTap: onProfileTap,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    width: 1.5,
                                  ),
                                ),
                                child: profileImageUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          profileImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            // Fallback to RandomAvatar if the image fails to load
                                            return RandomAvatar(title ?? 'User',
                                                height: 48, width: 48);
                                          },
                                        ),
                                      )
                                    : RandomAvatar(title ?? 'User',
                                        height: 48, width: 48),
                              ),
                            )
                          : const SizedBox(),
                      isImage ? const SizedBox(width: 12) : const SizedBox(),
                      Text(
                        title ?? 'Guest',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  )
                : const SizedBox(),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

class CustomAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  CustomAppBarDelegate({required this.child, this.height = 70});

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
