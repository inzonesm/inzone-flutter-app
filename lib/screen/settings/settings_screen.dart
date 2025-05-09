import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings/settings_tile.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/router/app_router.dart';
import 'package:inzone/screen/auth/introduction_screen.dart';
import 'package:inzone/screen/settings/content_select_screen.dart';
import 'package:inzone/screen/settings/subscription_purchase.dart';
import 'package:inzone/screen/settings/referral_screen.dart';
// ignore: unused_import
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show LogLevel, Purchases;

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
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user is signed in'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await currentUser.delete();
      await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user == null);

      if (context.mounted) {
        context.go(Routes.login);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        try {
          await FirebaseAuth.instance.signOut();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please sign in again to delete your account'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.orange,
              ),
            );
            context.go(Routes.login);
          }
        } catch (signOutError) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error signing out: $signOutError'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message ?? e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _confirmDeleteAccountDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    return result ?? false; // 아무것도 선택 안 하고 닫으면 false
  }

  List<String> category = ["Personal", "Others"];

  List<String> personalTitleList = ["Content Selection", "Subscription"];
  List<String> personalSubtitleList = [
    "You can select different content",
    "Manage your InCash subscription"
  ];
  List<VoidCallback> personalOnPressedList(BuildContext context) {
    return [
      () {
        try {
          context.push(Routes.contentSelection);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error navigating to content selection: $e')),
          );
        }
      },
      () {
        try {
          context.push(Routes.subscription);
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
    "Invite friends and earn rewards",
    "Get help or ask us any questions",
    "Learn how we protect your personal information",
    "Understand the rules of using our services",
    "Permanently delete your account and data",
    "",
  ];
  List<VoidCallback> otherOnPressedList(BuildContext context) {
    return [
      () {
        try {
          context.push(Routes.referral);
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
      () async {
        final confirmed = await _confirmDeleteAccountDialog(context);
        if (confirmed) {
          await _deleteAccount(context);
        }
      },
      () {
        try {
          Purchases.logOut();
          FirebaseAuth.instance.signOut().then((value) {
            GoRouter.of(context).go(Routes.login);
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
    return ColorfulSafeArea(
      color: Theme.of(context).canvasColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CustomAppBar(
              isHome: true,
              isSettings: true,
              isImage: false,
              title: "Settings",
              userPoints: "100",
              onSearchTap: () {},
              onProfileTap: () {},
              onPointsTap: () {},
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
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
                    const SizedBox(height: 10),
                    ...List.generate(personalTitleList.length, (index) {
                      return Column(
                        children: [
                          SettingsTile(
                            title: personalTitleList[index],
                            subtitle: personalSubtitleList[index],
                            onPressed: personalOnPressedList(context)[index],
                          ),
                          if (index != personalTitleList.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Divider(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.05),
                                thickness: 1,
                              ),
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
                  color: Theme.of(context).cardColor,
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
                    const SizedBox(height: 10),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Divider(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.05),
                                thickness: 1,
                              ),
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
        ),
      ),
    );
  }
}
