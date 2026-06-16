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

    // Also listen for user data changes. The snapshot already carries the
    // doc, so compute completion from it directly (checkAuth() would re-fetch
    // the same doc) and only notify when the value actually flips — the user
    // doc changes often (balance updates etc.) and this notifier drives
    // GoRouter's redirect re-evaluation.
    if (_auth.currentUser != null) {
      FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(_auth.currentUser!.uid)
          .snapshots()
          .listen((docSnapshot) {
        final data = docSnapshot.data();
        final hasCreatedAt = data?['createdAt'] != null;
        final completed = docSnapshot.exists && hasCreatedAt;
        if (completed != _isProfileCompleted) {
          _isProfileCompleted = completed;
          notifyListeners();
        }
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
        final data = docSnapshot.data();
        // Onboarding is complete only once `createdAt` is set — and that is set
        // exclusively at the end of the interests screen. We deliberately do NOT
        // treat merely having a name/username as "complete", so a user who
        // entered a name but never finished setup can't skip the interests step.
        final hasCreatedAt = data?['createdAt'] != null;
        _isProfileCompleted = docSnapshot.exists && hasCreatedAt;
        print("AuthNotifier - Profile completion status: $_isProfileCompleted");
        print("AuthNotifier - createdAt value: ${data?['createdAt']}");
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
