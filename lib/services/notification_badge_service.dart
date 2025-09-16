import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationBadgeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  /// Get a stream of unread notification count for the current user
  static Stream<int> getUnreadNotificationCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          // Filter unread notifications manually to avoid composite index
          final unreadCount = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['isRead'] != true; // Count as unread if isRead is false or null
          }).length;
          
          // Update iOS badge count in real-time
          _updateIOSBadgeCount(unreadCount);
          
          return unreadCount;
        });
  }

  /// Update iOS app badge count
  static Future<void> _updateIOSBadgeCount(int count) async {
    if (Platform.isIOS) {
      try {
        // Use Flutter Local Notifications to update iOS badge
        final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          badgeNumber: count,
          presentBadge: true,
        );
        
        // Show a silent notification to update badge (iOS requirement)
        final NotificationDetails notificationDetails = NotificationDetails(
          iOS: iosDetails,
        );
        
        // Cancel any existing badge update notifications to avoid duplicates
        await _localNotifications.cancel(999999);
        
        if (count > 0) {
          // Show invisible notification to update badge
          await _localNotifications.show(
            999999, // Special ID for badge updates
            null, // No title
            null, // No body
            notificationDetails,
          );
        } else {
          // Clear badge when count is 0
          await _localNotifications.show(
            999999,
            null,
            null,
            notificationDetails,
          );
        }
        
        print('✅ iOS badge count updated to: $count');
      } catch (e) {
        print('❌ Error updating iOS badge count: $e');
      }
    }
  }

  /// Mark all notifications as read for the current user
  static Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      
      // Get all notifications for user (without isRead filter to avoid composite index)
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Filter unread notifications manually and update them
      for (final doc in notifications.docs) {
        final data = doc.data();
        if (data['isRead'] != true) { // Only update if not already read
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      
      // Clear iOS badge
      await _updateIOSBadgeCount(0);
      
      print('✅ All notifications marked as read and badge cleared');
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Mark a specific notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      
      // Recalculate and update badge count
      await _recalculateBadgeCount();
      
      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
  
  /// Recalculate and update the badge count manually
  static Future<void> _recalculateBadgeCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      final unreadCount = notifications.docs.where((doc) {
        final data = doc.data();
        return data['isRead'] != true;
      }).length;
      
      await _updateIOSBadgeCount(unreadCount);
    } catch (e) {
      print('Error recalculating badge count: $e');
    }
  }
  
  /// Force clear iOS badge (useful for app launch)
  static Future<void> clearIOSBadge() async {
    if (Platform.isIOS) {
      await _updateIOSBadgeCount(0);
    }
  }
  
  /// Manual sync badge count with actual unread notifications
  static Future<void> syncBadgeCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      final unreadCount = notifications.docs.where((doc) {
        final data = doc.data();
        return data['isRead'] != true;
      }).length;
      
      await _updateIOSBadgeCount(unreadCount);
      print('✅ Badge count synced: $unreadCount');
    } catch (e) {
      print('Error syncing badge count: $e');
    }
  }
}
