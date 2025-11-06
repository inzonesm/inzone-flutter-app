import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PushNotificationDebugApp());
}

class PushNotificationDebugApp extends StatefulWidget {
  const PushNotificationDebugApp({super.key});

  @override
  _PushNotificationDebugAppState createState() => _PushNotificationDebugAppState();
}

class _PushNotificationDebugAppState extends State<PushNotificationDebugApp> {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String _status = 'Initializing...';
  String? _fcmToken;
  String? _userId;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initializeEverything();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      _status = message;
    });
    print('🔍 DEBUG: $message');
  }

  Future<void> _initializeEverything() async {
    try {
      _addLog('🔄 Starting initialization...');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Initialize FCM
      await _initializeFCM();
      
      // Setup a test user ID
      _userId = 'UtJT6b11yPRYabfxXRmYjW7UQAY2'; // Use real user ID
      _addLog('👤 Real User ID: $_userId (Johnny Test!)');
      
      // Register FCM token
      if (_fcmToken != null) {
        await _registerFCMToken();
      }
      
      _addLog('✅ Initialization complete!');
    } catch (e) {
      _addLog('❌ Initialization error: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _addLog('📱 Local notification tapped: ${response.payload}');
      },
    );

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
    _addLog('📱 Local notifications initialized');
  }

  Future<void> _initializeFCM() async {
    // Request permission
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _addLog('🔔 FCM Permission: ${settings.authorizationStatus}');

    // Get FCM token
    _fcmToken = await FirebaseMessaging.instance.getToken();
    _addLog('🎫 FCM Token received: ${_fcmToken?.substring(0, 20)}...');

    // Setup foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _addLog('📨 Foreground FCM message received: ${message.notification?.title}');
      _showLocalNotificationFromFCM(message);
    });

    // Setup background message handler
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _addLog('📱 FCM message opened app: ${message.notification?.title}');
    });
  }

  Future<void> _showLocalNotificationFromFCM(RemoteMessage message) async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'FCM Notification',
      message.notification?.body ?? 'FCM message received',
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _registerFCMToken() async {
    try {
      _addLog('🔄 Registering FCM token with backend...');
      
      final response = await http.post(
        Uri.parse('https://inzoneapi-912424781531.us-central1.run.app/api/notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'token': _fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        _addLog('✅ FCM token registered with backend');
      } else {
        _addLog('❌ Failed to register FCM token: ${response.body}');
      }
    } catch (e) {
      _addLog('❌ Error registering FCM token: $e');
    }
  }

  Future<void> _testBackendPushNotification() async {
    try {
      _addLog('🔄 Testing backend push notification...');
      
      final response = await http.post(
        Uri.parse('https://inzoneapi-912424781531.us-central1.run.app/api/notifications/send-push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'title': 'Test Push Notification 🎉',
          'body': 'This is a test push notification from the debug app!',
          'data': {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        _addLog('✅ Backend push notification sent successfully');
        _addLog('📊 Stats: ${responseData['stats']}');
        
        // Check if any sends were successful
        final stats = responseData['stats'];
        final successful = stats['successful'] ?? 0;
        final failed = stats['failed'] ?? 0;
        
        if (successful > 0) {
          _addLog('🎉 FCM messages delivered! Check your notification panel.');
        } else if (failed > 0) {
          _addLog('⚠️ FCM sends failed. This might be due to:');
          _addLog('   • Google Play Services not available in emulator');
          _addLog('   • Firebase project configuration mismatch');
          _addLog('   • Network connectivity issues');
          _addLog('💡 Try testing on a real device with Google Play Services');
        }
      } else {
        _addLog('❌ Backend push notification failed: ${response.body}');
      }
    } catch (e) {
      _addLog('❌ Error testing backend push notification: $e');
    }
  }

  Future<void> _testGooglePlayServices() async {
    _addLog('🔄 Testing Google Play Services availability...');
    
    try {
      // Try to get a new FCM token (this will fail if Google Play Services isn't working)
      await FirebaseMessaging.instance.deleteToken();
      String? newToken = await FirebaseMessaging.instance.getToken();
      
      if (newToken != null) {
        _addLog('✅ Google Play Services working - Got new FCM token');
        _addLog('🎫 New token: ${newToken.substring(0, 20)}...');
        _fcmToken = newToken;
      } else {
        _addLog('❌ Failed to get FCM token - Google Play Services may not be available');
      }
    } catch (e) {
      _addLog('❌ Google Play Services test failed: $e');
      _addLog('💡 This emulator may not support push notifications');
      _addLog('💡 Try using an emulator with Google Play Store or a real device');
    }
  }

  Future<void> _testLocalNotification() async {
    _addLog('🔄 Testing local notification...');
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _localNotifications.show(
      999,
      'Local Test Notification 📱',
      'This is a local notification to verify display works',
      platformChannelSpecifics,
      payload: 'local_test_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    _addLog('✅ Local notification sent');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Push Notification Debug',
      theme: ThemeData(primarySwatch: Colors.red),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Push Notification Debug'),
          backgroundColor: Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔍 Push Notification Debugging',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('FCM Token: ${_fcmToken?.substring(0, 20) ?? 'Not available'}...'),
                    Text('User ID: $_userId'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Current Status:',
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
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _testLocalNotification,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Local Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fcmToken != null ? _testBackendPushNotification : null,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Test Backend Push Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _registerFCMToken,
                icon: const Icon(Icons.app_registration),
                label: const Text('Re-register FCM Token'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _testGooglePlayServices,
                icon: const Icon(Icons.settings_system_daydream),
                label: const Text('Test Google Play Services'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Debug Logs:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
