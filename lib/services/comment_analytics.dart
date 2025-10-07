import 'package:flutter/material.dart';
import 'package:inzone/services/appsflyer_service.dart';

class CommentAnalytics {
  static final AppsFlyerService _appsFlyerService = AppsFlyerService();

  /// Track when user opens reply composer
  static void trackCommentReplyOpen({
    required String postId,
    required String parentCommentId,
    String? category,
    String? userId,
  }) {
    try {
      _appsFlyerService.logEvent('comment_reply_open', {
        'post_id': postId,
        'parent_comment_id': parentCommentId,
        'category': category ?? 'unknown',
        'user_id': userId ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } catch (e) {
      debugPrint('Failed to track comment_reply_open: $e');
    }
  }

  /// Track when user successfully sends a reply
  static void trackCommentReplied({
    required String postId,
    required String parentCommentId,
    required String replyId,
    String? category,
    String? userId,
    int? replyLength,
  }) {
    try {
      _appsFlyerService.logEvent('comment_replied', {
        'post_id': postId,
        'parent_comment_id': parentCommentId,
        'reply_id': replyId,
        'category': category ?? 'unknown',
        'user_id': userId ?? '',
        'reply_length': replyLength ?? 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } catch (e) {
      debugPrint('Failed to track comment_replied: $e');
    }
  }

  /// Track when user expands a comment thread
  static void trackCommentThreadExpand({
    required String postId,
    required String parentCommentId,
    required int replyCount,
    String? userId,
  }) {
    try {
      _appsFlyerService.logEvent('comment_thread_expand', {
        'post_id': postId,
        'parent_comment_id': parentCommentId,
        'reply_count': replyCount.toString(),
        'user_id': userId ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } catch (e) {
      debugPrint('Failed to track comment_thread_expand: $e');
    }
  }

  /// Track when user collapses a comment thread
  static void trackCommentThreadCollapse({
    required String postId,
    required String parentCommentId,
    required int replyCount,
    String? userId,
  }) {
    try {
      _appsFlyerService.logEvent('comment_thread_collapse', {
        'post_id': postId,
        'parent_comment_id': parentCommentId,
        'reply_count': replyCount.toString(),
        'user_id': userId ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } catch (e) {
      debugPrint('Failed to track comment_thread_collapse: $e');
    }
  }

  /// Track when user engages with a reply (like/dislike)
  static void trackReplyEngagement({
    required String postId,
    required String parentCommentId,
    required String replyId,
    required String engagementType, // 'like', 'dislike', 'unlike', 'undislike'
    String? userId,
  }) {
    try {
      _appsFlyerService.logEvent('reply_engagement', {
        'post_id': postId,
        'parent_comment_id': parentCommentId,
        'reply_id': replyId,
        'engagement_type': engagementType,
        'user_id': userId ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } catch (e) {
      debugPrint('Failed to track reply_engagement: $e');
    }
  }

  /// Track notification tap for comments/replies
  static void trackCommentNotificationTap({
    required String postId,
    required String commentId,
    String? parentCommentId,
    required String notificationType, // 'comment', 'reply'
    String? userId,
  }) {
    try {
      _appsFlyerService.logEvent('comment_notification_tap', {
        'post_id': postId,
        'comment_id': commentId,
        'parent_comment_id': parentCommentId ?? '',
        'notification_type': notificationType,
        'user_id': userId ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } catch (e) {
      debugPrint('Failed to track comment_notification_tap: $e');
    }
  }

  /// Track funnel: opened composer → sent reply → first 24h engagement
  static void trackReplyFunnelStep({
    required String step, // 'composer_opened', 'reply_sent', '24h_engagement'
    required String postId,
    required String parentCommentId,
    String? replyId,
    String? userId,
    Map<String, String>? additionalData,
  }) {
    try {
      final eventData = <String, dynamic>{
        'funnel_step': step,
        'post_id': postId,
        'parent_comment_id': parentCommentId,
        'reply_id': replyId ?? '',
        'user_id': userId ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      if (additionalData != null) {
        eventData.addAll(additionalData);
      }

      _appsFlyerService.logEvent('reply_funnel', eventData);
    } catch (e) {
      debugPrint('Failed to track reply_funnel: $e');
    }
  }
}
