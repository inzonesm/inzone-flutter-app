import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/services/notification_event_service.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to view notifications')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.settings),
            onPressed: () => context.push('/notifications/settings'),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(FeatherIcons.checkCircle, size: 16),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(FeatherIcons.trash2, size: 16),
                    SizedBox(width: 8),
                    Text('Clear all'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Sort notifications manually by createdAt (descending) and limit to 50
          var notifications = snapshot.data!.docs;

          // Debug: print incoming notification docs to help diagnose missing items
          // try {
          //   final debugList = notifications.map((d) {
          //     final data = d.data() as Map<String, dynamic>;
          //     return '${d.id}:${data['type'] ?? 'no-type'}:user=${data['userId'] ?? 'no-user'}';
          //   }).toList();
          //   debugPrint('NotificationCenter snapshot docs: ${debugList.join(', ')}');
          // } catch (e) {
          //   debugPrint('Failed to debug-print notifications snapshot: $e');
          // }
          notifications.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreated = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bCreated = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bCreated.compareTo(aCreated); // Descending order
          });
          
          // Limit to 50 most recent
          if (notifications.length > 50) {
            notifications = notifications.take(50).toList();
          }

          final groupedNotifications = _groupNotificationsByDate(notifications);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedNotifications.length,
            itemBuilder: (context, index) {
              final group = groupedNotifications[index];
              return _buildNotificationGroup(group);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FeatherIcons.bell,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you receive notifications, they\'ll appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<NotificationGroup> _groupNotificationsByDate(List<QueryDocumentSnapshot> notifications) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    final now = DateTime.now();
    
    for (final notification in notifications) {
      final data = notification.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? now;
      
      String dateKey;
      final difference = now.difference(createdAt).inDays;
      
      if (difference == 0) {
        dateKey = 'Today';
      } else if (difference == 1) {
        dateKey = 'Yesterday';
      } else if (difference < 7) {
        dateKey = DateFormat('EEEE').format(createdAt);
      } else {
        dateKey = DateFormat('MMM dd, yyyy').format(createdAt);
      }
      
      grouped.putIfAbsent(dateKey, () => []).add(notification);
    }
    
    return grouped.entries
        .map((entry) => NotificationGroup(
              title: entry.key,
              notifications: entry.value,
            ))
        .toList();
  }

  Widget _buildNotificationGroup(NotificationGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            group.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...group.notifications.map((notification) => _buildNotificationItem(notification)),
      ],
    );
  }

  Widget _buildNotificationItem(QueryDocumentSnapshot notification) {
    final data = notification.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'system';
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final isRead = data['isRead'] as bool? ?? false;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final deeplink = data['deeplink'] as String?;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(FeatherIcons.trash2, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteNotification(notification.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: isRead ? 1 : 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleNotificationTap(notification.id, deeplink, isRead),
          onLongPress: () => _showNotificationOptions(notification),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isRead ? null : Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationIcon(type, isRead),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          color: isRead
                              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (createdAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String type, bool isRead) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'dm_new':
        iconData = FeatherIcons.messageCircle;
        iconColor = Colors.blue;
        break;
      case 'group_digest':
      case 'mention':
        iconData = FeatherIcons.users;
        iconColor = Colors.green;
        break;
      case 'engagement_digest':
        iconData = FeatherIcons.heart;
        iconColor = Colors.red;
        break;
      case 'ai_nudge':
        iconData = FeatherIcons.zap;
        iconColor = Colors.purple;
        break;
      case 'rare_offer':
        iconData = FeatherIcons.gift;
        iconColor = Colors.orange;
        break;
      case 'system':
      default:
        iconData = FeatherIcons.bell;
        iconColor = Colors.grey;
        break;
    }

    if (isRead) {
      iconColor = iconColor.withOpacity(0.5);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: 20,
        color: iconColor,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    }
  }

  void _handleNotificationTap(String notificationId, String? deeplink, bool isRead) {
    // Mark as read if not already
    if (!isRead) {
      _markAsRead(notificationId);
    }

    // Handle deep link
    if (deeplink != null && deeplink.isNotEmpty) {
      NotificationEventService.markNotificationOpened(notificationId, deeplink);
      _handleDeepLink(deeplink);
    }
  }

  void _handleDeepLink(String deeplink) {
    try {
      final uri = Uri.parse(deeplink);
      
      switch (uri.pathSegments.first) {
        case 'chat':
          if (uri.pathSegments.length > 1) {
            final chatId = uri.pathSegments[1];
            context.push('/chat/$chatId');
          }
          break;
        case 'post':
          if (uri.pathSegments.length > 1) {
            // Navigate to home since we don't have a specific post view route
            context.push('/home');
          }
          break;
        case 'settings':
          if (uri.pathSegments.length > 1 && uri.pathSegments[1] == 'notifications') {
            context.push('/notifications/settings');
          }
          break;
        case 'earn':
          if (uri.pathSegments.length > 1) {
            final offerType = uri.pathSegments[1];
            // Navigate to appropriate earning screen based on type
            if (offerType == 'watch') {
              context.push('/settings/unity-web-game');
            } else if (offerType == 'referral') {
              context.push('/settings/referral');
            } else {
              // Default to referral screen for unknown types
              context.push('/settings/referral');
            }
          }
          break;
      }
    } catch (e) {
      print('Error handling deep link: $e');
    }
  }

  void _markAsRead(String notificationId) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  void _deleteNotification(String notificationId) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  void _showNotificationOptions(QueryDocumentSnapshot notification) {
    final data = notification.data() as Map<String, dynamic>;
    final isRead = data['isRead'] as bool? ?? false;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isRead)
              ListTile(
                leading: const Icon(FeatherIcons.checkCircle),
                title: const Text('Mark as read'),
                onTap: () {
                  _markAsRead(notification.id);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(FeatherIcons.trash2),
              title: const Text('Delete'),
              onTap: () {
                _deleteNotification(notification.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'mark_all_read':
        _markAllAsRead();
        break;
      case 'clear_all':
        _clearAllNotifications();
        break;
    }
  }

  void _markAllAsRead() async {
    setState(() => _isLoading = true);
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Get all notifications for user (without isRead filter to avoid composite index)
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user!.uid)
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user!.uid)
          .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    
    setState(() => _isLoading = false);
  }
}

class NotificationGroup {
  final String title;
  final List<QueryDocumentSnapshot> notifications;

  NotificationGroup({
    required this.title,
    required this.notifications,
  });
}
