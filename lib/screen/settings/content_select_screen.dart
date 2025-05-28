import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings/topic_selector_widget.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ContentSelectionSettingsScreen extends StatefulWidget {
  const ContentSelectionSettingsScreen({super.key});

  @override
  _ContentSelectionSettingsScreenState createState() =>
      _ContentSelectionSettingsScreenState();
}

class _ContentSelectionSettingsScreenState
    extends State<ContentSelectionSettingsScreen> {
  final List<String> selectedTopics = [];

  void addToList(String topic) {
    setState(() {
      selectedTopics.contains(topic)
          ? selectedTopics.remove(topic)
          : selectedTopics.add(topic);
    });
  }

  void _saveSelection() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Saved"),
        backgroundColor: Colors.blue,
      ),
    );
    context.pop();
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
    'Arts & Creativity': 'icons/content_icons/1.png',
    'Entertainment & Pop Culture': 'icons/content_icons/2.png',
    'Learning & Knowledge': 'icons/content_icons/3.png',
    'Lifestyle & Hobbies': 'icons/content_icons/4.png',
  };

  void _goBack() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      topColor: Theme.of(context).canvasColor,
      left: false,
      right: false,
      top: true,
      bottom: false,
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: Theme.of(context).cardColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_ios,
                              size: 18,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
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
                          'Pick things you\'d like to see on your feed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
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
                                        color: Theme.of(context).cardColor,
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
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: List.generate(
                                  topics.length,
                                  (i) {
                                    return TopicSelectorWidget(
                                      topic: topics[i],
                                      callBack: addToList,
                                    );
                                  },
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
            padding:
                const EdgeInsets.only(left: 15, right: 15, bottom: 30, top: 15),
            child: Button(text: "Done", onPressed: _saveSelection)),
      ),
    );
  }
}
