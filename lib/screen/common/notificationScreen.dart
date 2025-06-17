import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inzone/components/cards/tip_noti_tile.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

final List<Map<String, dynamic>> mockData = [
  {
    'id': 'tip1',
    'sender_id': 'userA',
    'recipient_id': 'userB',
    'amount': 10.0,
    'status': 'completed',
    'createdAt': DateTime.now().subtract(const Duration(minutes: 5)),
  },
  {
    'id': 'tip2',
    'sender_id': 'userC',
    'recipient_id': 'userD',
    'amount': 25.5,
    'status': 'completed',
    'createdAt': DateTime.now().subtract(const Duration(hours: 1)),
  },
  {
    'id': 'tip3',
    'sender_id': 'userE',
    'recipient_id': 'userF',
    'amount': 50.0,
    'status': 'pending',
    'createdAt': DateTime.now().subtract(const Duration(days: 1)),
  },
  {
    'id': 'tip4',
    'sender_id': 'userG',
    'recipient_id': 'userH',
    'amount': 70.0,
    'status': 'completed',
    'createdAt': DateTime.now().subtract(const Duration(days: 3)),
  },
];

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> today = [];
  List<Map<String, dynamic>> yesterday = [];
  List<Map<String, dynamic>> earlier = [];

  @override
  void initState() {
    super.initState();
    _categorizeNotifications();
  }

  void _categorizeNotifications() {
    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);
    DateTime yesterdayStart = todayStart.subtract(const Duration(days: 1));

    for (var noti in mockData) {
      DateTime createdAt = noti['createdAt'];

      if (createdAt.isAfter(todayStart)) {
        today.add(noti);
      } else if (createdAt.isAfter(yesterdayStart)) {
        yesterday.add(noti);
      } else {
        earlier.add(noti);
      }
    }
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .dividerColor
                    .withAlpha((0.05 * 255).toInt()),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        ...data.map((notification) => TipNotificationTile(
              tipId: notification['id'],
              senderId: notification['sender_id'],
              recipientId: notification['recipient_id'],
              amount: notification['amount'],
              status: notification['status'],
              createdAt: notification['createdAt'],
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColorfulSafeArea(
        topColor: Theme.of(context).canvasColor,
        left: false,
        right: false,
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: 8.0, left: 8.0, right: 16.0, bottom: 8.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: Theme.of(context).cardColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_ios,
                              size: 18,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: mockData.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView(
                      children: [
                        _buildSection('Today', today),
                        _buildSection('Yesterday', yesterday),
                        _buildSection('Earlier', earlier),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
