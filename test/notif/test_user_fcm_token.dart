import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/config/default_firebase_options.dart';

/// Test FCM token registration for current user
Future<void> testCurrentUserFCMToken() async {
  print('🧪 Testing current user FCM token registration...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Check current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user is currently signed in');
      return;
    }
    
    print('✅ Current user: ${user.uid}');
    print('✅ User email: ${user.email}');
    
    // Get FCM token
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    
    if (token == null) {
      print('❌ Failed to get FCM token');
      return;
    }
    
    print('✅ FCM Token: ${token.substring(0, 20)}...');
    
    // Check if user document exists in Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('humanUsers')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) {
      print('❌ User document does not exist in humanUsers collection');
      print('📝 Creating user document...');
      
      // Create basic user document
      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? 'Test User',
        'fcmTokens': [token],
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ User document created with FCM token');
    } else {
      print('✅ User document exists');
      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmTokens = userData['fcmTokens'] as List<dynamic>? ?? [];
      
      if (fcmTokens.contains(token)) {
        print('✅ FCM token is already registered');
      } else {
        print('📝 Adding FCM token to user document...');
        await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(user.uid)
            .update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token added to user document');
      }
    }
    
    // Test backend token registration
    print('\n🧪 Testing backend token registration...');
    final response = await http.post(
      Uri.parse('https://inzoneapi-912424781531.us-central1.run.app/api/notifications/register-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': user.uid,
        'token': token,
      }),
    );
    
    print('Backend registration status: ${response.statusCode}');
    print('Backend registration response: ${response.body}');
    
    if (response.statusCode == 200) {
      print('✅ FCM token successfully registered with backend');
    } else {
      print('❌ Backend token registration failed');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

void main() async {
  await testCurrentUserFCMToken();
}
