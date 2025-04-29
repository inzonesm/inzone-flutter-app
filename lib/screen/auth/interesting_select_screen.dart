import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/components/settings/topic_selector_widget.dart';
import 'package:inzone/router/app_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InterestSelectionScreen extends StatefulWidget {
  final String email;

  const InterestSelectionScreen({
    super.key,
    required this.email,
  });

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final List<String> _interests = [];

  void _toggleInterest(String topic) {
    setState(() {
      if (_interests.contains(topic)) {
        _interests.remove(topic);
      } else {
        _interests.add(topic);
      }
    });
  }

  final List<String> topicList = [
    'environmental_conservation',
    'bullying_prevention',
    'mental_health',
    'inclusivity',
    'anti_discrimination',
    'healthy_habits',
    'community_service',
    'creativity',
    'science',
    'funny_memes',
    'diy',
    'video_game_reviews',
    'animated_movies',
    'challenge_videos',
    'cooking',
    'animals',
    'magic_tricks',
    'board_games',
    'art',
    'dance',
    'outdoor_adventures',
    'music',
    'books',
    'travel',
    'lego',
    'fashion',
    'financial_literacy',
    'empowerment',
    'friendship'
  ];
  Future<void> _finishSignUp() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User not logged in."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 16),
                Text(
                  "Setting up InZone...",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      print("InterestScreen - Finishing signup for user: ${user.uid}");
      print("InterestScreen - Selected interests: $_interests");

      // Set a timestamp to mark profile completion
      final timestamp = DateTime.now().toIso8601String();
      print("InterestScreen - Setting createdAt timestamp: $timestamp");

      // Update the user document with interests and createdAt timestamp
      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(user.uid)
          .update({
        'interests': _interests,
        'createdAt': timestamp,
      });

      print("InterestScreen - Updated interests and set createdAt timestamp");

      // Force refresh of auth state
      await AppRouter.authNotifier.refreshAuthState();

      if (mounted) {
        // 로딩 다이얼로그 닫기
        Navigator.of(context).pop();

        print("InterestScreen - Navigating to home screen");
        // Use replaceAll to completely replace the navigation stack and ensure we go to the root app
        context.pushReplacement(Routes.home);
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
      }

      print("InterestScreen - Error completing signup: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to complete sign up: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).canvasColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).canvasColor,
          title: const Text("Select Your Interests"),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Choose a few topics you care about",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topicList
                      .map((topic) => TopicSelectorWidget(
                            topic: topic,
                            callBack: _toggleInterest,
                          ))
                      .toList(),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: ElevatedButton(
                onPressed: _finishSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Text(
                    "Start InZone",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
