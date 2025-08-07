import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final String avatarId;
  final VoidCallback onBack;
  final List<Widget>? actions;

  const ChatAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    required this.avatarId,
    required this.onBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).canvasColor,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: GestureDetector(
          onTap: onBack,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios,
                  size: 18,
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).cardColor,
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    color: null, // Remove any color overlay
                    colorBlendMode: BlendMode.srcOver, // Use default blend mode
                    placeholder: (context, url) => const SizedBox(),
                    errorWidget: (context, url, error) {
                      return const Center(
                        child: Icon(Icons.account_circle, size: 40),
                      );
                    },
                  )
                : const Center(
                    child: Icon(Icons.account_circle, size: 40),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
