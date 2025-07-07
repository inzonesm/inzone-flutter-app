import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/auth/auth_work.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/screen/auth/profile_screen.dart';
import 'package:inzone/screen/auth/signin_login_screen.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inzone/screen/common/home_screen.dart';

class IntroductionScreen extends StatefulWidget {
  const IntroductionScreen({super.key});

  @override
  State<IntroductionScreen> createState() => _IntroductionScreenState();
}

class _IntroductionScreenState extends State<IntroductionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    _showLoadingDialog();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _dismissLoadingDialog();
      return;
    }

    final docRef =
        FirebaseFirestore.instance.collection('humanUsers').doc(user.uid);
    var doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'email': user.email ?? '',
        'createdAt': null, // 아직 프로필 설정 안 했으면 createdAt 비워둬야 구분 가능
      });
      doc = await docRef.get();
    }

    bool isProfileCompleted = doc.data()?['createdAt'] != null;

    // Make sure to dismiss the loading dialog before navigation
    _dismissLoadingDialog();

    // Use a small delay to ensure the dialog is fully dismissed before navigation
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      if (isProfileCompleted) {
        context.go(Routes.home);
      } else {
        context.go(Routes.profileWithEmail(user.email ?? ""));
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  void _dismissLoadingDialog() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleAppleLogin() async {
    _showLoadingDialog();

    try {
      final result = await AuthWork().signinWithApple();
      if (result == null) {
        // User cancelled or sign-in failed
        _dismissLoadingDialog();
        return;
      }
      await _checkLoginStatus();
    } catch (e) {
      debugPrint("Apple Sign-In Error: $e");
      _dismissLoadingDialog();
    }
  }

  Future<void> _handleGoogleLogin() async {
    _showLoadingDialog();

    try {
      final result = await AuthWork().signinWithGoogle();
      if (result == null) {
        // User cancelled or sign-in failed
        _dismissLoadingDialog();
        return;
      }
      await _checkLoginStatus();
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      _dismissLoadingDialog();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      body: ColorfulSafeArea(
        bottom: false,
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.25,
              width: MediaQuery.of(context).size.height * 0.25,
              child: Hero(
                tag: 'logo',
                child: Image.asset(
                  'assets/auth/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  appleLoginButton(context, _handleAppleLogin),
                  const SizedBox(height: 12),
                  googleLoginButton(context, _handleGoogleLogin),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const SignInLoginScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      );
                    },
                    child: Text(
                      'or use e-mail',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                            fontSize: 14,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 8),
                        children: [
                          const TextSpan(
                              text: "By continuing, you are agreeing to our "),
                          TextSpan(
                            text: "Terms of Service",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 8,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.mediumGrey,
                                    ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                try {
                                  _launchInBrowser(
                                      "https://inzone.ai/terms-conditions");
                                } catch (e) {
                                  ToastService.showToast(
                                    context,
                                    backgroundColor:
                                        Theme.of(context).canvasColor,
                                    shadowColor: Colors.transparent,
                                    leading: const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                    ),
                                    message: 'Error launching browser: $e',
                                  );
                                }
                              },
                          ),
                          const TextSpan(text: " and "),
                          TextSpan(
                            text: "Privacy Policy",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 8,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.mediumGrey,
                                    ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                try {
                                  _launchInBrowser(
                                      "https://inzone.ai/privacy-policy");
                                } catch (e) {
                                  ToastService.showToast(
                                    context,
                                    backgroundColor:
                                        Theme.of(context).canvasColor,
                                    shadowColor: Colors.transparent,
                                    leading: const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                    ),
                                    message: 'Error launching browser: $e',
                                  );
                                }
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget appleLoginButton(BuildContext context, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: !isDark ? Colors.black : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.asset(
          !isDark ? 'assets/auth/apple_white.png' : 'assets/auth/apple.png',
          height: 30,
        ),
        label: Text(
          'Sign in with Apple',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: !isDark ? Colors.white : Colors.black,
                fontSize: 18,
              ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          side: BorderSide.none,
        ),
      ),
    );
  }

  Widget googleLoginButton(BuildContext context, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: isDark ? Colors.black : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.asset('assets/auth/google.png', height: 40),
        label: Text(
          'Sign in with Google',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
              ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          side: BorderSide.none,
        ),
      ),
    );
  }
}
/*
    String licenseAgreement = '''
Introduction
Welcome to InZone operated by InZone Inc. ('we', 'our', 'us'). These Terms and Conditions ('Terms') govern your access to and use of the website located at 'inzone.ai' and the InZone application (collectively the 'Platform'). By using the Platform, you agree to be bound by these Terms. Please read them carefully.

Scope of Services
InZone provides an interactive social media platform that incorporates AI-powered chatbots, 2D/3D avatars, user-generated content, and a Parent Hub for monitoring children's activities. These services are aimed at promoting healthier content consumption and immersive experiences for users.

Account Creation and Usage
To use our services, you must create an account. During account registration, you agree to provide accurate and up-to-date information. InZone reserves the right to terminate accounts that violate these Terms or contain fraudulent information.

AI Chatbot Interactions
Our Platform includes AI-powered chatbots that allow users to engage with AI-generated content in real-time. These bots simulate conversations with fictional or real-world characters. While they enhance user interaction, the following rules apply: - Purpose: AI chatbots are intended for entertainment and educational use only. Responses from these bots are automated and may not be accurate or appropriate. - Limitation of Liability: InZone is not responsible for any loss, damage, or inconvenience caused by the use of AI chatbot services. AI-generated responses are based on machine learning algorithms and do not undergo human verification. Users should refrain from relying on AI chatbot interactions for personal, legal, or financial decisions. - User Discretion: By engaging with the AI chatbot services, users agree that the content generated by these bots is for general use only and may not be suitable for all contexts. Users should use discretion in sharing sensitive or personal information with AI chatbots.

Intellectual Property
The Platform, including but not limited to AI algorithms, avatars, code, and design elements, is the intellectual property of InZone or its licensors. Unauthorized reproduction, distribution, or use of this content is strictly prohibited.

Parental Monitoring
For users under 13, InZone provides a Parent Hub that enables parents to monitor their child's activity on the Platform. Although we provide tools to encourage a safe and healthy environment, parents are ultimately responsible for the actions and safety of their children while using InZone.

Sharing of User-Generated Content
Users may share, post, and interact with content created by other users or AI services. All user-generated content must comply with community standards. InZone reserves the right to remove content that violates these standards or is deemed harmful or inappropriate.

Limitation of Liability
In no event shall InZone, its officers, employees, or agents be liable for any indirect, incidental, special, or consequential damages resulting from the use of or inability to use the Platform, including AI chatbot interactions or user-generated content. Users assume all responsibility for their engagement with the Platform.

Dispute Resolution
Any disputes arising under these Terms shall be resolved through binding arbitration in accordance with the rules of [arbitration organization] and by the laws of [State/Country]. You agree to waive your right to participate in any class action lawsuits.

Changes to Terms
InZone reserves the right to update or modify these Terms at any time. Notice of material changes will be provided via email or by posting the updated Terms on the Platform. Your continued use of the Platform after such modifications will constitute your acknowledgment of the modified Terms.

Contact Information
For questions or concerns regarding these Terms, contact: InZone Inc., Riverdale, Maryland 20737 Email: contact@inzone.ai Phone: 240-681-4298

''';

    String privacyPolicy = '''
        Introduction
InZone Inc. ('we', 'our', 'us') is committed to protecting your privacy. This Privacy Policy outlines how we collect, use, and protect personal information obtained through our website 'inzone.ai' and the InZone application (collectively the 'Platform'). By using the Platform, you consent to the data practices outlined below.

Information We Collect
We collect two types of information: personally identifiable information and non-personal data. - Personal Information: Includes first and last name, email address, phone number, and your child's InZone account identifier. We also collect billing and payment information for transactions. - Non-Personal Information: We may collect demographic information, including age, as well as browser details and anonymized data for statistical purposes.

AI Chatbot Data
InZone's AI chatbot services collect conversation data to enhance user experience and improve chatbot performance. Users should be aware that while chatbot conversations are stored for improvement purposes, they should avoid sharing personal or sensitive information during these interactions. - Use of Chatbot Data: Conversation data may be analyzed internally to enhance AI performance. We do not sell or share this data with third parties. - Liability Disclaimer: Users acknowledge that chatbot interactions are for entertainment or educational purposes and InZone is not liable for any advice or information provided by AI bots. Users should not rely on chatbot responses for any critical decisions.

Use of Collected Information
We use the personal information you provide for: - Delivering the services you request - Processing transactions - Communicating with you about updates, offers, or changes to the Platform - Analyzing trends and improving Platform functionality. We do not sell or rent your personal information to third parties.

Children's Privacy
InZone complies with the Children's Online Privacy Protection Act (COPPA). We collect personal information from children under 13 only for the purpose of providing parental monitoring services through the Parent Hub. Parental consent is required for any data collection involving children. - Parental Control: Parents can control their child's interactions on InZone through the Parent Hub. Any collected data is for monitoring purposes and is not shared externally.

Data Security
We implement industry-standard security measures, including HTTPS and database isolation, to protect your personal information. However, we cannot guarantee complete security due to the inherent risks of data transmission over the Internet.

Right to Deletion
You have the right to request the deletion of your personal data. We will comply with all deletion requests subject to legal exceptions such as complying with regulatory obligations or preventing fraudulent activity.

Retention of Data
We retain personal information only as long as necessary to fulfill the purposes for which it was collected or to comply with legal obligations. Data related to AI chatbots is anonymized and used to improve functionality.

Changes to this Policy
InZone may update this Privacy Policy periodically. We will notify you of significant changes through email or by posting a notice on the Platform.

Contact Information
For any questions or concerns regarding this Privacy Policy, please contact us: InZone Inc., Riverdale, Maryland 20737 Email: contact@inzone.ai Phone: 240-681-4298
        ''';
*/
