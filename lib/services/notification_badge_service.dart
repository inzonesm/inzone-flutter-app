import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io';

class NotificationBadgeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // One shared Firestore listener per user, instead of a new one per
  // StreamBuilder rebuild. The iOS badge update only runs when the count
  // actually changes.
  static StreamController<int>? _countController;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _countSub;
  static String? _countUid;
  static int? _lastCount;

  /// Get a stream of unread notification count for the current user
  static Stream<int> getUnreadNotificationCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    if (_countController == null || _countUid != user.uid) {
      _countSub?.cancel();
      _countUid = user.uid;
      _lastCount = null;
      final controller = StreamController<int>.broadcast();
      _countController = controller;
      _countSub = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        // Filter unread notifications manually to avoid composite index
        final unreadCount = snapshot.docs.where((doc) {
          final data = doc.data();
          return data['isRead'] !=
              true; // Count as unread if isRead is false or null
        }).length;

        // Update iOS badge count only when it changed
        if (unreadCount != _lastCount) {
          _updateIOSBadgeCount(unreadCount);
        }
        _lastCount = unreadCount;
        controller.add(unreadCount);
      });
    }

    return _watchCount();
  }

  // Replays the last known count to new subscribers, then follows the shared
  // broadcast stream.
  static Stream<int> _watchCount() async* {
    final last = _lastCount;
    if (last != null) yield last;
    yield* _countController!.stream;
  }

  /// Force clear iOS badge using multiple methods
  static Future<void> forceIOSBadgeClear() async {
    if (!Platform.isIOS) return;
    
    try {
      print('🔄 Force clearing iOS badge...');
      
      // Method 1: Request permissions and clear badge
      await _localNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(badge: true);
      
      // Method 2: Show temporary notification with badge 0
      await _localNotifications.show(
        999998, // Use a unique ID
        '', '', 
        const NotificationDetails(
          iOS: DarwinNotificationDetails(badgeNumber: 0),
        ),
      );
      
      // Method 3: Cancel the temporary notification
      await _localNotifications.cancel(999998);
      
      // Method 4: Clear all notifications which should also clear badge
      await _localNotifications.cancelAll();
      
      print('✅ iOS badge force cleared using multiple methods');
    } catch (e) {
      print('❌ Error force clearing iOS badge: $e');
    }
  }

  /// Update iOS app badge count
  static Future<void> _updateIOSBadgeCount(int count) async {
    if (Platform.isIOS) {
      try {
        // Method 1: Use flutter_local_notifications plugin to set badge directly
        await _localNotifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: false,
          badge: true,
          sound: false,
        );
        
        // Set the badge number directly without showing a notification
        final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          badgeNumber: count,
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        );
        
        final NotificationDetails notificationDetails = NotificationDetails(
          iOS: iosDetails,
        );
        
        // Cancel any existing badge notifications to avoid conflicts
        await _localNotifications.cancelAll();
        
        if (count >= 0) {
          // Show a completely silent notification that only updates the badge
          await _localNotifications.show(
            999999, // Special ID for badge updates
            '', // Empty title (required but won't be shown)
            '', // Empty body (required but won't be shown)
            notificationDetails,
            payload: 'badge_update', // Special payload to identify badge updates
          );
          
          // Immediately cancel the notification so it doesn't appear in notification center
          await Future.delayed(const Duration(milliseconds: 100));
          await _localNotifications.cancel(999999);
        }
        
        print('✅ iOS badge count updated to: $count');
      } catch (e) {
        print('❌ Error updating iOS badge count: $e');
        
        // Fallback: Try alternative approach
        try {
          await _localNotifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
            badge: true,
          );
          
          // Alternative method - show and immediately dismiss
          await _localNotifications.show(
            999998,
            null,
            null,
            NotificationDetails(
              iOS: DarwinNotificationDetails(
                badgeNumber: count,
                presentBadge: true,
                presentAlert: false,
                presentSound: false,
              ),
            ),
          );
          
          await _localNotifications.cancel(999998);
          print('✅ iOS badge count updated using fallback method: $count');
        } catch (fallbackError) {
          print('❌ Fallback iOS badge update also failed: $fallbackError');
        }
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
