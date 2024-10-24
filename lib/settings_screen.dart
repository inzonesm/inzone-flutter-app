import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings_tile.dart';
import 'package:inzone/introduction_screen.dart';
// ignore: unused_import
import 'package:sliding_sheet2/sliding_sheet2.dart';
import 'package:url_launcher/url_launcher.dart';

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
      // Your logic to delete the account comes here
      // Example: Firebase Auth to delete the current user
      await FirebaseAuth.instance.currentUser?.delete();

      // After deleting the account, navigate to the introduction screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const IntroductionScreen()),
      );
    } on FirebaseAuthException catch (e) {
      // If an error occurs, show the error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete the account: ${e.message}')),
      );
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
                    SettingsTile(
                        title: "InZone Schedule",
                        imagePath: "icons/settings/content_scheduling.svg",
                        onPressed: () {
                          // Navigator.of(context)
                          //     .push(MaterialPageRoute(builder: (context) {
                          //   return const InZoneSchedule();
                          // }));
                        }),
                    SettingsTile(
                        title: "Content Selection",
                        imagePath: "icons/settings/content_selection.svg",
                        onPressed: () {
                          // Navigator.of(context)
                          //     .push(MaterialPageRoute(builder: (context) {
                          //   return ContentSelectionSignupScreen(newUser: false);
                          // }));
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
                        title: "Edit Profile",
                        imagePath:"icons/settings/edit_profile.svg",
                        onPressed: () {
                          // Navigator.of(context)
                          //     .push(MaterialPageRoute(builder: (context) {
                          //   return const  Charactertemp();
                          // }));
                        }),

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
                                content: const Text('Are you sure you want to delete your account? This cannot be undone.'),
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
                                      // Dismiss the dialog and then call the delete account method
                                      Navigator.of(context).pop();
                                      _deleteAccount(context);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }
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
