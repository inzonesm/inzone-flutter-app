import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings_tile.dart';
import 'package:inzone/introduction_screen.dart';
// ignore: unused_import
import 'package:sliding_sheet2/sliding_sheet2.dart';
import 'package:url_launcher/url_launcher.dart';

import 'components/topic_selector_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  Future<void> _launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        headers: <String, String>{"header_key": "header_value"},
      );
    } else {
      throw "Could not launch $url";
    }
  }
  Future<void> _deleteAccount(BuildContext context) async {
    try {
      // Sign out of Firebase
      await FirebaseAuth.instance.signOut();

      // Delete the user account
      await FirebaseAuth.instance.currentUser?.delete();

      // Navigate to the introduction screen and clear navigation stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const IntroductionScreen()),
            (Route<dynamic> route) => false, // This removes all previous routes
      );
    } catch (e) {
      // Handle any errors (e.g., re-authentication required)
      if (e.toString().contains('requires-recent-login')) {
        // Show a dialog informing the user to re-authenticate
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Re-authentication required'),
              content: const Text(
                  'For security reasons, please sign in again to delete your account.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        // Display an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          elevation: 0,
          backgroundColor:  Theme.of(context).canvasColor,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            "Settings",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),

      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Settings",
                  style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  width: MediaQuery.of(context).size.width - 20,
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Column(children: [
                    // SettingsTile(
                    //     title: "InZone Schedule",
                    //     imagePath: "icons/settings/content_scheduling.svg",
                    //     onPressed: () {
                    //       // Navigator.of(context)
                    //       //     .push(MaterialPageRoute(builder: (context) {
                    //       //   return const InZoneSchedule();
                    //       // }));
                    //     }),
                    SettingsTile(
                        title: "Content Selection",
                        imagePath: "icons/settings/content_selection.svg",
                        onPressed: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (context) {
                            return const ContentSelectionSettingsScreen();
                          }));
                        }),


                  ]),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text(
                  "Other Settings",
                  style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  width: MediaQuery.of(context).size.width - 20,
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(30)),
                  child: Column(children: [

                    SettingsTile(
                        title: "Privacy Policy",
                        imagePath: "icons/settings/privacy_policy.svg",
                        onPressed: () {_launchInBrowser("https://www.inzone.ai/privacypolicy");}),
                    SettingsTile(
                        title: "Terms & Conditions",
                        imagePath: "icons/settings/terms_and_conditions.svg",
                        onPressed: () {_launchInBrowser(
                            "https://www.inzone.ai/terms-condition");}),
                    SettingsTile(
                      title: "Delete Account",
                      imagePath: "icons/settings/delete_account.svg",
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Delete Account'),
                              content: const Text(
                                  'Are you sure you want to delete your account? This cannot be undone.'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                  child: const Text('Delete'),
                                  onPressed: () {
                                    // Close the dialog, then call the delete account method
                                    Navigator.of(context).pop();
                                    _deleteAccount(context);
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    SettingsTile(
                        title: "Logout",
                        imagePath: "icons/settings/logout.svg",
                        onPressed: () {
                          FirebaseAuth.instance.signOut().then((value) {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>const IntroductionScreen()));
                          });
                        }),
                  ]),
                ),
              ],
            ),
          )),
    );
  }
}


class ContentSelectionSettingsScreen extends StatefulWidget {
  const ContentSelectionSettingsScreen({super.key});

  @override
  _ContentSelectionSettingsScreenState createState() => _ContentSelectionSettingsScreenState();
}

class _ContentSelectionSettingsScreenState extends State<ContentSelectionSettingsScreen> {
  final List<String> selectedTopics = [];

  void addToList(String topic) {
    setState(() {
      selectedTopics.contains(topic) ? selectedTopics.remove(topic) : selectedTopics.add(topic);
    });
  }

  Widget _buildContentSelectionPage() {
    List<String> topicList = [
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80.0),
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
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Topics"),
      ),
      body: Column(
        children: [
          Expanded(child: _buildContentSelectionPage()),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSelection,
                child: const Text("Save"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
