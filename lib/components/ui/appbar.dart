import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? greeting;
  final String? userName;
  final String? userPoints;
  final String? profileImageUrl;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onPointsTap;

  const CustomAppBar({
    super.key,
    this.greeting,
    this.userName,
    this.userPoints,
    this.profileImageUrl,
    this.onSearchTap,
    this.onProfileTap,
    this.onPointsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Row(
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'InZone',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      "Hello",
                      style: TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(100);
}
