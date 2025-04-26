import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings/topic_selector_widget.dart';
import 'package:inzone/root_app.dart';
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

    try {
      await InZoneDatabase.createUserProfile(
        name: user.displayName ?? user.email ?? 'Unknown',
        email: user.email ?? widget.email,
        age: 0, // 나중에 age 필드가 있다면 이쪽으로 받아와도 됨
        gender: "unknown", // 나중에 추가로 받는다면 수정 가능
        userUid: user.uid,
        userInterests: _interests,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RootApp()),
          (route) => false,
        );
      }
    } catch (e) {
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
