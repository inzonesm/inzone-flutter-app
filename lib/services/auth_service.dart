import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Key for storing first launch status in SharedPreferences
const String FIRST_LAUNCH_KEY = 'is_first_launch';

/// AuthService handles authentication-related functionality
/// including sign out with onboarding reset.
///
/// The onboarding flow works as follows:
/// 1. First app launch -> Show onboarding -> Mark first launch as false
/// 2. Subsequent launches with logged in user -> Skip onboarding, go to home
/// 3. Subsequent launches without logged in user -> Skip onboarding, go to login
/// 4. After logout -> Reset first launch flag -> Next app start will show onboarding
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign out and reset first launch flag to show onboarding again
  Future<void> signOut() async {
    try {
      // Reset first launch flag to show onboarding again after logout
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(FIRST_LAUNCH_KEY, true);

      // Log the action
      print('Reset first launch flag to show onboarding after logout');

      // Sign out from Firebase
      await _auth.signOut();
      print('User signed out successfully');
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }

  // Check if user is logged in
  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}
