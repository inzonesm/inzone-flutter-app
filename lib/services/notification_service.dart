import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static const String _channelDmHigh = 'dm_high';
  static const String _channelGroupDefault = 'group_default';
  static const String _channelEngagementDigest = 'engagement_digest';
  static const String _channelSystem = 'system';
  static const String _channelOffers = 'offers';

  // API Base URL - update this to match your backend
  static const String _apiBaseUrl = 'http://localhost:5000'; // Change to your production URL
  
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static final StreamController<RemoteMessage> _messageController = 
      StreamController<RemoteMessage>.broadcast();
  
  static Stream<RemoteMessage> get messageStream => _messageController.stream;
  static bool _isInitialized = false;
  static AppLinks? _appLinks;

  // Helper function to get user name from multiple collections
  static Future<String> _getUsersName(String userId) async {
    try {
      // First try humanUsers collection
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(userId)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        var userData = userDoc.data() as Map<String, dynamic>;
        return userData['name'] ?? userData['Name'] ?? userData['username'] ?? userData['user_name'] ?? userId;
      }
      
      // Then try popularCharacters collection
      DocumentSnapshot characterDoc = await FirebaseFirestore.instance
          .collection('popularCharacters')
          .doc(userId)
          .get();
      
      if (characterDoc.exists && characterDoc.data() != null) {
        var characterData = characterDoc.data() as Map<String, dynamic>;
        return characterData['name'] ?? characterData['Name'] ?? characterData['username'] ?? characterData['user_name'] ?? userId;
      }
      
      // Finally try aiUsers collection
      DocumentSnapshot aiUserDoc = await FirebaseFirestore.instance
          .collection('aiUsers')
          .doc(userId)
          .get();
      
      if (aiUserDoc.exists && aiUserDoc.data() != null) {
        var aiUserData = aiUserDoc.data() as Map<String, dynamic>;
        return aiUserData['name'] ?? aiUserData['Name'] ?? aiUserData['username'] ?? aiUserData['user_name'] ?? userId;
      }
      
      // Return userId as fallback if not found in any collection
      return userId;
    } catch (e) {
      print('Error fetching user name for $userId: $e');
      return userId; // Return ID as fallback on error
    }
  }

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      
      // Request permissions
      await _requestPermissions();
      
      // Configure local notifications
      await _configureLocalNotifications();
      
      // Configure FCM
      await _configureFCM();
      
  // deeplink handling disabled
  // await _setupAppLinks();
      
      // Register FCM token
      await _registerFCMToken();
      
      _isInitialized = true;
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotificationService: $e');
    }
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    // Request FCM permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('FCM Permission granted: ${settings.authorizationStatus}');

    // Request local notification permission (Android 13+)
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  /// Configure local notifications
  static Future<void> _configureLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create Android notification channels
  static Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // DM High Priority Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelDmHigh,
        'Direct Messages',
        description: 'High priority notifications for direct messages',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
    );

    // Group Chat Default Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelGroupDefault,
        'Group Chats',
        description: 'Notifications for group chat messages',
        importance: Importance.defaultImportance,
      ),
    );

    // Engagement Digest Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelEngagementDigest,
        'Post Engagement',
        description: 'Notifications for likes, comments, and post interactions',
        importance: Importance.defaultImportance,
      ),
    );

    // System Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelSystem,
        'System Notifications',
        description: 'System alerts, streaks, and milestones',
        importance: Importance.defaultImportance,
      ),
    );

    // Offers Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelOffers,
        'Coin Offers',
        description: 'Special offers to earn coins',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('offer_sound'),
      ),
    );
  }

  /// Configure Firebase Cloud Messaging
  static Future<void> _configureFCM() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Handle terminated app message taps
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Register FCM token with backend API
  static Future<void> _registerFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Register with backend API
          await _registerTokenWithBackend(user.uid, token);
          
          // Also update Firestore for backup
          await FirebaseFirestore.instance
              .collection('humanUsers')
              .doc(user.uid)
              .update({
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          print('✅ FCM token registered: ${token.substring(0, 20)}...');
        }
      }
    } catch (e) {
      print('❌ Error registering FCM token: $e');
    }
  }

  /// Register token with backend API
  static Future<void> _registerTokenWithBackend(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'token': token,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM token registered with backend');
      } else {
        print('❌ Failed to register FCM token with backend: ${response.body}');
      }
    } catch (e) {
      print('❌ Error registering token with backend: $e');
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Foreground message received: ${message.notification?.title}');
    
    // Add to stream for UI handling
    _messageController.add(message);
    
    // Show local notification for better UX
    _showLocalNotification(message);
    
    // Track analytics
    _trackNotificationDelivered(message);
  }

  /// Handle message opened from background/terminated
  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('🔗 Message opened app: ${message.data}');

    // deeplink handling disabled - navigation is handled via structured notification data now
    // _handleDeepLink(message.data);

    // Track analytics
    _trackNotificationOpened(message);
  }

  /// Handle local notification tap
  static void _onLocalNotificationTapped(NotificationResponse response) {
    print('🔔 Local notification tapped: ${response.payload}');
    
    if (response.payload != null) {
  // deeplink handling is disabled; route using structured `data` fields instead if needed.
  // Example (if you want to route here):
  // final payload = jsonDecode(response.payload!);
  // navigatorKey.currentState?.pushNamed('/chat', arguments: payload['chatId']);
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final notificationType = message.data['type'] ?? 'system';
    final channelId = _getChannelId(notificationType);

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Notification Channel',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  /// Get appropriate channel ID for notification type
  static String _getChannelId(String notificationType) {
    switch (notificationType) {
      case 'dm_new':
        return _channelDmHigh;
      case 'group_digest':
      case 'mention':
        return _channelGroupDefault;
      case 'engagement_digest':
        return _channelEngagementDigest;
      case 'rare_offer':
        return _channelOffers;
      default:
        return _channelSystem;
    }
  }

  // deeplink handling removed: see structured notification fields approach
  // static void _handleDeepLink(Map<String, dynamic> data) { ... }

  // AppLinks/deeplink setup disabled
  // static Future<void> _setupAppLinks() async { ... }

  // deeplink app link handler removed

  /// Update user notification preferences with backend API
  static Future<void> updateNotificationPreferences(Map<String, dynamic> prefs) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update backend API
        await _updatePreferencesWithBackend(user.uid, prefs);
        
        // Also update Firestore for backup
        await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(user.uid)
            .update({
          'notificationPrefs': prefs,
          'timezone': DateTime.now().timeZoneName,
        });
        print('✅ Notification preferences updated');
      }
    } catch (e) {
      print('❌ Error updating notification preferences: $e');
    }
  }

  /// Update preferences with backend API
  static Future<void> _updatePreferencesWithBackend(String userId, Map<String, dynamic> preferences) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/notifications/preferences'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'preferences': preferences,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification preferences updated with backend');
      } else {
        print('❌ Failed to update preferences with backend: ${response.body}');
      }
    } catch (e) {
      print('❌ Error updating preferences with backend: $e');
    }
  }

  /// Get user notification preferences from backend
  static Future<Map<String, dynamic>?> getNotificationPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(user.uid)
            .get();
        
        return doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
      }
    } catch (e) {
      print('❌ Error getting notification preferences: $e');
    }
    return null;
  }

  // ==============================================
  // NOTIFICATION EVENT METHODS
  // ==============================================

  /// Send group message notification event
  static Future<void> sendGroupMessageNotification({
    required String groupId,
    required String content,
    required String senderId,
    String? senderName,
  }) async {
    try {
      // If senderName is not provided, fetch it
      final actualSenderName = senderName ?? await _getUsersName(senderId);
      
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/notifications/events/group-message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'content': content,
          'senderId': senderId,
          'senderName': actualSenderName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Group message notification sent');
      } else {
        print('❌ Failed to send group message notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending group message notification: $e');
    }
  }

  /// Send group mention notification event
  static Future<void> sendGroupMentionNotification({
    required String groupId,
    required String mentionedUserId,
    required String content,
    required String senderId,
    String? senderName,
    String? msgId,
  }) async {
    try {
      // If senderName is not provided, fetch it
      final actualSenderName = senderName ?? await _getUsersName(senderId);
      
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/notifications/events/group-mention'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'mentionedUserId': mentionedUserId,
          'content': content,
          'senderId': senderId,
          'senderName': actualSenderName,
          'msgId': msgId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Group mention notification sent');
      } else {
        print('❌ Failed to send group mention notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending group mention notification: $e');
    }
  }

  /// Send direct message notification event
  static Future<void> sendDirectMessageNotification({
    required String chatId,
    required String content,
    required String senderId,
    required String receiverId,
    String? senderName,
  }) async {
    try {
      // If senderName is not provided, fetch it
      final actualSenderName = senderName ?? await _getUsersName(senderId);
      
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/notifications/events/direct-message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': chatId,
          'content': content,
          'senderId': senderId,
          'receiverId': receiverId,
          'senderName': actualSenderName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Direct message notification sent');
      } else {
        print('❌ Failed to send direct message notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending direct message notification: $e');
    }
  }

  /// Send post engagement notification event
  static Future<void> sendPostEngagementNotification({
    required String postId,
    required String type, // 'like', 'comment', 'share'
    required String userId,
    String? postAuthorId,
    String? content,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/notifications/events/post-engagement'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'postId': postId,
          'type': type,
          'userId': userId,
          'postAuthorId': postAuthorId,
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Post engagement notification sent');
      } else {
        print('❌ Failed to send post engagement notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending post engagement notification: $e');
    }
  }

  /// Send AI nudge notification event
  static Future<void> sendAINudgeNotification({
    required String userId,
    required String characterId,
    required String lastChatId,
    String? personalizedHook,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/notifications/events/ai-nudge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'characterId': characterId,
          'lastChatId': lastChatId,
          'personalizedHook': personalizedHook,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ AI nudge notification sent');
      } else {
        print('❌ Failed to send AI nudge notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending AI nudge notification: $e');
    }
  }

  /// Get all notifications for user (testing/debug)
  static Future<Map<String, dynamic>?> getAllUserNotifications(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/notifications/user/$userId/all'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved all user notifications');
        return data['data'] as Map<String, dynamic>?;
      } else {
        print('❌ Failed to get user notifications: ${response.body}');
      }
    } catch (e) {
      print('❌ Error getting user notifications: $e');
    }
    return null;
  }

  /// Schedule local notification
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled Notifications',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Cancel notification
  static Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Track notification delivered
  static void _trackNotificationDelivered(RemoteMessage message) {
    final type = message.data['type'] ?? 'unknown';
    final category = message.data['category'] ?? 'system';
    // deeplink removed from notification tracking; use structured data instead
    AppsFlyerService().logEvent('notif_delivered', {
      'type': type,
      'category': category,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Track notification opened
  static void _trackNotificationOpened(RemoteMessage message) {
    // deeplink removed from notification tracking; use structured data instead
    AppsFlyerService().logEvent('notif_open', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Cleanup - remove invalid tokens
  static Future<void> cleanupInvalidTokens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? currentToken = await _firebaseMessaging.getToken();
        if (currentToken != null) {
          // Keep only the current token
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'fcmTokens': [currentToken],
          });
        }
      }
    } catch (e) {
      print('❌ Error cleaning up tokens: $e');
    }
  }
}

// Global navigator key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();