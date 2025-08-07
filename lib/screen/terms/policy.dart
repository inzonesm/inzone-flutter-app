import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'contact@inzone.ai',
      queryParameters: {
        'subject': 'Privacy Policy Inquiry',
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      // Handle case where email client can't be launched
      debugPrint('Could not launch $emailUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Content with padding for the header
            Padding(
              padding: const EdgeInsets.only(
                  top: 80.0, left: 16.0, right: 16.0, bottom: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // 1. Introduction
                    Text(
                      "1. Introduction",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "Welcome to InZone's Privacy Policy. This policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and website.",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Information We Collect
                    Text(
                      "2. Information We Collect",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "We may collect information about you in a variety of ways. The information we may collect includes:",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint(context,
                              "Personal Data: Personally identifiable information, such as your name, email address, and date of birth, that you voluntarily give to us when you register with the application."),
                          _buildBulletPoint(context,
                              "Derivative Data: Information our servers automatically collect when you access the application, such as your IP address, browser type, operating system, access times, and the pages you have viewed."),
                          _buildBulletPoint(context,
                              "Financial Data: Financial information, such as data related to your payment method, that we may collect when you purchase a subscription."),
                          _buildBulletPoint(context,
                              "Data from Social Networks: User information from social networking sites, including Facebook, Google, and others, if you connect your account to these services."),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Use of Your Information
                    Text(
                      "3. Use of Your Information",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "We may use the information we collect about you for various purposes, including:",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint(
                              context, "To create and manage your account"),
                          _buildBulletPoint(
                              context, "To provide and maintain our services"),
                          _buildBulletPoint(context, "To process transactions"),
                          _buildBulletPoint(
                              context, "To send administrative information"),
                          _buildBulletPoint(
                              context, "To personalize your experience"),
                          _buildBulletPoint(context, "To protect our services"),
                          _buildBulletPoint(context,
                              "To respond to legal requests and comply with regulations"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Disclosure of Your Information
                    Text(
                      "4. Disclosure of Your Information",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "We may share information we have collected about you in certain situations. Your information may be disclosed as follows:",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint(context,
                              "By Law or to Protect Rights: If required by law or to protect our rights and those of our users."),
                          _buildBulletPoint(context,
                              "Third-Party Service Providers: We may share your information with third parties that perform services for us or on our behalf."),
                          _buildBulletPoint(context,
                              "Marketing Communications: With your consent, we may share your information with third parties for marketing purposes."),
                          _buildBulletPoint(context,
                              "Interactions with Other Users: If you interact with other users, they may see certain aspects of your profile."),
                          _buildBulletPoint(context,
                              "Business Transfers: If we are involved in a merger, acquisition, or sale of assets."),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Third-Party Websites
                    Text(
                      "5. Third-Party Websites",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "The application may contain links to third-party websites that are not affiliated with us. We are not responsible for the privacy practices of these websites.",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 6. Security of Your Information
                    Text(
                      "6. Security of Your Information",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "We use administrative, technical, and physical security measures to protect your personal information. However, no security system is impenetrable, and we cannot guarantee the security of our database.",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 7. COPPA Compliance
                    Text(
                      "7. COPPA Compliance",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "We comply with the requirements of the Children's Online Privacy Protection Act (COPPA). We do not collect personal information from children under 13 without appropriate parental consent.",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 8. Options Regarding Your Information
                    Text(
                      "8. Options Regarding Your Information",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "You may at any time review, change, or delete the information in your account. You may also opt out of marketing communications.",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 9. Changes to This Privacy Policy
                    Text(
                      "9. Changes to This Privacy Policy",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "We may update this policy from time to time. We will notify you of any changes by posting the new policy on this page.",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 10. Contact Us
                    Text(
                      "10. Contact Us",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "If you have questions about this Privacy Policy, \n please contact us at: ",
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _launchEmail,
                      child: Text(
                        "Email: contact@inzone.ai",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 16,
                          height: 1.5,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Header with title and close button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title on left
                    Text(
                      "Privacy Policy",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),

                    // X button on right
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          FeatherIcons.x,
                          size: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.blue.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "• ",
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
