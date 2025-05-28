import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/components/settings/topic_selector_widget.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/router/app_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  // Topic categories
  final Map<String, List<String>> topicCategories = {
    'Social & Personal Development': [
      'environmental_conservation',
      'bullying_prevention',
      'mental_health',
      'inclusivity',
      'anti_discrimination',
      'healthy_habits',
      'financial_literacy',
      'empowerment',
      'friendship',
      'community_service',
    ],
    'Arts & Creativity': [
      'creativity',
      'art',
      'dance',
      'music',
      'fashion',
    ],
    'Entertainment & Pop Culture': [
      'funny_memes',
      'animated_movies',
      'challenge_videos',
      'video_game_reviews',
      'board_games',
      'magic_tricks',
      'lego',
    ],
    'Learning & Knowledge': [
      'science',
      'books',
    ],
    'Lifestyle & Hobbies': [
      'diy',
      'cooking',
      'animals',
      'outdoor_adventures',
      'travel',
    ],
  };

  // Category icons
  final Map<String, String> categoryIcons = {
    'Social & Personal Development': 'icons/content_icons/cloths.png',
    'Arts & Creativity': 'icons/content_icons/music.png',
    'Entertainment & Pop Culture': 'icons/content_icons/popcorn.png',
    'Learning & Knowledge': 'icons/content_icons/tools.png',
    'Lifestyle & Hobbies': 'icons/content_icons/game.png',
  };

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
        context.pop();
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
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Interest',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Choose a few topics you care about',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          String categoryName =
                              topicCategories.keys.elementAt(index);
                          List<String> topics = topicCategories[categoryName]!;
                          String iconPath = categoryIcons[categoryName]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 8.0, top: 16.0, bottom: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: Image.asset(
                                          iconPath,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      categoryName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: topics.length <= 4
                                    // Single row layout for 4 or fewer topics
                                    ? Row(
                                        children: topics
                                            .map((topic) => TopicSelectorWidget(
                                                  topic: topic,
                                                  callBack: _toggleInterest,
                                                ))
                                            .toList(),
                                      )
                                    // Two-row layout for more than 4 topics
                                    : SizedBox(
                                        height:
                                            110, // Height for 2 rows of topics
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // First row
                                            Expanded(
                                              child: Row(
                                                children: topics
                                                    .sublist(
                                                        0,
                                                        (topics.length / 2)
                                                                    .ceil() >
                                                                topics.length
                                                            ? topics.length
                                                            : (topics.length /
                                                                    2)
                                                                .ceil())
                                                    .map((topic) =>
                                                        TopicSelectorWidget(
                                                          topic: topic,
                                                          callBack:
                                                              _toggleInterest,
                                                        ))
                                                    .toList(),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            // Second row
                                            Expanded(
                                              child: Row(
                                                children: topics.length >
                                                        (topics.length / 2)
                                                            .ceil()
                                                    ? topics
                                                        .sublist(
                                                            (topics.length / 2)
                                                                .ceil())
                                                        .map((topic) =>
                                                            TopicSelectorWidget(
                                                              topic: topic,
                                                              callBack:
                                                                  _toggleInterest,
                                                            ))
                                                        .toList()
                                                    : [],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                        childCount: topicCategories.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Button(
            text: _interests.isEmpty
                ? "Start InZone"
                : "Start InZone (${_interests.length} selected)",
            onPressed: _finishSignUp,
          ),
        ),
      ),
    );
  }
}
