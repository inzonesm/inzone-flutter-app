import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:inzone/theme/light_theme.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime? timestamp;
  final String? senderName;
  final Widget? senderAvatar;
  final VoidCallback? onShare;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.timestamp,
    this.senderName,
    this.senderAvatar,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isMe && senderAvatar != null) ...[
            senderAvatar!,
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).myChatBubbleColor
                        : Theme.of(context).otherChatBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomRight: isMe
                          ? const Radius.circular(0)
                          : const Radius.circular(18),
                      bottomLeft: isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isMe && senderName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            senderName!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      Text(
                        message,
                        style: TextStyle(
                          color: isMe
                              ? Theme.of(context).myChatTextColor
                              : Theme.of(context).otherChatTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // if (timestamp != null)
                //   Padding(
                //     padding: const EdgeInsets.only(top: 2, right: 10, left: 10),
                //     child: Text(
                //       _formatTimestamp(timestamp!),
                //       style: TextStyle(
                //         fontSize: 10,
                //         color: Theme.of(context).textTheme.bodySmall?.color,
                //       ),
                //     ),
                //   ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
          if (!isMe && onShare != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: GestureDetector(
                onTap: onShare,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 15.0, right: 5.0),
                  child: SizedBox(
                    height: 25,
                    width: 25,
                    child: SvgPicture.asset(CustomIcons.send),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(dateTime);
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }
}
