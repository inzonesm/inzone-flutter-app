import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/router/routes.dart';

class CommentsTile extends StatefulWidget {
  final String commentText;
  final String profilePictureUrl;
  final String author;
  final String timestamp;
  final String commentId;
  final String? parentCommentId;
  final String? parentCommentAuthor; // Author of the parent comment being replied to
  final String? postCreatorId; // ID of the post creator to identify if current user is creator
  final String? commentAuthorId; // ID of the comment author to check if they are the post creator
  final int replyCount;
  final bool isReply;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final String currentUserId;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onReply;
  final VoidCallback? onToggleReplies;
  final List<CommentClass>? replies;
  final bool showReplies;

  const CommentsTile({
    super.key,
    required this.commentText,
    required this.profilePictureUrl,
    required this.author,
    required this.timestamp,
    required this.commentId,
    this.parentCommentId,
    this.parentCommentAuthor,
    this.postCreatorId,
    this.commentAuthorId,
    this.replyCount = 0,
    this.isReply = false,
    required this.likedBy,
    required this.dislikedBy,
    required this.currentUserId,
    this.onLike,
    this.onDislike,
    this.onReply,
    this.onToggleReplies,
    this.replies,
    this.showReplies = false,
  });

  @override
  _CommentsTileState createState() => _CommentsTileState();
}

class _CommentsTileState extends State<CommentsTile> {
  late bool isLiked;
  late bool isDisliked;
  bool showRepliesExpanded = false;

  @override
  void initState() {
    super.initState();
    isLiked = widget.likedBy.contains(widget.currentUserId);
    isDisliked = widget.dislikedBy.contains(widget.currentUserId);
    showRepliesExpanded = widget.showReplies;
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
      // Comments store timestamps as epoch-millis strings (canonical) or
      // ISO-8601 strings (older comments) - support both.
      final int? millis = int.tryParse(timestamp);
      final DateTime date = millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
          : DateTime.parse(timestamp).toUtc();
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
    // Check if the comment author is the post creator
    // For AI posts, compare display names; for human posts, compare user IDs
    final bool isCommentAuthorCreator = widget.postCreatorId != null && 
                                       (widget.commentAuthorId == widget.postCreatorId ||
                                        widget.author == widget.postCreatorId);
    
    return Container(
      margin: EdgeInsets.only(
        // Spacing between the comments and their replies
        bottom: widget.isReply ? 8.0 : (widget.replyCount > 0 && widget.showReplies ? 3.6 : 12.0),
        left: widget.isReply ? 40.0 : 0.0, // Indent replies
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture - Make it tappable
              GestureDetector(
                onTap: () {
                  // Navigate to user profile if commentAuthorId is available
                  if (widget.commentAuthorId != null && widget.commentAuthorId!.isNotEmpty) {
                    context.push(Routes.regularProfilePath(widget.commentAuthorId!));
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: widget.profilePictureUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.profilePictureUrl,
                          width: widget.isReply ? 32 : 40, // Smaller for replies
                          height: widget.isReply ? 32 : 40,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.account_circle, size: widget.isReply ? 32 : 40),
                        )
                      : Icon(Icons.account_circle, size: widget.isReply ? 32 : 40),
                ),
              ),
              const SizedBox(width: 10),

              // Comment Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply indicator for nested comments: show replier name and, if creator, the Author tag; include timestamp on same line for replies
                    if (widget.isReply && widget.parentCommentId != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Replier's name first (no icon or reply text before it) - Make it tappable
                          GestureDetector(
                            onTap: () {
                              // Navigate to user profile if commentAuthorId is available
                              if (widget.commentAuthorId != null && widget.commentAuthorId!.isNotEmpty) {
                                context.push(Routes.regularProfilePath(widget.commentAuthorId!));
                              }
                            },
                            child: Text(
                              widget.author,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.titleMedium?.color,
                                ),
                            ),
                          ),
                          // Only show the Author tag (with bullet) when the replier is the post creator.
                          if (isCommentAuthorCreator) ...[
                            const SizedBox(width: 4),
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Author',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // timestamp for replies on same line to avoid an extra empty row
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

                    // Author and Timestamp (parent comments only)
                    if (!widget.isReply)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Navigate to user profile if commentAuthorId is available
                              if (widget.commentAuthorId != null && widget.commentAuthorId!.isNotEmpty) {
                                context.push(Routes.regularProfilePath(widget.commentAuthorId!));
                              }
                            },
                            child: Text(
                              widget.author,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.titleMedium?.color,
                                  ),
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

                    // Action Row (Like, Dislike, Reply)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          // Like button
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

                          // Dislike button
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
                          const SizedBox(width: 16),

                          // Reply button (only for non-reply comments to maintain 1-level threading)
                          if (!widget.isReply && widget.onReply != null)
                            InkWell(
                              onTap: widget.onReply,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.reply,
                                    size: 16,
                                    color: Theme.of(context).iconTheme.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reply',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // View Replies button for parent comments
                    if (!widget.isReply && widget.replyCount > 0 && widget.onToggleReplies != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: InkWell(
                          onTap: widget.onToggleReplies,
                          child: Row(
                            children: [
                              Icon(
                                widget.showReplies
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.showReplies
                                    ? 'Hide ${widget.replyCount} ${widget.replyCount == 1 ? 'reply' : 'replies'}'
                                    : 'View ${widget.replyCount} ${widget.replyCount == 1 ? 'reply' : 'replies'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),

          // Show replies if expanded and there are replies
          if (!widget.isReply && showRepliesExpanded && widget.replies != null && widget.replies!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0), // Reduced from 8.0 to 4.0
              child: Column(
                children: widget.replies!
                    .map((reply) => CommentsTile(
                          commentText: reply.text,
                          profilePictureUrl: reply.profilePictureUrl ?? '',
                          author: reply.author,
                          timestamp: reply.timestamp,
                          commentId: reply.id,
                          parentCommentId: reply.parentCommentId,
                          parentCommentAuthor: widget.author, // Pass parent author
                          postCreatorId: widget.postCreatorId, // Pass post creator ID
                          commentAuthorId: reply.userId, // Pass comment author ID
                          isReply: true,
                          likedBy: reply.likedBy ?? [],
                          dislikedBy: reply.dislikedBy ?? [],
                          currentUserId: widget.currentUserId,
                          onLike: () {
                            // Handle reply like
                          },
                          onDislike: () {
                            // Handle reply dislike
                          },
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
