import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'dart:io' show Platform;
import 'package:go_router/go_router.dart';

import 'package:inzone/components/settings/topic_selector_widget.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:toasty_box/toast_service.dart'; // Import this to detect the platform

class SignUpScreens extends StatefulWidget {
  const SignUpScreens({super.key});

  @override
  State<SignUpScreens> createState() => _SignUpScreensState();
}

class _SignUpScreensState extends State<SignUpScreens> {
  String licenseAgreement = '''
1. Acknowledgement:
This End User License Agreement (EULA) is a binding agreement between you (the "End-User") and InZone, INC. ("We" or "Us"). This EULA governs your use of our Licensed Application. By downloading, installing, or using the Licensed Application, you agree to be bound by the terms of this EULA. This agreement is in place between you and us, not with Apple. We are solely responsible for the Licensed Application and its content, not Apple. This EULA adheres to the Apple Media Services Terms and Conditions.

2. Scope of License:
We grant you a non-transferable license to use the Licensed Application on Apple-branded products owned or controlled by you, as per the Usage Rules in the Apple Media Services Terms and Conditions. This includes access and use by other accounts via Family Sharing or volume purchasing.

3. Maintenance and Support:
We are solely responsible for providing maintenance and support services for the Licensed Application, as outlined in this EULA or as required by law. Apple has no obligation to provide maintenance or support services for the Licensed Application.

4. Warranty:
We are solely responsible for any product warranties, to the extent not effectively disclaimed by law. If the Licensed Application fails to conform to any applicable warranty, you may notify Apple, and Apple will refund the purchase price. To the maximum extent permitted by law, Apple will have no other warranty obligations.

5. Product Claims:
We, not Apple, are responsible for addressing any claims you or any third party may have concerning the Licensed Application, including product liability claims, legal or regulatory non-conformance claims, and claims under consumer protection, privacy, or similar legislation.

6. Intellectual Property Rights:
In the event of a third-party claim that the Licensed Application infringes intellectual property rights, we, not Apple, will be solely responsible for the investigation, defense, settlement, and discharge of any such claim.

7. Legal Compliance:
You represent and warrant that you are not located in a U.S. Government embargoed country or designated as a "terrorist supporting" country and that you are not listed on any U.S. Government list of prohibited or restricted parties.

8. Developer Name and Address:
For any questions, complaints, or claims concerning the Licensed Application, please contact InZone, INC. at 6505 59th Ave Riverdale, MD, +1 (240) 681-4298, contact@inzone.ai.

9. Third-Party Terms of Agreement:
You must comply with applicable third-party terms when using the Licensed Application. For example, if the Licensed Application is a VoIP app, you must not violate your wireless data service agreement.

10. Third Party Beneficiary:
Apple and Apple's subsidiaries are third-party beneficiaries of this EULA. Upon your acceptance of the terms and conditions, Apple will have the right to enforce this EULA against you as a third-party beneficiary.

11. Content and Conduct:
We are dedicated to fostering healthier relationships with social media. There is zero tolerance for objectionable content or abusive behavior on the platform. Users are encouraged to report any such content for immediate review and action.

12. Protecting Young Users:
Information from users below 13 years of age is used solely for enhancing the InZone Parents Hub, making social media healthier for them by giving appropriate tools to their parents or guardians. We are committed to safeguarding the online experiences of our youngest users with the utmost care and in compliance with applicable laws.

By using the Licensed Application, you agree to abide by these terms and conditions. Your acceptance of this EULA constitutes your agreement to its terms.
''';

  final PageController _controller = PageController();

  int _currentPage = 0;
  int tempGender = 4;
  int tempAge = 0;
  String? name;
  String? email;
  int? age;
  List<String>? interests;
  String? username;
  String? password;

  void _dismissLoadingDialog() {
    if (mounted && Navigator.of(context).canPop()) {
      context.pop();
    }
  }

  // Function to navigate between pages
  void _navigateToPage(int page) async {
    if (_currentPage == 1) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Creating account..."),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Simulate a minimum 2-second loading time, and then proceed with tasks
      await Future.delayed(const Duration(seconds: 2));

      // After 2 seconds, perform the actual tasks (FirebaseAuth + API request)
      try {
        // Firebase Authentication (replace with actual email and password fields)

        if (email != null && password != null && username != null) {
          if (email!.isNotEmpty &&
              password!.isNotEmpty &&
              username!.isNotEmpty) {
            final credential =
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email!,
              password: password!,
            );
            if (interests != null) {
              if (interests!.length < 2) {
                interests = [];
              }
            } else {
              interests = [];
            }

            FirebaseAuth.instance.currentUser!.updateDisplayName(username!);
            await InZoneDatabase.createUserProfile(
              name: username!,
              email: email!,
              age: age ?? 101,
              gender: "male",
              userUid: credential.user!.uid,
              userInterests: interests!,
            );

            _dismissLoadingDialog();

            // Navigate to home
            if (mounted) {
              context.go(Routes.home);
            }
          }
        } else {
          _dismissLoadingDialog();

          // Navigate back to introduction screen
          if (!mounted) return;
          context.go(Routes.login);

          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.xCircle,
              color: Colors.redAccent,
            ),
            message: "Error: Please fill all the fields!",
          );
        }
      } on FirebaseAuthException catch (e) {
        _dismissLoadingDialog();
        if (!mounted) return;
        // Show an error message if something went wrong
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: "Error: ${e.message}",
        );
      } catch (e) {
        _dismissLoadingDialog();
        if (!mounted) return;

        // Show a general error message
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: "An unexpected error occurred. Please try again.",
        );
      }
    } else {
      // Handle non-loading screen navigation logic
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          _currentPage == 0 ? 'Sign Up' : 'Content Selection',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildDetailInputPage(),
                  _buildContentSelectionPage(),
                ],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailInputPage() {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text("E-mail",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(
                height: 10,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(
                            0, 0), // Changes the position of the shadow
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Enter E-mail',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      email = value;
                    },
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text("Username",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(
                height: 10,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(
                            0, 0), // Changes the position of the shadow
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Enter Username',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      username = value;
                    },
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text("Password",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(
                height: 10,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(
                            0, 0), // Changes the position of the shadow
                      ),
                    ],
                  ),
                  child: TextField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter Password',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      password = value;
                    },
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text("Age (optional)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(
                height: 10,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: 48,
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(
                            0, 0), // Changes the position of the shadow
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    itemCount: 200,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (BuildContext context, int index) {
                      return Center(
                          child: Row(
                        children: [
                          tempAge == index + 1
                              ? Container(
                                  margin:
                                      const EdgeInsets.only(left: 5, right: 5),
                                  width: 30.0,
                                  height: 30.0,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue,
                                    boxShadow: [
                                      BoxShadow(
                                        offset: Offset(0, 2),
                                        blurRadius: 0,
                                        spreadRadius: 0,
                                        color: Color(0xFF1573BE),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    age = index + 1;
                                    setState(() {
                                      tempAge = index + 1;
                                    });
                                  },
                                  child: Text("   ${index + 1}   ")),
                        ],
                      ));
                    },
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              // const Text("Gender (optional)",
              //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              // Flexible(
              //   child: SingleChildScrollView(
              //     scrollDirection: Axis.horizontal,
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //       crossAxisAlignment: CrossAxisAlignment.center,
              //       children: [
              //         GestureDetector(
              //             onTap: () {
              //               setState(() {
              //                 tempGender = 0;
              //               });
              //             },
              //             child: genderChoose(Icons.male, "Male", 0)),
              //         GestureDetector(
              //             onTap: () {
              //               setState(() {
              //                 tempGender = 1;
              //               });
              //             },
              //             child: genderChoose(Icons.male, "Female", 1)),
              //         GestureDetector(
              //             onTap: () {
              //               setState(() {
              //                 tempGender = 2;
              //               });
              //             },
              //             child: genderChoose(Icons.male, "Other", 2)),
              //       ],
              //     ),
              //   ),
              // ),
              // const SizedBox(
              //   height: 10,
              // ),

              Flexible(
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 8.0, right: 8.0, top: 20),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 10,
                      ),
                      Flexible(
                        flex: 1,
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text("Close"))
                                    ],
                                    content: SingleChildScrollView(
                                      child: Text(licenseAgreement),
                                    ));
                              },
                            );
                          },
                          child: const Text(
                              "By continuing, you are agreeing to the Terms of Use including the arbitration clause and acknowledging the Privacy Policy. \nTap to learn more.",
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.grey)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentSelectionPage() {
    void addToList(String topic) {
      interests ??= [];
      interests!.add(topic);
    }

    List topicList = [
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
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              const Center(
                  child: Text(
                "Select your favorite categories (Optional)",
                style: TextStyle(color: Colors.blue),
              )),
              Padding(
                padding: const EdgeInsets.only(bottom: 80.0),
                child: Wrap(
                  children: List.generate(
                    topicList.length,
                    (index) {
                      String currentTopic = topicList[index];
                      return TopicSelectorWidget(
                          topic: currentTopic, callBack: addToList);
                    },
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  // Navigation buttons for page switching
  Widget _buildNavigationButtons() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _currentPage == 0 ? null : () => _navigateToPage(0),
              child: Icon(
                Platform.isIOS
                    ? Icons.arrow_back_ios
                    : Icons.arrow_back, // iOS or Android specific icon
              ),
            ),
            ElevatedButton(
              onPressed: () => _navigateToPage(1),
              child: AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 300), // Set animation duration
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Define the animation type
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  _currentPage == 1
                      ? Icons.check
                      : (Platform.isIOS
                          ? Icons.arrow_forward_ios
                          : Icons.arrow_forward), // Platform-specific arrow
                  key: ValueKey<int>(
                      _currentPage), // Ensure a unique key for different icons
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget genderChoose(IconData iconData, String genderName, int index) {
    int gender = tempGender;
    return SizedBox(
      height: 60,
      width: MediaQuery.of(context).size.width / 3.4,
      child: Container(
        height: 48,
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: gender != index
                  ? Colors.grey.withOpacity(0.5)
                  : Theme.of(context).colorScheme.primary,
              spreadRadius: 2,
              blurRadius: 1,
              offset: const Offset(0, 2), // Changes the position of the shadow
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconData,
                color: gender != index
                    ? Colors.black54
                    : Theme.of(context).colorScheme.primary,
              ),
              Text(
                genderName,
                style: TextStyle(
                  color: gender != index
                      ? Colors.black
                      : Theme.of(context).colorScheme.primary,
                  fontSize: 16.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
