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
  final String? timestampLabel;
  final bool showTimestamp;
  final String? statusLabel;
  final String? senderName;
  final Widget? senderAvatar;
  final VoidCallback? onShare;
  final VoidCallback?
      onSenderTap; // New callback for tapping sender avatar/name
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? imageUrl; // New: image URL
  final String? videoUrl; // New: video URL
  final String? videoThumbnailUrl; // New: video thumbnail URL

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.timestamp,
    this.timestampLabel,
    this.showTimestamp = false,
    this.statusLabel,
    this.senderName,
    this.senderAvatar,
    this.onShare,
    this.onSenderTap,
    this.onTap,
    this.onLongPress,
    this.imageUrl,
    this.videoUrl,
    this.videoThumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasMeta = timestamp != null || statusLabel != null || timestampLabel != null;
    final showMetaContent = (showTimestamp && timestampLabel != null) || statusLabel != null;
    final metaParts = <String>[];
    if (showTimestamp && timestampLabel != null) {
      metaParts.add(timestampLabel!);
    }
    if (statusLabel != null && statusLabel!.trim().isNotEmpty) {
      metaParts.add(statusLabel!.trim());
    }
    final metaText = metaParts.join('  •  ');

    final bubble = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
        margin: EdgeInsets.only(right: isMe ? 10 : 50, left: isMe ? 50 : 10),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 0.5,
              spreadRadius: 0.5,
              offset: const Offset(0.5, 0.5),
            ),
          ],
          color: isMe
              ? Theme.of(context).myChatBubbleColor
              : Theme.of(context).otherChatBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(8),
            bottomLeft:
                isMe ? const Radius.circular(8) : const Radius.circular(0),
          ),
        ),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                        color:
                            Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ),
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
              if (message.isNotEmpty)
                Text(
                  message,
                  style: TextStyle(
                    color: isMe
                        ? Theme.of(context).myChatTextColor
                        : Theme.of(context).otherChatTextColor,
                  ),
                ),
              if (hasMeta)
                SizedBox(
                  height: 14,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: showMetaContent
                        ? Text(
                            metaText,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Theme.of(context).myChatTextColor
                                  : Theme.of(context).otherChatTextColor,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

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
                bubble,
                const SizedBox(height: 5),
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
}
