import 'dart:math';
import 'package:flutter/material.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/theme/app_colors.dart';

class AvatarCard extends StatefulWidget {
  InZoneAvatar avatar;
  final Function(String)? onTap;

  AvatarCard({super.key, required this.avatar, this.onTap});

  @override
  State<AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends State<AvatarCard> {
  bool isUpvoted = false;
  bool isDownvoted = false;
  int voteCount = 23;
  int comments = 23;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    voteCount = getRandomNumber(0, 999);
    comments = getRandomNumber(0, 300);
    _loadLastMessage();
  }

  Future<void> _loadLastMessage() async {
    final msg = await InZoneDatabase.getAvatarChatLastMessage(
        widget.avatar.username);
    if (msg != null && mounted) {
      setState(() => _lastMessage = msg);
    }
  }

  int getRandomNumber(int min, int max) {
    final random = Random();
    return min + random.nextInt(max - min + 1);
  }

  void handleUpvote() {
    setState(() {
      if (isUpvoted) {
        voteCount--;
        isUpvoted = false;
      } else {
        if (isDownvoted) {
          voteCount++;
          isDownvoted = false;
        }
        voteCount++;
        isUpvoted = true;
      }
    });
  }

  void handleDownvote() {
    setState(() {
      if (isDownvoted) {
        voteCount++;
        isDownvoted = false;
      } else {
        if (isUpvoted) {
          voteCount--;
          isUpvoted = false;
        }
        voteCount--;
        isDownvoted = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: GestureDetector(
        onTap: () {},
        onDoubleTap: () {},
        child: Container(
          height: 580,
          width: 250,
          padding: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top image
              SizedBox(
                height: 280,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: Image.network(
                    widget.avatar.profilePicture,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          widget.avatar.name.isNotEmpty
                              ? widget.avatar.name[0].toUpperCase()
                              : "?",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Text content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        widget.avatar.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
// Last message preview or greeting bubble
                      Builder(builder: (_) {
                        final bubbleText = _lastMessage ??
                            (widget.avatar.greeting?.isNotEmpty == true
                                ? widget.avatar.greeting
                                : null);
                        final isHistory = _lastMessage != null;
                        return SizedBox(
                          height: 65,
                          child: bubbleText != null
                              ? Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isHistory)
                                        Text(
                                          'Last message',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .colorScheme.primary
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      Text(
                                        isHistory
                                            ? bubbleText
                                            : '"$bubbleText"',
                                        style: TextStyle(
                                          fontStyle: isHistory
                                              ? FontStyle.normal
                                              : FontStyle.italic,
                                          fontSize: 12,
                                          color:
                                              theme.textTheme.bodyMedium?.color,
                                        ),
                                        maxLines: isHistory ? 2 : 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        );
                      }),

                      // Bio
                      SizedBox(
                        height: 52,
                        child: Text(
                          widget.avatar.bio,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color,
                            height: 1.3,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: handleUpvote,
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: isUpvoted
                                      ? Colors.green
                                      : theme.iconTheme.color,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$voteCount',
                                style: TextStyle(
                                  color: isUpvoted
                                      ? Colors.green
                                      : isDownvoted
                                          ? Colors.red
                                          : theme.textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 2),
                              GestureDetector(
                                onTap: handleDownvote,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: isDownvoted
                                      ? Colors.red
                                      : theme.iconTheme.color,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 16,
                                color: theme.iconTheme.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                comments.toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return ChatScreen(
                                  userData: ChatUser(
                                    name: widget.avatar.name,
                                    email: widget.avatar.username,
                                    chatId: null,
                                    isHuman: false,
                                    profilePictureURL:
                                        widget.avatar.profilePicture,
                                    greeting: widget.avatar.greeting,
                                  ),
                                );
                              }));
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                            child: const Text(
                              "Chat",
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
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
}
