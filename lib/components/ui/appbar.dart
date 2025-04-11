import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/chat/chat_screen.dart';

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
  final bool isOthers;
  final bool isImage;

  const CustomAppBar({
    super.key,
    this.greeting,
    this.title,
    this.subtitle,
    this.userPoints,
    this.profileImageUrl,
    this.onSearchTap,
    this.onProfileTap,
    this.onPointsTap,
    this.isHome = false,
    this.isOthers = false,
    this.isImage = true,
  });

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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 0.5)
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: isHome
              ? Row(
                  children: [
                    // profile image
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
                    ),
                    const SizedBox(width: 12),
                    // brand name and greeting
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title ?? 'InZone',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            subtitle ?? 'Welcome back',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // search button
                    GestureDetector(
                      onTap: onSearchTap,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade100,
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.black54,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // points display
                    GestureDetector(
                      onTap: onPointsTap,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.grey.shade100,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blue.shade400,
                              child: const Icon(
                                Icons.local_police,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              userPoints ?? '0',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // const SizedBox(width: 12),
                    // GestureDetector(
                    //   onTap: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) => ChatScreen(
                    //           userData: userName ?? 'Guest',
                    //         ),
                    //       ),
                    //     );
                    //   },
                    //   child: const SizedBox(
                    //     height: 16,
                    //     width: 16,
                    //     child: Icon(
                    //       Icons.chat_bubble_outline_rounded,
                    //       color: Colors.black,
                    //       size: 21,
                    //     ),
                    //   ),
                    // ),
                  ],
                )
              : isOthers
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.back,
                            color: Colors.black,
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
                                    color: Colors.blue,
                                    image: profileImageUrl != null
                                        ? DecorationImage(
                                            image:
                                                NetworkImage(profileImageUrl!),
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
                              )
                            : const SizedBox(),
                        isImage ? const SizedBox(width: 12) : const SizedBox(),
                        Text(
                          title ?? 'Guest',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(),
        ),
      ),
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
