import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationBadgeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
          return unreadCount;
        });
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
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
}
