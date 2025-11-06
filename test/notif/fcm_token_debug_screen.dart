import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FCMTokenDebugScreen extends StatefulWidget {
  const FCMTokenDebugScreen({super.key});

  @override
  _FCMTokenDebugScreenState createState() => _FCMTokenDebugScreenState();
}

class _FCMTokenDebugScreenState extends State<FCMTokenDebugScreen> {
  String _debugInfo = 'Loading...';

  @override
  void initState() {
    super.initState();
    _checkFCMTokens();
  }

  Future<void> _checkFCMTokens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _debugInfo = 'No user logged in';
        });
        return;
      }

      // Check Firestore for FCM tokens
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        List<dynamic>? fcmTokens = userData['fcmTokens'];
        
        setState(() {
          _debugInfo = '''
User ID: ${user.uid}
User Email: ${user.email}
FCM Tokens Count: ${fcmTokens?.length ?? 0}
FCM Tokens: ${fcmTokens?.map((t) => '${t.toString().substring(0, 20)}...').join('\n') ?? 'None'}
Last Token Update: ${userData['lastTokenUpdate']}
          ''';
        });
      } else {
        setState(() {
          _debugInfo = 'User document not found in Firestore';
        });
      }
    } catch (e) {
      setState(() {
        _debugInfo = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Token Debug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FCM Token Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _debugInfo,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkFCMTokens,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
