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
  final VoidCallback?
      onSenderTap; // New callback for tapping sender avatar/name

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.timestamp,
    this.senderName,
    this.senderAvatar,
    this.onShare,
    this.onSenderTap,
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
            GestureDetector(
              onTap: onSenderTap,
              child: senderAvatar!,
            ),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 0.5,
                          spreadRadius: 0.5,
                          offset:
                              const Offset(0.5, 0.5), // horizontal, vertical
                        ),
                      ],
                      color: isMe
                          ? Theme.of(context).myChatBubbleColor
                          : Theme.of(context).otherChatBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(8),
                        topRight: const Radius.circular(8),
                        bottomRight: isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(8),
                        bottomLeft: isMe
                            ? const Radius.circular(8)
                            : const Radius.circular(0),
                      ),
                    ),
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMe && senderName != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 0.0),
                              child: GestureDetector(
                                onTap: onSenderTap,
                                child: Text(
                                  senderName!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
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
                          if (timestamp != null)
                            Align(
                                alignment: Alignment.centerRight,
                                child: Text(_formatTimestamp(timestamp!),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe
                                          ? Theme.of(context).myChatTextColor
                                          : Theme.of(context)
                                              .otherChatTextColor,
                                    )))
                        ],
                      ),
                    )),
                const SizedBox(
                  height: 5,
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
    // final now = DateTime.now().toUtc();
    // final today = DateTime(now.year, now.month, now.day);
    // final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // if (messageDate == today) {
    return DateFormat('h:mm a').format(dateTime.toLocal());
    // } else {
    // return DateFormat('MMM d, h:mm a').format(dateTime.toLocal());
  }
}
