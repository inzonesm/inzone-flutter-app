import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/services/notification_event_service.dart';

class CommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Simple ID generation function
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (999 * (DateTime.now().microsecond / 1000000)).round()).toString();
  }

  /// Add a new comment or reply to a post
  static Future<String?> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
    String? postAuthorId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final commentId = _generateId();
      final now = DateTime.now().toUtc();
      
      final commentData = {
        'id': commentId,
        'author': user.displayName ?? user.email ?? 'Anonymous',
        'text': content,
        'userId': user.uid,
        'postId': postId,
        'parentCommentId': parentCommentId,
        'timestamp': now.millisecondsSinceEpoch.toString(),
        'createdAt': Timestamp.fromDate(now),
        'likedBy': <String>[],
        'dislikedBy': <String>[],
        'replyCount': 0,
        'isReply': parentCommentId != null,
      };

      // Use batch write for atomic operations
      final batch = _firestore.batch();

      // Reference to the post's comment document
      final postCommentDocRef = _firestore.collection('postComments').doc(postId);
      
      // Get current comments
      final postCommentDoc = await postCommentDocRef.get();
      List<dynamic> currentComments = [];
      
      if (postCommentDoc.exists) {
        currentComments = postCommentDoc.data()?['comments'] ?? [];
      }

      // Add the new comment
      currentComments.add(commentData);

      // If this is a reply, increment parent's reply count
      if (parentCommentId != null) {
        for (int i = 0; i < currentComments.length; i++) {
          final comment = currentComments[i];
          if (comment['id'] == parentCommentId) {
            currentComments[i]['replyCount'] = (comment['replyCount'] ?? 0) + 1;
            break;
          }
        }
      }

      // Update the document
      batch.set(postCommentDocRef, {'comments': currentComments}, SetOptions(merge: true));

      // Commit the batch
      await batch.commit();

      // Send notification if this is not the post author commenting on their own post
      if (postAuthorId != null && postAuthorId != user.uid) {
        try {
          await NotificationEventService.onPostEngagement(
            postId: postId,
            type: parentCommentId != null ? 'reply' : 'comment',
            userId: user.uid,
            postAuthorId: postAuthorId,
            content: content,
          );
        } catch (e) {
          debugPrint('Failed to send notification: $e');
        }
      }

          // If this is a reply, also notify the parent comment author
          if (parentCommentId != null) {
            try {
              final parentComment = currentComments.firstWhere(
                (c) => c['id'] == parentCommentId,
                orElse: () => null,
              );
              
              if (parentComment != null) {
                final parentAuthorId = parentComment['userId'];
                if (parentAuthorId != null && parentAuthorId != user.uid) {
                  // Send a reply notification using the existing post engagement system
                  await NotificationEventService.onPostEngagement(
                    postId: postId,
                    type: 'comment_reply',
                    userId: user.uid,
                    postAuthorId: parentAuthorId,
                    content: 'Replied to your comment: $content',
                  );
                }
              }
            } catch (e) {
              debugPrint('Failed to send reply notification: $e');
            }
          }      return commentId;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      return null;
    }
  }

  /// Get comments for a post with proper threading
  static Future<List<CommentClass>> getCommentsForPost(String postId) async {
    try {
      final postCommentDoc = await _firestore.collection('postComments').doc(postId).get();
      
      if (!postCommentDoc.exists) return [];
      
      final data = postCommentDoc.data();
      if (data == null) return [];
      
      final commentsList = data['comments'] as List<dynamic>? ?? [];
      
      // Separate parent comments and replies
      final Map<String, CommentClass> parentComments = {};
      final Map<String, List<CommentClass>> repliesByParent = {};
      
      for (final commentData in commentsList) {
        final comment = CommentClass.fromJson(Map<String, dynamic>.from(commentData));
        
        if (comment.parentCommentId == null) {
          // This is a parent comment
          parentComments[comment.id] = comment;
          repliesByParent[comment.id] = [];
        } else {
          // This is a reply
          if (!repliesByParent.containsKey(comment.parentCommentId!)) {
            repliesByParent[comment.parentCommentId!] = [];
          }
          repliesByParent[comment.parentCommentId!]!.add(comment);
        }
      }
      
      // Attach replies to parent comments and sort
      final List<CommentClass> result = [];
      
      // Sort parent comments by timestamp (newest first for top-level)
      final sortedParents = parentComments.values.toList();
      sortedParents.sort((a, b) {
        try {
          final aTime = int.parse(a.timestamp);
          final bTime = int.parse(b.timestamp);
          return bTime.compareTo(aTime); // Newest first
        } catch (e) {
          return 0;
        }
      });
      
      for (final parentComment in sortedParents) {
        // Add parent comment
        final replies = repliesByParent[parentComment.id] ?? [];
        
        // Sort replies by timestamp (newest first)
        replies.sort((a, b) {
          try {
            final aTime = int.parse(a.timestamp);
            final bTime = int.parse(b.timestamp);
            return bTime.compareTo(aTime); // Newest first
          } catch (e) {
            return 0;
          }
        });
        
        // Create a new parent comment with updated reply info
        final updatedParent = CommentClass(
          author: parentComment.author,
          text: parentComment.text,
          timestamp: parentComment.timestamp,
          id: parentComment.id,
          postId: parentComment.postId,
          userId: parentComment.userId,
          parentCommentId: parentComment.parentCommentId,
          replyCount: replies.length,
          isReply: false,
          replies: replies.map((r) => ReplyClass(
            name: r.author,
            text: r.text,
            uid: r.id,
          )).toList(),
          likedBy: parentComment.likedBy,
          dislikedBy: parentComment.dislikedBy,
          profilePictureUrl: parentComment.profilePictureUrl,
        );
        
        result.add(updatedParent);
        
        // Add replies as separate items for the UI
        for (final reply in replies) {
          result.add(reply);
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('Error getting comments: $e');
      return [];
    }
  }

  /// Get replies for a specific comment
  static Future<List<CommentClass>> getRepliesForComment(String postId, String parentCommentId) async {
    try {
      final postCommentDoc = await _firestore.collection('postComments').doc(postId).get();
      
      if (!postCommentDoc.exists) return [];
      
      final data = postCommentDoc.data();
      if (data == null) return [];
      
      final commentsList = data['comments'] as List<dynamic>? ?? [];
      
      final replies = <CommentClass>[];
      
      for (final commentData in commentsList) {
        final comment = CommentClass.fromJson(Map<String, dynamic>.from(commentData));
        
        if (comment.parentCommentId == parentCommentId) {
          replies.add(comment);
        }
      }
      
      // Sort replies by timestamp (newest first)
      replies.sort((a, b) {
        try {
          final aTime = int.parse(a.timestamp);
          final bTime = int.parse(b.timestamp);
          return bTime.compareTo(aTime);
        } catch (e) {
          return 0;
        }
      });
      
      return replies;
    } catch (e) {
      debugPrint('Error getting replies: $e');
      return [];
    }
  }

  /// Update comment like/dislike
  static Future<bool> updateCommentReaction({
    required String postId,
    required String commentId,
    required String userId,
    required bool isLike, // true for like, false for dislike
    required bool isAdding, // true to add, false to remove
  }) async {
    try {
      final postCommentDocRef = _firestore.collection('postComments').doc(postId);
      
      return await _firestore.runTransaction((transaction) async {
        final postCommentDoc = await transaction.get(postCommentDocRef);
        
        if (!postCommentDoc.exists) return false;
        
        final data = postCommentDoc.data();
        if (data == null) return false;
        
        List<dynamic> commentsList = List.from(data['comments'] ?? []);
        
        // Find and update the comment
        for (int i = 0; i < commentsList.length; i++) {
          if (commentsList[i]['id'] == commentId) {
            List<String> likedBy = List<String>.from(commentsList[i]['likedBy'] ?? []);
            List<String> dislikedBy = List<String>.from(commentsList[i]['dislikedBy'] ?? []);
            
            if (isLike) {
              if (isAdding) {
                if (!likedBy.contains(userId)) {
                  likedBy.add(userId);
                }
                dislikedBy.remove(userId); // Remove from dislike if present
              } else {
                likedBy.remove(userId);
              }
            } else {
              if (isAdding) {
                if (!dislikedBy.contains(userId)) {
                  dislikedBy.add(userId);
                }
                likedBy.remove(userId); // Remove from like if present
              } else {
                dislikedBy.remove(userId);
              }
            }
            
            commentsList[i]['likedBy'] = likedBy;
            commentsList[i]['dislikedBy'] = dislikedBy;
            break;
          }
        }
        
        transaction.update(postCommentDocRef, {'comments': commentsList});
        return true;
      });
    } catch (e) {
      debugPrint('Error updating comment reaction: $e');
      return false;
    }
  }

  /// Delete a comment or reply
  static Future<bool> deleteComment({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    try {
      final postCommentDocRef = _firestore.collection('postComments').doc(postId);
      
      return await _firestore.runTransaction((transaction) async {
        final postCommentDoc = await transaction.get(postCommentDocRef);
        
        if (!postCommentDoc.exists) return false;
        
        final data = postCommentDoc.data();
        if (data == null) return false;
        
        List<dynamic> commentsList = List.from(data['comments'] ?? []);
        
        // Find the comment to delete
        Map<String, dynamic>? commentToDelete;
        int commentIndex = -1;
        
        for (int i = 0; i < commentsList.length; i++) {
          if (commentsList[i]['id'] == commentId) {
            commentToDelete = commentsList[i];
            commentIndex = i;
            break;
          }
        }
        
        if (commentToDelete == null || commentIndex == -1) return false;
        
        // Check if user owns the comment
        if (commentToDelete['userId'] != userId) return false;
        
        final parentCommentId = commentToDelete['parentCommentId'];
        
        // Remove the comment
        commentsList.removeAt(commentIndex);
        
        // If this was a reply, decrement parent's reply count
        if (parentCommentId != null) {
          for (int i = 0; i < commentsList.length; i++) {
            if (commentsList[i]['id'] == parentCommentId) {
              final currentCount = commentsList[i]['replyCount'] ?? 0;
              commentsList[i]['replyCount'] = (currentCount - 1).clamp(0, double.infinity).toInt();
              break;
            }
          }
        } else {
          // If this was a parent comment, also remove all its replies
          commentsList.removeWhere((comment) => comment['parentCommentId'] == commentId);
        }
        
        transaction.update(postCommentDocRef, {'comments': commentsList});
        return true;
      });
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }
}
