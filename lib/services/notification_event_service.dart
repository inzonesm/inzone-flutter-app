import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:inzone/router/app_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/services/notification_badge_service.dart';

class NotificationEventService {
  static const String _apiUrl = 'https://inzoneapi-912424781531.us-central1.run.app';
  
  // Local notifications instance for immediate display
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  // Firebase messaging instance
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Helper method to validate and resolve user ID for human users only
  /// This method is specifically for notifications and only returns human user IDs
  static Future<String?> _resolveHumanUserId(String userId) async {
    try {
      // If it looks like a valid Firebase UID (alphanumeric, no spaces, no special chars except possibly hyphens/underscores)
      if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(userId) && !userId.contains(' ')) {
        // Check if the document exists in humanUsers first
        final userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          return userId; // Valid human user ID found
        }
        
        // Check if it's an AI character (should not receive notifications)
        final characterDoc = await FirebaseFirestore.instance
            .collection('popularCharacters')
            .doc(userId)
            .get();
        
        if (characterDoc.exists) {
          print('❌ _resolveHumanUserId: $userId is an AI character - cannot send notifications to AI');
          return null; // AI characters should not receive notifications
        }
      }
      
      // If direct lookup failed or ID looks like a display name, search by name/displayName in humanUsers only
      print('🔍 Searching for human user ID by display name: $userId');
      
      // Search in humanUsers by name or displayName
      final queryByName = await FirebaseFirestore.instance
          .collection('humanUsers')
          .where('name', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (queryByName.docs.isNotEmpty) {
        final actualUserId = queryByName.docs.first.id;
        print('✅ Found human user ID by name: $actualUserId for display name: $userId');
        return actualUserId;
      }
      
      final queryByDisplayName = await FirebaseFirestore.instance
          .collection('humanUsers')
          .where('displayName', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (queryByDisplayName.docs.isNotEmpty) {
        final actualUserId = queryByDisplayName.docs.first.id;
        print('✅ Found human user ID by displayName: $actualUserId for display name: $userId');
        return actualUserId;
      }
      
      // Try case-insensitive search in humanUsers only
      final allUsers = await FirebaseFirestore.instance
          .collection('humanUsers')
          .get();
      
      for (final doc in allUsers.docs) {
        final userData = doc.data();
        final name = userData['name']?.toString().toLowerCase();
        final displayName = userData['displayName']?.toString().toLowerCase();
        final searchTerm = userId.toLowerCase();
        
        if (name == searchTerm || displayName == searchTerm) {
          final actualUserId = doc.id;
          print('✅ Found human user ID by case-insensitive search: $actualUserId for: $userId');
          return actualUserId;
        }
      }
      
      print('❌ Could not resolve human user ID for: $userId');
      return null;
      
    } catch (e) {
      print('❌ Error resolving human user ID for $userId: $e');
      return null;
    }
  }

  // /// Helper method to validate and resolve user ID
  // /// If the provided ID looks like a display name, try to find the actual user ID
  // static Future<String?> _resolveUserId(String userId) async {
  //   try {
  //     // If it looks like a valid Firebase UID (alphanumeric, no spaces, no special chars except possibly hyphens/underscores)
  //     if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(userId) && !userId.contains(' ')) {
  //       // Check if the document exists in humanUsers first
  //       final userDoc = await FirebaseFirestore.instance
  //           .collection('humanUsers')
  //           .doc(userId)
  //           .get();
        
  //       if (userDoc.exists) {
  //         return userId; // Valid human user ID found
  //       }
        
  //       // Check if the document exists in popularCharacters (AI characters)
  //       final characterDoc = await FirebaseFirestore.instance
  //           .collection('popularCharacters')
  //           .doc(userId)
  //           .get();
        
  //       if (characterDoc.exists) {
  //         return userId; // Valid AI character ID found
  //       }
  //     }
      
  //     // If direct lookup failed or ID looks like a display name, search by name/displayName
  //     print('🔍 Searching for user ID by display name: $userId');
      
  //     // Search in humanUsers by name or displayName
  //     final queryByName = await FirebaseFirestore.instance
  //         .collection('humanUsers')
  //         .where('name', isEqualTo: userId)
  //         .limit(1)
  //         .get();
      
  //     if (queryByName.docs.isNotEmpty) {
  //       final actualUserId = queryByName.docs.first.id;
  //       print('✅ Found user ID by name: $actualUserId for display name: $userId');
  //       return actualUserId;
  //     }
      
  //     final queryByDisplayName = await FirebaseFirestore.instance
  //         .collection('humanUsers')
  //         .where('displayName', isEqualTo: userId)
  //         .limit(1)
  //         .get();
      
  //     if (queryByDisplayName.docs.isNotEmpty) {
  //       final actualUserId = queryByDisplayName.docs.first.id;
  //       print('✅ Found user ID by displayName: $actualUserId for display name: $userId');
  //       return actualUserId;
  //     }
      
  //     // Search in popularCharacters by name
  //     final queryByCharacterName = await FirebaseFirestore.instance
  //         .collection('popularCharacters')
  //         .where('name', isEqualTo: userId)
  //         .limit(1)
  //         .get();
      
  //     if (queryByCharacterName.docs.isNotEmpty) {
  //       final actualUserId = queryByCharacterName.docs.first.id;
  //       print('✅ Found AI character ID by name: $actualUserId for display name: $userId');
  //       return actualUserId;
  //     }
      
  //     // Try case-insensitive search in both collections
  //     final allUsers = await FirebaseFirestore.instance
  //         .collection('humanUsers')
  //         .get();
      
  //     for (final doc in allUsers.docs) {
  //       final userData = doc.data();
  //       final name = userData['name']?.toString().toLowerCase();
  //       final displayName = userData['displayName']?.toString().toLowerCase();
  //       final searchTerm = userId.toLowerCase();
        
  //       if (name == searchTerm || displayName == searchTerm) {
  //         final actualUserId = doc.id;
  //         print('✅ Found user ID by case-insensitive search: $actualUserId for: $userId');
  //         return actualUserId;
  //       }
  //     }
      
  //     // Try case-insensitive search in popularCharacters
  //     final allCharacters = await FirebaseFirestore.instance
  //         .collection('popularCharacters')
  //         .get();
      
  //     for (final doc in allCharacters.docs) {
  //       final characterData = doc.data();
  //       final name = characterData['name']?.toString().toLowerCase();
  //       final searchTerm = userId.toLowerCase();
        
  //       if (name == searchTerm) {
  //         final actualUserId = doc.id;
  //         print('✅ Found AI character ID by case-insensitive search: $actualUserId for: $userId');
  //         return actualUserId;
  //       }
  //     }
      
  //     print('❌ Could not resolve user ID for: $userId');
  //     return null;
      
  //   } catch (e) {
  //     print('❌ Error resolving user ID for $userId: $e');
  //     return null;
  //   }
  // }

  /// Mark notification as read by searching for it using push notification data
  /// Since notifications don't have an id field, we search by document characteristics
  static Future<void> _markNotificationAsReadByData(String userId, String type, Map<String, dynamic> pushData) async {
    try {
      // Simple query without orderBy to avoid index requirements
      final querySnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .limit(100)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return;
      }
      
      // Check if push data contains a notification document ID
      final notificationId = pushData['notificationId'] as String? ?? pushData['id'] as String?;
      
      if (notificationId != null) {
        // Direct approach: mark specific notification by document ID
        try {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(notificationId)
              .update({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
          return;
        } catch (e) {
          // If direct ID fails, continue with matching below
        }
      }
      
      // Find the specific notification that matches
      for (final doc in querySnapshot.docs) {
        final notificationData = doc.data();
        final isRead = notificationData['isRead'] as bool? ?? false;
        
        // Skip if already read
        if (isRead) continue;
        
        final notificationType = notificationData['type'] as String? ?? '';
        final storedData = notificationData['data'] as Map<String, dynamic>? ?? {};
        
        // Simple type matching first
        bool typeMatches = notificationType == type;
        
        if (!typeMatches) continue;
        
        // For precise matching, check one key field based on type
        bool isMatch = false;
        
        switch (type) {
          case 'follow':
            final pushFollowerId = pushData['followerId'] as String? ?? pushData['userId'] as String?;
            final storedFollowerId = storedData['followerId'] as String? ?? storedData['userId'] as String?;
            isMatch = pushFollowerId != null && pushFollowerId == storedFollowerId;
            break;
            
          case 'comment':
            final pushPostId = pushData['postId'] as String?;
            final storedPostId = storedData['postId'] as String?;
            isMatch = pushPostId != null && pushPostId == storedPostId;
            break;
            
          case 'like':
            final pushPostId = pushData['postId'] as String?;
            final storedPostId = storedData['postId'] as String?;
            isMatch = pushPostId != null && pushPostId == storedPostId;
            break;
            
          default:
            // For other types, just match the first unread notification of same type
            isMatch = true;
            break;
        }
        
        if (isMatch) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(doc.id)
              .update({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
          return; // Done - marked specific notification
        }
      }
      
    } catch (e) {
      // Silent fail
    }
  }

  /// Initialize and register FCM token for push notifications
  static Future<void> initializePushNotifications() async {
    try {
      // Request notification permissions first
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print('🔔 Notification permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Configure FCM message handlers
        await _configureFCM();
        
        // Wait a bit to ensure user authentication is complete
        await Future.delayed(const Duration(seconds: 2));
        
        // On iOS, wait a bit more for APNS to be properly initialized
        if (Platform.isIOS) {
          await Future.delayed(const Duration(seconds: 3));
        }
        
        // Register FCM token when app starts
        await _registerFCMToken();
        
        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            _registerTokenWithBackend(user.uid, newToken);
          }
        });
        
        print('✅ Push notifications initialized');
      } else {
        print('❌ Notification permissions denied');
      }
    } catch (e) {
      print('❌ Error initializing push notifications: $e');
    }
  }

  /// Configure Firebase Cloud Messaging handlers
  static Future<void> _configureFCM() async {
    // Handle foreground messages (show local notification)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground message received: ${message.notification?.title}');
      // You can show local notification here if needed
    });
    
    // Handle background message taps (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Background message tapped: ${message.data}');
      handlePushNotificationTap(message.data);
    });
    
    // Handle terminated app message taps (app was completely closed)
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('📱 Terminated app message received: ${initialMessage.data}');
      // Delay handling to ensure app is fully initialized
      Future.delayed(const Duration(milliseconds: 1000), () {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          handlePushNotificationTap(initialMessage.data);
        } else {
          // Store for later if user not logged in yet
          _pendingInitialMessage = initialMessage;
        }
      });
    }
  }

  // Store initial message if user isn't logged in yet
  static RemoteMessage? _pendingInitialMessage;

  /// Handle pending initial message after user logs in
  static Future<void> handlePendingInitialMessage() async {
    if (_pendingInitialMessage != null) {
      print('📱 Handling pending initial message after login: ${_pendingInitialMessage!.data}');
      handlePushNotificationTap(_pendingInitialMessage!.data);
      _pendingInitialMessage = null;
    }
  }

  /// Manual method to re-register FCM token (call after login)
  static Future<void> reRegisterFCMToken() async {
    print('🔄 Manually re-registering FCM token...');
    
    // Add a small delay to ensure authentication is complete
    await Future.delayed(const Duration(seconds: 1));
    
    await _registerFCMToken();
  }

  /// Debug method to test FCM token validity
  static Future<void> debugFCMToken() async {
    try {
      print('🔍 Debug: Testing FCM token...');
      String? token = await _firebaseMessaging.getToken();
      
      if (token != null) {
        print('📱 Current FCM token: $token');
        print('📱 Token length: ${token.length}');
        print('📱 Token starts with: ${token.substring(0, 20)}...');
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print('👤 Current user: ${user.uid}');
          print('👤 User email: ${user.email}');
          
          // Test sending a push notification to self
          await _sendPushNotificationToUser(
            userId: user.uid,
            title: 'FCM Test',
            body: 'This is a test push notification to verify FCM token validity',
            data: {'type': 'test'},
          );
        } else {
          print('❌ No authenticated user for FCM test');
        }
      } else {
        print('❌ No FCM token available');
      }
    } catch (e) {
      print('❌ FCM debug error: $e');
    }
  }

  /// Register FCM token with backend API
  static Future<void> _registerFCMToken() async {
    try {
      print('🔄 Getting FCM token...');
      
      // On iOS, wait for APNS token to be available before getting FCM token
      if (Platform.isIOS) {
        await _waitForAPNSToken();
      }
      
      String? token = await _firebaseMessaging.getToken();
      
      if (token != null) {
        print('📱 FCM token obtained: ${token.substring(0, 30)}...${token.substring(token.length - 10)}');
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print('👤 Current user: ${user.uid}');
          
          // Register with backend API
          await _registerTokenWithBackend(user.uid, token);
          
          // Also update Firestore for backup
          await FirebaseFirestore.instance
              .collection('humanUsers')
              .doc(user.uid)
              .set({
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ FCM token registered in Firestore');
        } else {
          print('❌ No authenticated user found');
        }
      } else {
        print('❌ Failed to get FCM token');
      }
    } catch (e) {
      print('❌ Error registering FCM token: $e');
    }
  }

  /// Wait for APNS token to be available on iOS
  static Future<void> _waitForAPNSToken() async {
    try {
      print('🍎 Waiting for APNS token...');
      
      // Try to get APNS token with retries
      int maxRetries = 10;
      int retryCount = 0;
      
      while (retryCount < maxRetries) {
        try {
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            print('✅ APNS token available: ${apnsToken.substring(0, 20)}...');
            return;
          }
        } catch (e) {
          print('⚠️ APNS token not yet available (attempt ${retryCount + 1}/$maxRetries): $e');
        }
        
        retryCount++;
        
        // Wait before retrying, with exponential backoff
        int delaySeconds = retryCount * 2;
        print('⏳ Waiting ${delaySeconds}s before retry...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
      
      print('⚠️ APNS token not available after $maxRetries attempts, proceeding anyway...');
    } catch (e) {
      print('❌ Error waiting for APNS token: $e');
    }
  }

  /// Register token with backend API
  static Future<void> _registerTokenWithBackend(String userId, String token) async {
    try {
      print('🌐 Registering token with backend for user: $userId');
      
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'token': token,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM token registered with backend');
        try {
          final responseData = jsonDecode(response.body);
          print('📊 Backend response: $responseData');
        } catch (e) {
          print('📊 Backend response: ${response.body}');
        }
      } else {
        print('❌ Failed to register FCM token with backend: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error registering token with backend: $e');
    }
  }

  /// Send FCM push notification directly to a user's devices
  static Future<void> _sendPushNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      print('🔄 Sending push notification to user: $userId');
      
      // For push notifications, we should ONLY send to human users, not AI characters
      // First check if this is directly a human user
      final humanUserDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(userId)
          .get();
      
      String? actualUserId;
      
      if (humanUserDoc.exists) {
        // Direct human user ID - use it
        actualUserId = userId;
        print('✅ Confirmed human user ID: $actualUserId');
      } else {
        // Check if it's an AI character ID (should not receive push notifications)
        final aiDoc = await FirebaseFirestore.instance
            .collection('popularCharacters')
            .doc(userId)
            .get();
        
        if (aiDoc.exists) {
          print('❌ Cannot send push notification to AI character: $userId - skipping');
          print('📍 Call stack trace:');
          print(StackTrace.current);
          return;
        }
        
        // Try to resolve as a display name to human user ID
        final resolvedUserId = await _resolveHumanUserId(userId);
        if (resolvedUserId != null) {
          // Double-check that resolved ID is a human user
          final resolvedUserDoc = await FirebaseFirestore.instance
              .collection('humanUsers')
              .doc(resolvedUserId)
              .get();
          
          if (resolvedUserDoc.exists) {
            actualUserId = resolvedUserId;
            print('🔄 Resolved to human user ID: $actualUserId instead of: $userId');
          } else {
            print('❌ Resolved ID is not a human user: $resolvedUserId - skipping push notification');
            return;
          }
        } else {
          print('❌ Could not resolve user ID: $userId - skipping push notification');
          return;
        }
      }
      
      // Send push notification via backend
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/send-push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': actualUserId,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Push notification sent to user $actualUserId');
        var responseData = jsonDecode(response.body);
        print('📊 Push notification stats: ${responseData['stats']}');
      } else {
        print('❌ Failed to send push notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }

  /// Show local notification for immediate feedback
  // static Future<void> _showLocalNotification({
  //   required String title,
  //   required String body,
  //   Map<String, String>? data,
  // }) async {
  //   try {
  //     const NotificationDetails platformChannelSpecifics = NotificationDetails(
  //       android: AndroidNotificationDetails(
  //         'high_importance_channel',
  //         'High Importance Notifications',
  //         channelDescription: 'Channel for important notifications',
  //         importance: Importance.high,
  //         priority: Priority.high,
  //       ),
  //       iOS: DarwinNotificationDetails(),
  //     );

  //     await _localNotifications.show(
  //       DateTime.now().millisecondsSinceEpoch.remainder(100000),
  //       title,
  //       body,
  //       platformChannelSpecifics,
  //       payload: data != null ? jsonEncode(data) : null,
  //     );
  //   } catch (e) {
  //     print('❌ Error showing local notification: $e');
  //   }
  // }

  /// Trigger notification when a new message is sent in a group chat
  /// Enhanced with push notifications
  static Future<void> onGroupMessage(String groupId, String content, String senderId, {String? messageId}) async {
    try {
      // Generate unique message ID if not provided
      final uniqueMessageId = messageId ?? 'msg_${DateTime.now().millisecondsSinceEpoch}_${senderId.hashCode}_${content.hashCode}';
      
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/group-message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'content': content,
          'senderId': senderId,
          'timestamp': DateTime.now().toIso8601String(),
          'messageId': uniqueMessageId, // Add unique message ID for deduplication
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Group message notification event sent');
        
        // Send push notifications to group participants (except sender)
        await _sendGroupMessagePushNotifications(groupId, content, senderId);
      } else {
        print('❌ Failed to send group message event: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sending group message event: $e');
    }
  }

  /// Send push notifications to group participants
  static Future<void> _sendGroupMessagePushNotifications(String groupId, String content, String senderId) async {
    try {
      // Get group participants from Firestore
      final groupDoc = await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(groupId)
          .get();
      
      if (groupDoc.exists) {
        final groupData = groupDoc.data()!;
        final participants = groupData['participants'] as List?;
        final groupName = groupData['name'] as String? ?? 'Group Chat';
        
        if (participants != null) {
          // Get sender name
          String senderName = 'Someone';
          final senderParticipant = participants.firstWhere(
            (p) => p['uid'] == senderId,
            orElse: () => null,
          );
          if (senderParticipant != null) {
            senderName = senderParticipant['name'] ?? 'Someone';
          }
          
          // Send push to all participants except sender
          for (var participant in participants) {
            final participantId = participant['uid'];
            if (participantId != senderId) {
              await _sendPushNotificationToUser(
                userId: participantId,
                title: '$senderName sent a message in $groupName',
                body: content.length > 50 ? '${content.substring(0, 50)}...' : content,
                data: {
                  'type': 'group_message',
                  'groupId': groupId,
                  'senderId': senderId,
                  'timestamp': DateTime.now().toIso8601String(),
                  'action': 'navigate_to_group_chat',
                  'route': '/group-chat/$groupId',
                },
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error sending group message push notifications: $e');
    }
  }

  /// Trigger notification when a user is mentioned in a group chat
  static Future<void> onGroupMention(String groupId, String mentionedUserId, String content, String senderId, {String? messageId}) async {
    try {
      // Generate unique message ID if not provided
      final uniqueMessageId = messageId ?? 'mention_${DateTime.now().millisecondsSinceEpoch}_${senderId.hashCode}_${mentionedUserId.hashCode}';
      
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/group-mention'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'mentionedUserId': mentionedUserId,
          'content': content,
          'senderId': senderId,
          'timestamp': DateTime.now().toIso8601String(),
          'messageId': uniqueMessageId, // Add unique message ID for deduplication
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Group mention notification event sent');
        
        // Send push notification to mentioned user
        await _sendGroupMentionPushNotification(groupId, mentionedUserId, content, senderId);
      }
    } catch (e) {
      print('❌ Error sending group mention event: $e');
    }
  }

  /// Send push notification for group mention
  static Future<void> _sendGroupMentionPushNotification(String groupId, String mentionedUserId, String content, String senderId) async {
    try {
      // Get group and sender info
      final groupDoc = await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(groupId)
          .get();
      
      String groupName = 'Group Chat';
      String senderName = 'Someone';
      
      if (groupDoc.exists) {
        final groupData = groupDoc.data()!;
        groupName = groupData['name'] as String? ?? 'Group Chat';
        
        // Get sender name from participants
        final participants = groupData['participants'] as List?;
        if (participants != null) {
          final senderParticipant = participants.firstWhere(
            (p) => p['uid'] == senderId,
            orElse: () => null,
          );
          if (senderParticipant != null) {
            senderName = senderParticipant['name'] ?? 'Someone';
          }
        }
      }
      
      // Send push notification to mentioned user
      await _sendPushNotificationToUser(
        userId: mentionedUserId,
        title: '$senderName mentioned you in $groupName',
        body: content.length > 50 ? '${content.substring(0, 50)}...' : content,
        data: {
          'type': 'group_mention',
          'groupId': groupId,
          'senderId': senderId,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'navigate_to_group_chat',
          'route': '/group-chat/$groupId',
        },
      );
    } catch (e) {
      print('❌ Error sending group mention push notification: $e');
    }
  }

  /// Trigger notification for 1:1 DM (AI or Human)
  static Future<void> onDirectMessage(String chatId, String content, String senderId, String receiverId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/direct-message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': chatId,
          'content': content,
          'senderId': senderId,
          'receiverId': receiverId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Direct message notification event sent');
        
        // Send push notification to receiver with sender name
        await _sendDirectMessagePushNotification(chatId, content, senderId, receiverId);
      }
    } catch (e) {
      print('❌ Error sending direct message event: $e');
    }
  }

  /// Trigger notification for AI auto-response (with push notification)
  static Future<void> onAIAutoResponse(String chatId, String content, String aiId, String receiverId) async {
    try {
      print('🤖 Triggering AI auto-response notification: AI $aiId -> User $receiverId');
      
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/ai-auto-response'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': chatId,
          'content': content,
          'aiId': aiId,
          'receiverId': receiverId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ AI auto-response notification event sent');
        
        // Send push notification to receiver
        await _sendAIAutoResponsePushNotification(chatId, content, aiId, receiverId);
      } else {
        print('❌ Failed to send AI auto-response event: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending AI auto-response event: $e');
    }
  }

  /// Send push notification for direct message
  static Future<void> _sendDirectMessagePushNotification(String chatId, String content, String senderId, String receiverId) async {
    try {
      // Get sender name for notification
      String senderName = 'Someone';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(senderId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          senderName = userData['name'] ?? userData['displayName'] ?? 'Someone';
        }
      } catch (e) {
        print('Could not fetch sender name: $e');
      }
      
      // Send push notification to receiver with sender name
      await _sendPushNotificationToUser(
        userId: receiverId,
        title: '$senderName sent you a message',
        body: content.length > 50 ? '${content.substring(0, 50)}...' : content,
        data: {
          'type': 'direct_message',
          'chatId': chatId,
          'senderId': senderId,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'navigate_to_chat',
          'route': '/chat/$chatId',
        },
      );
    } catch (e) {
      print('❌ Error sending direct message push notification: $e');
    }
  }

  /// Send push notification for AI auto-response
  static Future<void> _sendAIAutoResponsePushNotification(String chatId, String content, String aiId, String receiverId) async {
    try {
      // Get AI character name for notification
      String aiName = 'AI Character';
      try {
        final aiDoc = await FirebaseFirestore.instance
            .collection('popularCharacters')
            .doc(aiId)
            .get();
        if (aiDoc.exists) {
          final aiData = aiDoc.data()!;
          aiName = aiData['name'] ?? aiData['Name'] ?? 'AI Character';
        }
      } catch (e) {
        print('Could not fetch AI character name: $e');
      }
      
      // Send push notification to receiver
      await _sendPushNotificationToUser(
        userId: receiverId,
        title: '$aiName sent you a message',
        body: content.length > 50 ? '${content.substring(0, 50)}...' : content,
        data: {
          'type': 'ai_auto_response',
          'chatId': chatId,
          'aiId': aiId,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'navigate_to_chat',
          'route': '/chat/$chatId',
        },
      );
      
      print('✅ AI auto-response push notification sent to user $receiverId');
    } catch (e) {
      print('❌ Error sending AI auto-response push notification: $e');
    }
  }

  /// Trigger notification for post engagement (like, comment, etc.)
  static Future<void> onPostEngagement({
    required String postId,
    required String type, // 'like', 'comment', 'share'
    required String userId,
    String? content,
    String? postAuthorId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/post-engagement'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'postId': postId,
          'type': type,
          'userId': userId,
          'content': content,
          'postAuthorId': postAuthorId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Post engagement notification event sent');
        
        // Send push notification to post author (if not engaging with own post)
        if (postAuthorId != null && userId != postAuthorId) {
          await _sendPostEngagementPushNotification(postId, type, userId, postAuthorId, content);
        }
        
        // Track analytics
        AppsFlyerService().logEvent('notification_event_triggered', {
          'event_type': 'post_engagement',
          'engagement_type': type,
          'post_id': postId,
          'user_id': userId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('❌ Error sending post engagement event: $e');
    }
  }

  /// Send push notification for post engagement
  static Future<void> _sendPostEngagementPushNotification(String postId, String type, String userId, String postAuthorId, String? content) async {
    try {
      // Get user name for notification
      String userName = 'Someone';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          userName = userData['name'] ?? userData['displayName'] ?? 'Someone';
        }
      } catch (e) {
        print('Could not fetch user name: $e');
      }

      // Generate notification message based on type
      String title = '';
      String body = '';
      
      switch (type) {
        case 'like':
          title = 'New Like';
          body = '$userName liked your post';
          break;
        case 'comment':
          title = 'New Comment';
          body = '$userName commented on your post${content != null ? ': ${content.length > 30 ? '${content.substring(0, 30)}...' : content}' : ''}';
          break;
        case 'share':
          title = 'Post Shared';
          body = '$userName shared your post';
          break;
        default:
          title = 'Post Engagement';
          body = '$userName interacted with your post';
      }
      
      // Send push notification to post author
      await _sendPushNotificationToUser(
        userId: postAuthorId,
        title: title,
        body: body,
        data: {
          'type': 'post_engagement',
          'postId': postId,
          'engagementType': type,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'navigate_to_post',
          'route': '/post/$postId',
        },
      );
    } catch (e) {
      print('❌ Error sending post engagement push notification: $e');
    }
  }

  /// Trigger notification for follow events
  static Future<void> onUserFollow(String followerId, String followedUserId) async {
    print('📋 DEBUG: onUserFollow called with:');
    print('   - followerId: "$followerId"');
    print('   - followedUserId: "$followedUserId"');
    
    // Don't send notification if user is following themselves
    if (followerId == followedUserId) {
      print('🚫 Skipping follow notification: User cannot follow themselves');
      return;
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/user-follow'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'followerId': followerId,
          'followedUserId': followedUserId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ User follow notification event sent');
        
        // Send push notification to followed user
        await _sendFollowPushNotification(followerId, followedUserId);
      } else {
        print('❌ Failed to send follow event: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending user follow event: $e');
    }
  }

  /// Send push notification for follow event
  static Future<void> _sendFollowPushNotification(String followerId, String followedUserId) async {
    try {
      print('📋 DEBUG: _sendFollowPushNotification called with:');
      print('   - followerId: "$followerId"');
      print('   - followedUserId: "$followedUserId"');
      
      // Get follower name for notification
      String followerName = 'Someone';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(followerId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          followerName = userData['name'] ?? userData['displayName'] ?? 'Someone';
          print('📋 DEBUG: Found follower name: "$followerName"');
        } else {
          print('📋 DEBUG: Follower document not found for ID: "$followerId"');
        }
      } catch (e) {
        print('Could not fetch follower name: $e');
      }
      
      print('📋 DEBUG: About to call _sendPushNotificationToUser with userId: "$followedUserId"');
      
      // Send push notification to the followed user
      await _sendPushNotificationToUser(
        userId: followedUserId,
        title: 'New Follower',
        body: '$followerName started following you',
        data: {
          'type': 'user_follow',
          'followerId': followerId,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'navigate_to_profile',
          'route': '/profile/$followerId',
        },
      );
    } catch (e) {
      print('❌ Error sending follow push notification: $e');
    }
  }

  /// Trigger notification for system events (streaks, milestones)
  static Future<void> onSystemEvent({
    required String userId,
    required String type, // 'streak', 'milestone', 'welcome'
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/system'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'type': type,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ System notification event sent');
      }
    } catch (e) {
      print('❌ Error sending system event: $e');
    }
  }

  /// Trigger rare coin offer notification
  static Future<void> onRareCoinOffer({
    required String userId,
    required String offerType, // 'watch_video', 'refer_friend', 'double_coins'
    required int coinAmount,
    String? reason, // 'low_balance', 'failed_purchase', 'inactive'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/rare-offer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'offerType': offerType,
          'coinAmount': coinAmount,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Rare coin offer notification event sent');
        
        // Track analytics
        AppsFlyerService().logEvent('rare_offer_triggered', {
          'user_id': userId,
          'offer_type': offerType,
          'coin_amount': coinAmount,
          'reason': reason,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('❌ Error sending rare coin offer event: $e');
    }
  }

  /// Check if user qualifies for rare coin offers
  static Future<void> checkRareCoinOfferEligibility(String userId) async {
    try {
      // Get user's current balance
      final userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final currentBalance = userData['balance'] ?? 0;
      final lastOfferCheck = userData['lastOfferCheck'] as Timestamp?;
      
      // Check if user has low balance (less than 100 coins)
      if (currentBalance < 100) {
        await onRareCoinOffer(
          userId: userId,
          offerType: 'watch_video',
          coinAmount: 50,
          reason: 'low_balance',
        );
        return;
      }
      
      // Check if user hasn't earned coins in 7 days
      if (lastOfferCheck != null) {
        final daysSinceLastOffer = DateTime.now()
            .difference(lastOfferCheck.toDate())
            .inDays;
        
        if (daysSinceLastOffer >= 7) {
          await onRareCoinOffer(
            userId: userId,
            offerType: 'refer_friend',
            coinAmount: 200,
            reason: 'inactive',
          );
        }
      }
      
      // Update last offer check timestamp
      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(userId)
          .update({
        'lastOfferCheck': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('❌ Error checking rare coin offer eligibility: $e');
    }
  }

  /// Handle failed purchase - trigger coin offer
  static Future<void> onFailedPurchase(String userId, int attemptedAmount) async {
    await onRareCoinOffer(
      userId: userId,
      offerType: 'watch_video',
      coinAmount: attemptedAmount,
      reason: 'failed_purchase',
    );
  }

  /// Queue AI nudge notification for inactive users
  static Future<void> queueAINudge(String userId, String characterId, String lastChatId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/notifications/events/ai-nudge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'characterId': characterId,
          'lastChatId': lastChatId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ AI nudge notification queued');
      }
    } catch (e) {
      print('❌ Error queueing AI nudge: $e');
    }
  }

  /// Mark notification as delivered
  static Future<void> markNotificationDelivered(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notificationsQueue')
          .doc(notificationId)
          .update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking notification as delivered: $e');
    }
  }

  /// Mark notification as opened
  // deeplink parameter is deprecated and removed from storage
  static Future<void> markNotificationOpened(String notificationId, /* String? deeplink */) async {
    try {
      await FirebaseFirestore.instance
          .collection('notificationsQueue')
          .doc(notificationId)
          .update({
        'status': 'opened',
        'openedAt': FieldValue.serverTimestamp(),
      });
      
      // Track analytics (deprecated deeplink removed)
      AppsFlyerService().logEvent('notif_open', {
        'notification_id': notificationId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      // If the document wasn't found, create it (merge) so the app doesn't crash
      try {
        if (e is FirebaseException && e.code == 'not-found') {
          await FirebaseFirestore.instance
              .collection('notificationsQueue')
              .doc(notificationId)
              .set({
            'status': 'opened',
            'openedAt': FieldValue.serverTimestamp(),
            // 'deeplink': deeplink, // removed
          }, SetOptions(merge: true));

          AppsFlyerService().logEvent('notif_open', {
            'notification_id': notificationId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          return;
        }
      } catch (inner) {
        // swallow and fallthrough to logging the original error
      }

      print('❌ Error marking notification as opened: $e');
    }
  }

  /// Mark notification as dismissed
  static Future<void> markNotificationDismissed(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notificationsQueue')
          .doc(notificationId)
          .update({
        'status': 'dismissed',
        'dismissedAt': FieldValue.serverTimestamp(),
      });
      
      // Track analytics
      AppsFlyerService().logEvent('notif_dismiss', {
        'notification_id': notificationId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Error marking notification as dismissed: $e');
    }
  }

  /// Handle push notification tap routing
  /// This method should be called when a user taps on a push notification
  static Future<void> handlePushNotificationTap(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String? ?? 'system';
      print('🔗 Handling push notification tap - Type: $type, Data: $data');

      final user = FirebaseAuth.instance.currentUser;
      print('👤 Current user: ${user?.uid ?? 'null'}');
      
      // Mark the corresponding notification in Firestore as read
      // Search for notification by its characteristics since there's no id field
      if (user != null) {
        print('📝 About to call _markNotificationAsReadByData for user: ${user.uid}');
        await _markNotificationAsReadByData(user.uid, type, data);
        print('✅ _markNotificationAsReadByData completed');
        
        // Clear iOS badge immediately using multiple approaches
        if (Platform.isIOS) {
          try {
            print('📱 Force clearing iOS badge...');
            await NotificationBadgeService.forceIOSBadgeClear();
            print('✅ iOS badge force cleared');
          } catch (e) {
            print('⚠️ Error force clearing iOS badge: $e');
          }
        }
        
        // Immediately update iOS badge after marking notification as read
        print('📱 Immediately updating iOS badge...');
        await NotificationBadgeService.syncBadgeCount();
      } else {
        print('❌ User is null, cannot mark notification as read');
      }
      
      // Import the badge service to ensure notifications get marked as read
      // and badge counts are updated properly on iOS
      try {
        // final notificationId = data['notificationId'] as String?;
        // if (notificationId != null) {
        //   // Mark this specific notification as read
        //   await markNotificationOpened(notificationId);
        //   
        //   // Update badge count
        //   await NotificationBadgeService.syncBadgeCount();
        // }
        
        print('🔄 Syncing badge count again for safety...');
        // Update badge count after marking notification as read
        await NotificationBadgeService.syncBadgeCount();
        print('✅ Badge count sync completed');
      } catch (e) {
        print('⚠️ Error updating notification read state: $e');
      }

      // Handle navigation based on notification type and data
      // This follows the exact same logic as notification_center_screen.dart
      switch (type) {
        case 'follow':
        case 'user_follow':
          print('🔗 Follow notification - navigating to followers screen');
          // Get the follower ID from notification data
          final followerId = data['followerId'] as String? ?? data['userId'] as String?;
          if (followerId != null) {
            // Navigate to the follower's profile followers/following screen
            AppRouter.router.push(Routes.followersFollowingPath(followerId));
          } else {
            // Fallback to home
            AppRouter.router.push(Routes.home);
          }
          break;
          
        case 'comment':
        case 'post_comment':
          print('🔗 Comment notification - navigating to post with comments opened');
          final postId = data['postId'] as String?;
          final commentId = data['commentId'] as String?;
          
          if (postId != null && postId.startsWith('post_')) {
            // Extract user ID from post ID (format: post_userId_timestamp)  
            final parts = postId.split('_');
            if (parts.length >= 3) {
              final userId = parts[1];
              print('🔗 Navigating to profile: $userId with post: $postId and comments opened');
              
              // Build route with query parameters for auto-opening comments
              String route = Routes.regularProfilePath(userId);
              route += '?post=$postId&openComments=true';
              if (commentId != null) {
                route += '&commentId=$commentId';
              }
              
              AppRouter.router.push(route);
            } else {
              // Fallback to home if post ID format is unexpected
              print('⚠️ Unexpected post ID format: $postId');
              AppRouter.router.push(Routes.home);
            }
          } else {
            print('⚠️ No postId or invalid format in comment notification');
            AppRouter.router.push(Routes.home);
          }
          break;
          
        case 'like':
        case 'post_like':
        case 'repost':
        case 'post_engagement':
          print('🔗 Like/Repost/Post engagement notification - navigating to post');
          final postId = data['postId'] as String?;
          
          if (postId != null && postId.startsWith('post_')) {
            // Extract user ID from post ID
            final parts = postId.split('_');
            if (parts.length >= 3) {
              final userId = parts[1];
              print('🔗 Navigating to profile: $userId with post: $postId');
              
              String route = Routes.regularProfilePath(userId);
              route += '?post=$postId';
              
              AppRouter.router.push(route);
            } else {
              // Fallback to home if post ID format is unexpected
              print('⚠️ Unexpected post ID format: $postId');
              AppRouter.router.push(Routes.home);
            }
          } else {
            print('⚠️ No postId or invalid format in engagement notification');
            AppRouter.router.push(Routes.home);
          }
          break;
          
        case 'group_message':
        case 'group_mention':
          print('🔗 Group message/mention notification - navigating to group chat');
          final chatId = data['chatId'] as String? ?? data['groupId'] as String?;
          
          if (chatId != null && chatId.startsWith('group_chat_')) {
            // Group chat
            final groupData = GroupData(
              id: chatId,
              name: data['groupName'] as String? ?? 'Group Chat',
              description: '',
              memberCount: 0,
              messageCount: 0,
              avatars: [],
              isMember: true,
              showRandomCharacters: true,
            );
            AppRouter.router.push(Routes.groupChat, extra: groupData);
          } else {
            print('⚠️ Invalid group chat ID: $chatId');
            AppRouter.router.push(Routes.home);
          }
          break;
          
        case 'direct_message':
        case 'ai_auto_response':
          print('🔗 Direct message/AI auto-response notification - navigating to chat');
          final chatId = data['chatId'] as String?;
          
          if (chatId != null) {
            // Individual chat - extract other user ID
            final currentUserId = user?.uid ?? '';
            final userIds = chatId.split('_');
            String? otherUserId;
            
            for (String userId in userIds) {
              if (userId != currentUserId) {
                otherUserId = userId;
                break;
              }
            }
            
            if (otherUserId != null) {
              // Try to get the other user's name, first from notification data, then from Firestore
              String otherUserName = data['senderName'] as String? ?? data['aiCharacterName'] as String? ?? 'Chat';
              
              // If we don't have a proper name from notification data, fetch from Firestore
              if (otherUserName == 'Chat' || otherUserName.isEmpty) {
                try {
                  // Try popular characters first (for AI characters)
                  var userDoc = await FirebaseFirestore.instance
                      .collection('popularCharacters')
                      .doc(otherUserId)
                      .get();
                  
                  if (userDoc.exists) {
                    final userData = userDoc.data()!;
                    otherUserName = userData['name'] ?? userData['displayName'] ?? userData['username'] ?? 'AI Character';
                    print('🔗 Fetched AI character name from Firestore: $otherUserName');
                  } else {
                    // Try human users
                    userDoc = await FirebaseFirestore.instance
                        .collection('humanUsers')
                        .doc(otherUserId)
                        .get();
                    if (userDoc.exists) {
                      final userData = userDoc.data()!;
                      otherUserName = userData['name'] ?? userData['displayName'] ?? userData['username'] ?? 'User';
                      print('🔗 Fetched user name from Firestore: $otherUserName');
                    }
                  }
                } catch (e) {
                  print('❌ Error fetching other user name: $e');
                }
              }
              
              AppRouter.router.push(Routes.chat, extra: {
                'conversationId': chatId,
                'otherUserId': otherUserId,
                'otherUserName': otherUserName,
              });
            } else {
              print('⚠️ Could not determine other user ID from chat ID: $chatId');
              AppRouter.router.push(Routes.home);
            }
          } else {
            print('⚠️ No chatId in direct message notification');
            AppRouter.router.push(Routes.home);
          }
          break;
          
        default:
          print('🔗 Unknown notification type: $type - going to home');
          AppRouter.router.push(Routes.home);
          break;
      }
      
      // After successful navigation, ensure badge is updated
      try {
        await NotificationBadgeService.syncBadgeCount();
      } catch (e) {
        print('⚠️ Error syncing badge count after navigation: $e');
      }
      
    } catch (e) {
      print('❌ Error handling push notification tap: $e');
      // Fallback to home
      try {
        AppRouter.router.push(Routes.home);
      } catch (fallbackError) {
        print('❌ Failed to navigate to home: $fallbackError');
      }
    }
  }
}