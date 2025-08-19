import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CommentsTile extends StatefulWidget {
  final String commentText;
  final String profilePictureUrl;
  final String author;
  final String timestamp;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final String currentUserId;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;

  const CommentsTile({
    super.key,
    required this.commentText,
    required this.profilePictureUrl,
    required this.author,
    required this.timestamp,
    required this.likedBy,
    required this.dislikedBy,
    required this.currentUserId,
    this.onLike,
    this.onDislike,
  });

  @override
  _CommentsTileState createState() => _CommentsTileState();
}

class _CommentsTileState extends State<CommentsTile> {
  late bool isLiked;
  late bool isDisliked;

  @override
  void initState() {
    super.initState();
    isLiked = widget.likedBy.contains(widget.currentUserId);
    isDisliked = widget.dislikedBy.contains(widget.currentUserId);
  }

  @override
  void didUpdateWidget(CommentsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update like/dislike status if the underlying data changes
    isLiked = widget.likedBy.contains(widget.currentUserId);
    isDisliked = widget.dislikedBy.contains(widget.currentUserId);
  }

  void toggleLike() {
    setState(() {
      if (isLiked) {
        widget.likedBy.remove(widget.currentUserId);
      } else {
        widget.likedBy.add(widget.currentUserId);
        if (isDisliked) {
          widget.dislikedBy.remove(widget.currentUserId);
          isDisliked = false;
        }
      }
      isLiked = !isLiked;
    });

    if (widget.onLike != null) {
      widget.onLike!();
    }
  }

  void toggleDislike() {
    setState(() {
      if (isDisliked) {
        widget.dislikedBy.remove(widget.currentUserId);
      } else {
        widget.dislikedBy.add(widget.currentUserId);
        if (isLiked) {
          widget.likedBy.remove(widget.currentUserId);
          isLiked = false;
        }
      }
      isDisliked = !isDisliked;
    });

    if (widget.onDislike != null) {
      widget.onDislike!();
    }
  }

  String formatTimestamp(String timestamp) {
    try {
      final DateTime date = DateTime.parse(timestamp).toUtc();
      final Duration difference = DateTime.now().toUtc().difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} years ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Picture
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: widget.profilePictureUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.profilePictureUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SizedBox(),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.account_circle, size: 40),
                  )
                : const Icon(Icons.account_circle, size: 40),
          ),
          const SizedBox(width: 10),

          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author and Timestamp
                Row(
                  children: [
                    Text(
                      widget.author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).textTheme.titleMedium?.color,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatTimestamp(widget.timestamp),
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Comment Text
                Text(
                  widget.commentText,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.normal,
                  ),
                ),

                // Like/Dislike Actions
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                              size: 16,
                              color: isLiked
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).iconTheme.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.likedBy.length.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: toggleDislike,
                        child: Row(
                          children: [
                            Icon(
                              isDisliked
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined,
                              size: 16,
                              color: isDisliked
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).iconTheme.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.dislikedBy.length.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
