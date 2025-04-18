import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings/topic_selector_widget.dart';
import 'package:inzone/components/ui/appbar.dart';

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
    Navigator.pop(context);
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
    'friendship',
  ];

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      topColor: Theme.of(context).canvasColor,
      left: false,
      right: false,
      top: true,
      bottom: false,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CustomAppBar(
              isImage: false,
              isSettings: true,
              isHome: true,
              title: "Select Topics",
              userPoints: "100",
              onSearchTap: () {},
              onProfileTap: () {},
              onPointsTap: () {},
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(
                          topicList.length,
                          (index) {
                            String currentTopic = topicList[index];
                            return TopicSelectorWidget(
                              topic: currentTopic,
                              callBack: addToList,
                            );
                          },
                        ),
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
          child: GestureDetector(
            onTap: () async {
              _saveSelection();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 60,
              width: MediaQuery.of(context).size.width - 80,
              decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'DONE',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
