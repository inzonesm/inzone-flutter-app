// Test script for push notifications
// Run this with: flutter run test_push_notifications.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:inzone/config/default_firebase_options.dart';
import 'package:inzone/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const NotificationTestApp());
}

class NotificationTestApp extends StatefulWidget {
  const NotificationTestApp({super.key});

  @override
  _NotificationTestAppState createState() => _NotificationTestAppState();
}

class _NotificationTestAppState extends State<NotificationTestApp> {
  String _fcmToken = 'Loading...';
  String _status = 'Initializing...';
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }
  
  Future<void> _initializeNotifications() async {
    try {
      setState(() {
        _status = 'Initializing notification service...';
      });
      
      // Initialize notification service
      await NotificationService.initialize();
      
      setState(() {
        _status = 'Getting FCM token...';
      });
      
      // Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      
      setState(() {
        _fcmToken = token ?? 'Failed to get token';
        _status = 'Ready! You can now test push notifications.';
      });
      
      print('=== PUSH NOTIFICATION TEST RESULTS ===');
      print('FCM Token: $token');
      print('Status: Ready for testing');
      print('');
      print('To test push notifications:');
      print('1. Copy the FCM token above');
      print('2. Go to Firebase Console > Cloud Messaging');
      print('3. Click "Send your first message"');
      print('4. Paste the token in the "FCM registration token" field');
      print('5. Send a test message');
      print('=====================================');
      
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      print('❌ Error initializing notifications: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Push Notification Test',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Push Notification Test'),
          backgroundColor: Colors.blue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              const Text(
                'FCM Token:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _fcmToken,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _initializeNotifications();
                },
                child: const Text('Refresh Token'),
              ),
              const SizedBox(height: 16),
              const Text(
                'How to test:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Copy the FCM token above\n'
                '2. Go to Firebase Console > Cloud Messaging\n'
                '3. Click "Send your first message"\n'
                '4. Enter a title and message\n'
                '5. Paste the token in "FCM registration token"\n'
                '6. Send the test message\n'
                '7. Check if notification appears on device',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
