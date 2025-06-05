import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:inzone/screen/settings/referral_tile.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

// Main Referral Screen
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen>
    with TickerProviderStateMixin {
  final MonetizationService _monetizationService = MonetizationService();
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();
  Contact? _selectedContact;
  String? _referralCode;
  String? _referralLink;
  List<Map<String, dynamic>> _referralHistory = [];
  bool _isLoading = true;
  final String _userName = 'User'; // Default name

  @override
  void initState() {
    super.initState();

    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    try {
      final generateResponse =
          await _monetizationService.generateReferralCode();
      if (generateResponse['success'] == true) {
        setState(() {
          _referralCode = generateResponse['data']['referral_code'];
          _referralLink = 'https://inzone.ai/referral?code=$_referralCode';
        });
      }

      final stats = await _monetizationService.getReferralStats();
      if (stats['success'] == true) {
        setState(() {
          _referralHistory = List<Map<String, dynamic>>.from(
              stats['data']['referral_history']);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Error loading referral data: $e',
        );
      }
    }
  }

  Future<void> _copyReferralLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    ToastService.showToast(
      context,
      backgroundColor: Theme.of(context).canvasColor,
      shadowColor: Colors.transparent,
      leading: const Icon(
        FeatherIcons.checkCircle,
        color: Colors.greenAccent,
      ),
      message: 'Referral link copied to clipboard',
    );
  }

  Future<void> _launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(url, forceSafariVC: false, forceWebView: false);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> sendSMS(String message, String number) async {
    try {
      if (Platform.isAndroid) {
        String uri = 'sms:$number?body=${Uri.encodeComponent(message)}';
        await launchUrl(Uri.parse(uri));
      } else if (Platform.isIOS) {
        String uri = 'sms:$number&body=${Uri.encodeComponent(message)}';
        await launchUrl(Uri.parse(uri));
      }
    } catch (e) {
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Error sending SMS: $e',
        );
      }
      rethrow;
    }
  }

  String _getMessageInfo(String link) {
    return "Hey! 👋\n\nJoin me on InZone using this link: $link";
  }

  Future<void> _addToReferralHistory(Contact contact) async {
    try {
      final newReferral = {
        'name': contact.fullName ?? 'Referred User',
        'photo_url': '', // You can add a default avatar if needed
        'date':
            DateTime.now().toString().split(' ')[0], // Only keep the date part
        'phone': contact.phoneNumbers?.first.toString() ?? '',
      };

      setState(() {
        _referralHistory.insert(0, newReferral);
      });

      // You might want to sync this with your backend
      // await _monetizationService.addReferral(newReferral);
    } catch (e) {
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Error adding to referral history: $e',
        );
      }
    }
  }

  Future<void> _handleContactSelection() async {
    try {
      final contact = await _contactPicker.selectContact();
      if (contact != null) {
        setState(() {
          _selectedContact = contact;
        });

        if (_selectedContact?.phoneNumbers?.isNotEmpty == true) {
          final phoneNumber = _selectedContact!.phoneNumbers![0].toString();
          final userUid = FirebaseAuth.instance.currentUser?.uid;
          if (userUid != null) {
            final referralLink =
                AppsFlyerService().generateReferralLink(userUid);
            final message = _getMessageInfo(referralLink);

            // Send SMS
            await sendSMS(message, phoneNumber);

            // Add to referral history
            await _addToReferralHistory(contact);

            if (mounted) {
              ToastService.showToast(
                context,
                backgroundColor: Theme.of(context).canvasColor,
                shadowColor: Colors.transparent,
                leading: const Icon(
                  FeatherIcons.checkCircle,
                  color: Colors.greenAccent,
                ),
                message: 'Referral message sent successfully!',
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Error selecting contact: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColorfulSafeArea(
      color: theme.canvasColor,
      child: Scaffold(
        backgroundColor: theme.canvasColor,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 80),
                    _buildTopBanner(theme),
                    const SizedBox(height: 20),
                    _buildReferralLinkSection(theme),
                    const SizedBox(height: 20),
                    Text(
                      "Your Referrals",
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _isLoading
                        ? _buildLoadingList()
                        : _buildReferralHistoryList(theme),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40), // Placeholder for balance
                    Text(
                      "Referral",
                      style: theme.textTheme.titleLarge,
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(FeatherIcons.x, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
          child: Button(
            text: "Sync Contacts",
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await _handleContactSelection();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 31),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Image.asset("icons/referral/Frame.png"),
          ),
          const SizedBox(height: 16),
          Text(
            'Give \$10, Get \$10',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 16),
          Text(
            'Refer friends to InZone, they get \$10 worth of InCash upon signing up. You get \$10 worth of InCash on us.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("icons/referral/facebook.png", width: 32, height: 32),
              const SizedBox(width: 14),
              Image.asset("icons/referral/twitter.png", width: 32, height: 32),
              const SizedBox(width: 14),
              Image.asset("icons/referral/instagram.png",
                  width: 32, height: 32),
              const SizedBox(width: 14),
              Image.asset("icons/referral/tiktok.png", width: 32, height: 32),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralLinkSection(ThemeData theme) {
    String? userUid = FirebaseAuth.instance.currentUser?.uid;
    String referralLink = userUid != null
        ? AppsFlyerService().generateReferralLink(userUid)
        : "Login to generate your referral link";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              referralLink,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _copyReferralLink(referralLink),
            icon: const Icon(Icons.copy),
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildReferralHistoryList(ThemeData theme) {
    if (_referralHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "No referrals yet.",
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _referralHistory.length,
      itemBuilder: (context, index) {
        final referral = _referralHistory[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ReferralTile(
            photoUrl: referral['photo_url'] ?? '',
            name: referral['name'] ?? 'Referred User',
            date: referral['date'] ?? 'N/A',
          ),
        );
      },
    );
  }
}
