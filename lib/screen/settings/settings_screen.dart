import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings/settings_tile.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/screen/auth/introduction_screen.dart';
import 'package:inzone/screen/settings/contact_screen.dart';
import 'package:inzone/screen/settings/content_select_screen.dart';
import 'package:inzone/screen/settings/subscription_purchase.dart';
import 'package:inzone/screen/settings/referral_screen.dart';
// ignore: unused_import
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key});
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

  List<String> category = ["Personal", "Others"];

  List<String> personalTitleList = [
    "Content Selection",
    "Subscription"
  ];
  List<String> personalSubtitleList = [
    "You can select different content",
    "Manage your InCash subscription"
  ];
  List<VoidCallback> personalOnPressedList(BuildContext context) {
    return [
          () {
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ContentSelectionSettingsScreen(),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error navigating to content selection: $e')),
          );
        }
      },
          () {
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SubscriptionScreen(),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error navigating to subscription: $e')),
          );
        }
      },
    ];
  }

  List<String> otherTitleList = [
    "Referral Program",
    "Contact Us",
    "Privacy Policy",
    "Terms & Conditions",
    "Delete Account",
    "LogOut"
  ];
  List<String> otherSubtitleList = [
    "Share referral code and get bonus",
    "If you have any query you can contact us",
    "Language settings according to your region",
    "Set any type of notification message",
    "",
    "",
  ];
  List<VoidCallback> otherOnPressedList(BuildContext context) {
    return [
          () {
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReferralScreen(),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error navigating to referral: $e')),
          );
        }
      },
          () {
        try {
          _launchInBrowser("https://inzone.ai/about");
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error launching browser: $e')),
          );
        }
      },
          () {
        try {
          _launchInBrowser("https://inzone.ai/privacy-policy");
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error launching browser: $e')),
          );
        }
      },
          () {
        try {
          _launchInBrowser("https://inzone.ai/terms-conditions");
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error launching browser: $e')),
          );
        }
      },
          () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Account'),
              content: const Text(
                  'Are you sure you want to delete your account? This action cannot be undone.'),
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
                    Navigator.of(context).pop();
                    _deleteAccount(context);
                  },
                ),
              ],
            );
          },
        );
      },
          () {
        try {
          FirebaseAuth.instance.signOut().then((value) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const IntroductionScreen(),
              ),
            );
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CustomAppBar(
            isSettings: false,
            isImage: false,
            title: "Settings",
            userPoints: "100",
            onSearchTap: () {},
            onProfileTap: () {},
            onPointsTap: () {},
          ),
        ),
      ),
      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          category[0],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...List.generate(personalTitleList.length, (index) {
                        return Column(
                          children: [
                            SettingsTile(
                              title: personalTitleList[index],
                              subtitle: personalSubtitleList[index],
                              onPressed: personalOnPressedList(context)[index],
                            ),
                            if (index != personalTitleList.length - 1)
                              Divider(
                                color: Colors.grey.shade200,
                                thickness: 1,
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          category[1],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...List.generate(otherTitleList.length, (index) {
                        return Column(
                          children: [
                            SettingsTile(
                              title: otherTitleList[index],
                              subtitle: otherSubtitleList[index],
                              onPressed: otherOnPressedList(context)[index],
                              isLogout: index == otherTitleList.length - 1,
                            ),
                            if (index != otherTitleList.length - 1)
                              Divider(
                                color: Colors.grey.shade200,
                                thickness: 1,
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                )

                // Container(
                //   width: MediaQuery.of(context).size.width - 20,
                //   decoration: BoxDecoration(
                //       color: Colors.white, borderRadius: BorderRadius.circular(15)),
                //   child: Column(children: [
                //     // SettingsTile(
                //     //     title: "InZone Schedule",
                //     //     imagePath: "icons/settings/content_scheduling.svg",
                //     //     onPressed: () {
                //     //       // Navigator.of(context)
                //     //       //     .push(MaterialPageRoute(builder: (context) {
                //     //       //   return const InZoneSchedule();
                //     //       // }));
                //     //     }),

                //     SettingsTile(
                //         title: "Content Selection",
                //         // imagePath: "icons/settings/content_selection.svg",
                //         onPressed: () {
                //           Navigator.of(context)
                //               .push(MaterialPageRoute(builder: (context) {
                //             return const ContentSelectionSettingsScreen();
                //           }));
                //         }),
                //   ]),
                // ),

                // Container(
                //   width: MediaQuery.of(context).size.width - 20,
                //   decoration: BoxDecoration(
                //       color: Colors.white, borderRadius: BorderRadius.circular(30)),
                //   child: Column(children: [
                //     SettingsTile(
                //         title: "Privacy Policy",
                //         // imagePath: "icons/settings/privacy_policy.svg",
                //         onPressed: () {
                //           _launchInBrowser("https://www.inzone.ai/privacypolicy");
                //         }),
                //     SettingsTile(
                //         title: "Terms & Conditions",
                //         // imagePath: "icons/settings/terms_and_conditions.svg",
                //         onPressed: () {
                //           _launchInBrowser("https://www.inzone.ai/terms-condition");
                //         }),
                //     SettingsTile(
                //       title: "Delete Account",
                //       // imagePath: "icons/settings/delete_account.svg",
                //       onPressed: () {
                //         showDialog(
                //           context: context,
                //           builder: (BuildContext context) {
                //             return AlertDialog(
                //               title: const Text('Delete Account'),
                //               content: const Text(
                //                   'Are you sure you want to delete your account? This cannot be undone.'),
                //               actions: <Widget>[
                //                 TextButton(
                //                   child: const Text('Cancel'),
                //                   onPressed: () {
                //                     Navigator.of(context).pop();
                //                   },
                //                 ),
                //                 TextButton(
                //                   child: const Text('Delete'),
                //                   onPressed: () {
                //                     // Close the dialog, then call the delete account method
                //                     Navigator.of(context).pop();
                //                     _deleteAccount(context);
                //                   },
                //                 ),
                //               ],
                //             );
                //           },
                //         );
                //       },
                //     ),
                //     SettingsTile(
                //         title: "Logout",
                //         // imagePath: "icons/settings/logout.svg",
                //         onPressed: () {
                //           FirebaseAuth.instance.signOut().then((value) {
                //             Navigator.pushReplacement(
                //                 context,
                //                 MaterialPageRoute(
                //                     builder: (context) =>
                //                         const IntroductionScreen()));
                //           });
                //         }),
                //   ]),
                // ),
              ],
            ),
          )),
    );
  }
}
