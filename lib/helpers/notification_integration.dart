import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper methods to integrate notification system with existing app features
/// Call these methods when corresponding actions happen in your app
class NotificationIntegration {
  
  /// Call when a user sends a message in a group chat
  static Future<void> onGroupMessageSent({
    required String groupId,
    required String messageContent,
    required String senderId,
    String? senderName,
  }) async {
    await NotificationService.sendGroupMessageNotification(
      groupId: groupId,
      content: messageContent,
      senderId: senderId,
      senderName: senderName,
    );
  }

  /// Call when a user mentions someone in a group chat
  static Future<void> onUserMentionedInGroup({
    required String groupId,
    required String mentionedUserId,
    required String messageContent,
    required String senderId,
    String? senderName,
    String? messageId,
  }) async {
    await NotificationService.sendGroupMentionNotification(
      groupId: groupId,
      mentionedUserId: mentionedUserId,
      content: messageContent,
      senderId: senderId,
      senderName: senderName,
      msgId: messageId,
    );
  }

  /// Call when a user sends a direct message to another user
  static Future<void> onDirectMessageSent({
    required String chatId,
    required String messageContent,
    required String senderId,
    required String receiverId,
    String? senderName,
  }) async {
    await NotificationService.sendDirectMessageNotification(
      chatId: chatId,
      content: messageContent,
      senderId: senderId,
      receiverId: receiverId,
      senderName: senderName,
    );
  }

  /// Call when a user likes a post
  static Future<void> onPostLiked({
    required String postId,
    required String userId,
    String? postAuthorId,
  }) async {
    await NotificationService.sendPostEngagementNotification(
      postId: postId,
      type: 'like',
      userId: userId,
      postAuthorId: postAuthorId,
    );
  }

  /// Call when a user comments on a post
  static Future<void> onPostCommented({
    required String postId,
    required String userId,
    required String commentContent,
    String? postAuthorId,
  }) async {
    await NotificationService.sendPostEngagementNotification(
      postId: postId,
      type: 'comment',
      userId: userId,
      postAuthorId: postAuthorId,
      content: commentContent,
    );
  }

  /// Call when a user shares a post
  static Future<void> onPostShared({
    required String postId,
    required String userId,
    String? postAuthorId,
  }) async {
    await NotificationService.sendPostEngagementNotification(
      postId: postId,
      type: 'share',
      userId: userId,
      postAuthorId: postAuthorId,
    );
  }

  /// Call when an AI character should send a nudge to continue conversation
  static Future<void> onAINudgeNeeded({
    required String userId,
    required String characterId,
    required String lastChatId,
    String? personalizedMessage,
  }) async {
    await NotificationService.sendAINudgeNotification(
      userId: userId,
      characterId: characterId,
      lastChatId: lastChatId,
      personalizedHook: personalizedMessage,
    );
  }

  /// Call when user logs in to ensure FCM token is registered
  static Future<void> onUserLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Initialize notification service which will register FCM token
      await NotificationService.initialize();
    }
  }

  /// Call when user updates their notification preferences
  static Future<void> onNotificationPreferencesChanged(
    Map<String, dynamic> preferences
  ) async {
    await NotificationService.updateNotificationPreferences(preferences);
  }
}
