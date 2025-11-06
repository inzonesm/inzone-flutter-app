import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  runApp(const LocalNotificationTestApp());
}

class LocalNotificationTestApp extends StatefulWidget {
  const LocalNotificationTestApp({super.key});

  @override
  _LocalNotificationTestAppState createState() => _LocalNotificationTestAppState();
}

class _LocalNotificationTestAppState extends State<LocalNotificationTestApp> {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String _status = 'Ready to test local notifications';
  
  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
  }
  
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        setState(() {
          _status = 'Notification tapped! Payload: ${response.payload}';
        });
      },
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'test_channel',
      'Test Notifications',
      description: 'Channel for testing local notifications',
      importance: Importance.high,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
    
    setState(() {
      _status = 'Local notifications initialized! Ready to test.';
    });
  }
  
  Future<void> _showSimpleNotification() async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Channel for testing local notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _localNotifications.show(
      0,
      'Test Notification 🎉',
      'This is a local notification test. Tap to see action!',
      platformChannelSpecifics,
      payload: 'test_payload_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    setState(() {
      _status = 'Local notification sent! Check notification panel.';
    });
  }
  
  Future<void> _showBigTextNotification() async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Channel for testing local notifications',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          'This is a big text notification that demonstrates how longer messages will appear in the notification panel. This simulates what your push notifications will look like when they come from Firebase.',
          htmlFormatBigText: true,
          contentTitle: 'Big Text Test 📱',
          htmlFormatContentTitle: true,
          summaryText: 'Summary text here',
          htmlFormatSummaryText: true,
        ),
      ),
    );

    await _localNotifications.show(
      1,
      'Big Text Notification',
      'This is the short version...',
      platformChannelSpecifics,
      payload: 'big_text_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    setState(() {
      _status = 'Big text notification sent!';
    });
  }
  
  Future<void> _showScheduledNotification() async {
    await _localNotifications.show(
      2,
      'Delayed Notification ⏰',
      'This notification was scheduled for 3 seconds delay',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Channel for testing local notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'scheduled_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    setState(() {
      _status = 'Immediate notification sent (simulating scheduled)';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Notification Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Local Notification Test'),
          backgroundColor: Colors.blue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 Local Notification Testing',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This tests the notification display system without requiring FCM. '
                      'These notifications will appear in the Android notification panel.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Status:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showSimpleNotification,
                icon: const Icon(Icons.notifications),
                label: const Text('Send Simple Notification'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showBigTextNotification,
                icon: const Icon(Icons.text_fields),
                label: const Text('Send Big Text Notification'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showScheduledNotification,
                icon: const Icon(Icons.schedule),
                label: const Text('Send Immediate Notification'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Important Notes:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• These are LOCAL notifications (not push notifications)\n'
                      '• FCM push notifications need a real device or Google Play emulator\n'
                      '• Tap notifications to see interaction\n'
                      '• Check Android notification panel after sending',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
