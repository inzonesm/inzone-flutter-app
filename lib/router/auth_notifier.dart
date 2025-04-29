import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isProfileCompleted = false;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isProfileCompleted => _isProfileCompleted;

  AuthNotifier() {
    print("AuthNotifier - Initializing");
    checkAuth();
    _auth.authStateChanges().listen((user) {
      print(
          "AuthNotifier - Auth state changed: User ${user != null ? 'logged in' : 'logged out'}");
      checkAuth();
    });

    // Also listen for user data changes
    if (_auth.currentUser != null) {
      FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(_auth.currentUser!.uid)
          .snapshots()
          .listen((_) {
        print("AuthNotifier - User data changed");
        checkAuth();
      });
    }
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) {
      _isProfileCompleted = false;
    } else {
      final docRef =
          FirebaseFirestore.instance.collection('humanUsers').doc(user.uid);
      try {
        final docSnapshot = await docRef.get();
        _isProfileCompleted =
            docSnapshot.exists && docSnapshot.data()?['createdAt'] != null;
        print("AuthNotifier - Profile completion status: $_isProfileCompleted");
        print(
            "AuthNotifier - createdAt value: ${docSnapshot.data()?['createdAt']}");
      } catch (e) {
        _isProfileCompleted = false;
        print("AuthNotifier - Error checking profile: $e");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // Method to manually refresh auth state after updating user data
  Future<void> refreshAuthState() async {
    print("AuthNotifier - Manual refresh requested");
    await checkAuth();
  }
}
