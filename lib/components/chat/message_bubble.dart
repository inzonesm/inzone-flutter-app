import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:inzone/theme/light_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inzone/components/video/video_player_widget_post_screen.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime? timestamp;
  final String? senderName;
  final Widget? senderAvatar;
  final VoidCallback? onShare;
  final VoidCallback?
      onSenderTap; // New callback for tapping sender avatar/name
  final String? imageUrl; // New: image URL
  final String? videoUrl; // New: video URL
  final String? videoThumbnailUrl; // New: video thumbnail URL

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.timestamp,
    this.senderName,
    this.senderAvatar,
    this.onShare,
    this.onSenderTap,
    this.imageUrl,
    this.videoUrl,
    this.videoThumbnailUrl,
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
                // Display image if present
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 250,
                          maxHeight: 300,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 250,
                            height: 250,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 250,
                            height: 250,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Display video if present
                if (videoUrl != null && videoUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 250,
                          maxHeight: 300,
                        ),
                        child: VideoPlayerWidgetPostScreen(videoUrl!),
                      ),
                    ),
                  ),
                Container(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
                    margin: EdgeInsets.only(
                        right: isMe ? 10 : 50, left: isMe ? 50 : 10),
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
                          // Display text message if present
                          if (message.isNotEmpty)
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
