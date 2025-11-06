import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/config/default_firebase_options.dart';
import 'package:inzone/services/notification_event_service.dart';
import 'package:inzone/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const NotificationIntegrationTestApp());
}

class NotificationIntegrationTestApp extends StatefulWidget {
  const NotificationIntegrationTestApp({super.key});

  @override
  _NotificationIntegrationTestAppState createState() => _NotificationIntegrationTestAppState();
}

class _NotificationIntegrationTestAppState extends State<NotificationIntegrationTestApp> {
  String _status = 'Ready to test notification integration';
  String _fcmToken = 'Loading...';
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      setState(() {
        _status = 'Initializing notification services...';
      });
      
      // Initialize notification service
      await NotificationService.initialize();
      
      // Get FCM token if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to get FCM token
        final token = await FirebaseMessaging.instance.getToken();
        setState(() {
          _fcmToken = token ?? 'Failed to get token';
          _status = 'Services initialized! You can now test push notifications.';
        });
      } else {
        setState(() {
          _fcmToken = 'No user logged in';
          _status = 'Services initialized, but no user logged in. Some tests may not work.';
        });
      }
      
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      print('❌ Error initializing services: $e');
    }
  }
  
  Future<void> _testDMNotification() async {
    setState(() {
      _status = 'Testing direct message notification...';
    });
    
    try {
      await NotificationEventService.onDirectMessage(
        'test_chat_123',
        'This is a test DM for push notifications',
        'test_sender_456',
        'test_receiver_789',
      );
      
      setState(() {
        _status = '✅ DM notification test sent! Check backend logs and your notification panel.';
      });
    } catch (e) {
      setState(() {
        _status = '❌ DM notification test failed: $e';
      });
    }
  }
  
  Future<void> _testGroupMessageNotification() async {
    setState(() {
      _status = 'Testing group message notification...';
    });
    
    try {
      await NotificationEventService.onGroupMessage(
        'test_group_123',
        'This is a test group message for push notifications',
        'test_sender_456',
      );
      
      setState(() {
        _status = '✅ Group message notification test sent! Check backend logs.';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Group message notification test failed: $e';
      });
    }
  }
  
  Future<void> _testPostEngagementNotification() async {
    setState(() {
      _status = 'Testing post engagement notification...';
    });
    
    try {
      await NotificationEventService.onPostEngagement(
        postId: 'test_post_123',
        type: 'like',
        userId: 'test_user_456',
        postAuthorId: 'test_author_789',
      );
      
      setState(() {
        _status = '✅ Post engagement notification test sent! Check backend logs.';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Post engagement notification test failed: $e';
      });
    }
  }
  
  Future<void> _testBackendConnectivity() async {
    setState(() {
      _status = 'Testing backend connectivity...';
    });
    
    try {
      // Test if backend is reachable
      final response = await http.get(
        Uri.parse('https://inzoneapi-912424781531.us-central1.run.app/health'),
      );
      
      setState(() {
        _status = 'Backend response: ${response.statusCode} - ${response.body}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Backend connectivity test failed: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Integration Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Notification Integration Test'),
          backgroundColor: Colors.blue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
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
                        '🔔 Push Notification Integration Test',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This tests the backend integration for push notifications.',
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
                const SizedBox(height: 16),
                const Text(
                  'FCM Token:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    _fcmToken,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _testBackendConnectivity,
                  icon: const Icon(Icons.network_check),
                  label: const Text('Test Backend Connectivity'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _testDMNotification,
                  icon: const Icon(Icons.message),
                  label: const Text('Test DM Notification'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _testGroupMessageNotification,
                  icon: const Icon(Icons.group),
                  label: const Text('Test Group Message Notification'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _testPostEngagementNotification,
                  icon: const Icon(Icons.favorite),
                  label: const Text('Test Post Engagement Notification'),
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
                        '📋 What this tests:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Backend connectivity to https://inzoneapi-912424781531.us-central1.run.app\n'
                        '• DM notification API endpoint\n'
                        '• Group message notification API endpoint\n'
                        '• Post engagement notification API endpoint\n'
                        '• FCM token generation and registration\n\n'
                        'Check console logs for detailed error messages.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
