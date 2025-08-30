import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inzone/services/appsflyer_service.dart';

class NotificationEventService {
  static const String _apiUrl = 'https://inzoneapi-912424781531.us-central1.run.app';

  /// Trigger notification when a new message is sent in a group chat
  static Future<void> onGroupMessage(String groupId, String content, String senderId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/group-message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'content': content,
          'senderId': senderId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Group message notification event sent');
      } else {
        print('❌ Failed to send group message event: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sending group message event: $e');
    }
  }

  /// Trigger notification when a user is mentioned in a group chat
  static Future<void> onGroupMention(String groupId, String mentionedUserId, String content, String senderId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/group-mention'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'mentionedUserId': mentionedUserId,
          'content': content,
          'senderId': senderId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Group mention notification event sent');
      }
    } catch (e) {
      print('❌ Error sending group mention event: $e');
    }
  }

  /// Trigger notification for 1:1 DM (AI or Human)
  static Future<void> onDirectMessage(String chatId, String content, String senderId, String receiverId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/direct-message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': chatId,
          'content': content,
          'senderId': senderId,
          'receiverId': receiverId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Direct message notification event sent');
      }
    } catch (e) {
      print('❌ Error sending direct message event: $e');
    }
  }

  /// Trigger notification for post engagement (like, comment, etc.)
  static Future<void> onPostEngagement({
    required String postId,
    required String type, // 'like', 'comment', 'share'
    required String userId,
    String? content,
    String? postAuthorId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/post-engagement'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'postId': postId,
          'type': type,
          'userId': userId,
          'content': content,
          'postAuthorId': postAuthorId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Post engagement notification event sent');
        
        // Track analytics
        AppsFlyerService().logEvent('notification_event_triggered', {
          'event_type': 'post_engagement',
          'engagement_type': type,
          'post_id': postId,
          'user_id': userId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('❌ Error sending post engagement event: $e');
    }
  }

  /// Trigger notification for follow events
  static Future<void> onUserFollow(String followerId, String followedUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/user-follow'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'followerId': followerId,
          'followedUserId': followedUserId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ User follow notification event sent');
      }
    } catch (e) {
      print('❌ Error sending user follow event: $e');
    }
  }

  /// Trigger notification for system events (streaks, milestones)
  static Future<void> onSystemEvent({
    required String userId,
    required String type, // 'streak', 'milestone', 'welcome'
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/system'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'type': type,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ System notification event sent');
      }
    } catch (e) {
      print('❌ Error sending system event: $e');
    }
  }

  /// Trigger rare coin offer notification
  static Future<void> onRareCoinOffer({
    required String userId,
    required String offerType, // 'watch_video', 'refer_friend', 'double_coins'
    required int coinAmount,
    String? reason, // 'low_balance', 'failed_purchase', 'inactive'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/rare-offer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'offerType': offerType,
          'coinAmount': coinAmount,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Rare coin offer notification event sent');
        
        // Track analytics
        AppsFlyerService().logEvent('rare_offer_triggered', {
          'user_id': userId,
          'offer_type': offerType,
          'coin_amount': coinAmount,
          'reason': reason,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('❌ Error sending rare coin offer event: $e');
    }
  }

  /// Check if user qualifies for rare coin offers
  static Future<void> checkRareCoinOfferEligibility(String userId) async {
    try {
      // Get user's current balance
      final userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final currentBalance = userData['balance'] ?? 0;
      final lastOfferCheck = userData['lastOfferCheck'] as Timestamp?;
      
      // Check if user has low balance (less than 100 coins)
      if (currentBalance < 100) {
        await onRareCoinOffer(
          userId: userId,
          offerType: 'watch_video',
          coinAmount: 50,
          reason: 'low_balance',
        );
        return;
      }
      
      // Check if user hasn't earned coins in 7 days
      if (lastOfferCheck != null) {
        final daysSinceLastOffer = DateTime.now()
            .difference(lastOfferCheck.toDate())
            .inDays;
        
        if (daysSinceLastOffer >= 7) {
          await onRareCoinOffer(
            userId: userId,
            offerType: 'refer_friend',
            coinAmount: 200,
            reason: 'inactive',
          );
        }
      }
      
      // Update last offer check timestamp
      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(userId)
          .update({
        'lastOfferCheck': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('❌ Error checking rare coin offer eligibility: $e');
    }
  }

  /// Handle failed purchase - trigger coin offer
  static Future<void> onFailedPurchase(String userId, int attemptedAmount) async {
    await onRareCoinOffer(
      userId: userId,
      offerType: 'watch_video',
      coinAmount: attemptedAmount,
      reason: 'failed_purchase',
    );
  }

  /// Queue AI nudge notification for inactive users
  static Future<void> queueAINudge(String userId, String characterId, String lastChatId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/ai-nudge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'characterId': characterId,
          'lastChatId': lastChatId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ AI nudge notification queued');
      }
    } catch (e) {
      print('❌ Error queueing AI nudge: $e');
    }
  }

  /// Mark notification as delivered
  static Future<void> markNotificationDelivered(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notificationsQueue')
          .doc(notificationId)
          .update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking notification as delivered: $e');
    }
  }

  /// Mark notification as opened
  static Future<void> markNotificationOpened(String notificationId, String deeplink) async {
    try {
      await FirebaseFirestore.instance
          .collection('notificationsQueue')
          .doc(notificationId)
          .update({
        'status': 'opened',
        'openedAt': FieldValue.serverTimestamp(),
      });
      
      // Track analytics
      AppsFlyerService().logEvent('notif_open', {
        'notification_id': notificationId,
        'deeplink': deeplink,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      // If the document wasn't found, create it (merge) so the app doesn't crash
      try {
        if (e is FirebaseException && e.code == 'not-found') {
          await FirebaseFirestore.instance
              .collection('notificationsQueue')
              .doc(notificationId)
              .set({
            'status': 'opened',
            'openedAt': FieldValue.serverTimestamp(),
            'deeplink': deeplink,
          }, SetOptions(merge: true));

          AppsFlyerService().logEvent('notif_open', {
            'notification_id': notificationId,
            'deeplink': deeplink,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          return;
        }
      } catch (inner) {
        // swallow and fallthrough to logging the original error
      }

      print('❌ Error marking notification as opened: $e');
    }
  }

  /// Mark notification as dismissed
  static Future<void> markNotificationDismissed(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notificationsQueue')
          .doc(notificationId)
          .update({
        'status': 'dismissed',
        'dismissedAt': FieldValue.serverTimestamp(),
      });
      
      // Track analytics
      AppsFlyerService().logEvent('notif_dismiss', {
        'notification_id': notificationId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Error marking notification as dismissed: $e');
    }
  }
}
