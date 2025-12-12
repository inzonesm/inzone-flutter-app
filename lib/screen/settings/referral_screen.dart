import 'package:flutter/foundation.dart';
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

class _ReferralScreenState extends State<ReferralScreen> with TickerProviderStateMixin {
  // Debug mode flag
  final bool _isDebug = kDebugMode;
  final MonetizationService _monetizationService = MonetizationService();
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();
  List<Contact>? _selectedContacts;
  String? _referralCode;
  String? _referralLink;
  List<Map<String, dynamic>> _referralHistory = [];
  bool _isLoading = true;
  final String _userName = 'User'; // Default name

  // Deduplicate a list of referrals by normalized phone number
  List<Map<String, dynamic>> _deduplicateReferrals(List<Map<String, dynamic>> list) {
    final seenPhones = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final r in list) {
      String phone = (r['phone'] ?? '').replaceAll(RegExp(r'\D'), '');
      if (phone.isNotEmpty && !seenPhones.contains(phone)) {
        seenPhones.add(phone);
        deduped.add(r);
      }
    }
    // Debug print all phone numbers after deduplication
    debugPrint('Referral history after deduplication:');
    for (final r in deduped) {
      debugPrint('Name: \'${r['name']}\', Phone: \'${r['phone']}\'');
    }
    return deduped;
  }

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
        final rawList = List<Map<String, dynamic>>.from(stats['data']['referral_history']);
        setState(() {
          _referralHistory = _deduplicateReferrals(rawList);
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
    if (_isDebug) {
      // Simulate SMS sending in debug mode
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('DEBUG: Simulate SMS'),
            content: Text('Would send to: $number\n\nMessage:\n$message'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.checkCircle,
            color: Colors.greenAccent,
          ),
          message: 'DEBUG: Simulated referral message!',
        );
      }
      return;
    }
    // Real SMS sending for production
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
      String phone = contact.phoneNumbers?.first.toString() ?? '';
      // Normalize phone number: remove all non-digit characters
      phone = phone.replaceAll(RegExp(r'\D'), '');
      if (phone.isEmpty) {
        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.xCircle,
              color: Colors.redAccent,
            ),
            message: 'Contact has no valid phone number.',
          );
        }
        return;
      }
      // Prevent duplicate by normalized phone number
      final alreadyReferred = _referralHistory.any((r) => (r['phone'] ?? '').replaceAll(RegExp(r'\D'), '') == phone);
      if (alreadyReferred) {
        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.xCircle,
              color: Colors.redAccent,
            ),
            message: 'This contact has already been referred.',
          );
        }
        return;
      }

      final newReferral = {
        'name': contact.fullName ?? 'Referred User',
        'photo_url': '',
        'date': DateTime.now().toUtc().toString().split(' ')[0],
        'phone': phone,
      };

      setState(() {
        _referralHistory.insert(0, newReferral);
        _referralHistory = _deduplicateReferrals(_referralHistory);
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
      // Use pickContacts for multiple selection if available, else fallback to single
      List<Contact>? contacts;
      try {
        contacts = await _contactPicker.selectContacts();
      } catch (_) {
        // If selectContacts is not available, fallback to single
        final single = await _contactPicker.selectContact();
        if (single != null) {
          contacts = [single];
        }
      }
      if (contacts != null && contacts.isNotEmpty) {
        setState(() {
          _selectedContacts = contacts;
        });
        final userUid = FirebaseAuth.instance.currentUser?.uid;
        if (userUid != null) {
          final referralLink = AppsFlyerService().generateReferralLink(userUid);
          final message = _getMessageInfo(referralLink);
          int sentCount = 0;
          for (final contact in contacts) {
            if (contact.phoneNumbers?.isNotEmpty == true) {
              final phoneNumber = contact.phoneNumbers![0].toString();
              await sendSMS(message, phoneNumber);
              await _addToReferralHistory(contact);
              sentCount++;
            }
          }
          if (mounted) {
            ToastService.showToast(
              context,
              backgroundColor: Theme.of(context).canvasColor,
              shadowColor: Colors.transparent,
              leading: const Icon(
                FeatherIcons.checkCircle,
                color: Colors.greenAccent,
              ),
              message: 'Referral message sent to $sentCount contact(s)!',
            );
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
          message: 'Error selecting contacts: $e',
        );
      }
    }
  }


  // --- Helper widgets ---

  Widget _buildReferralLinkSection(ThemeData theme) {
    return _referralLink == null
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _referralLink!,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    if (_referralLink != null) {
                      _copyReferralLink(_referralLink!);
                    }
                  },
                ),
              ],
            ),
          );
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debugBanner = _isDebug
        ? Container(
            width: double.infinity,
            color: Colors.orange,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'DEBUG MODE: SMS sending is simulated',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          )
        : const SizedBox.shrink();

    return ColorfulSafeArea(
      color: theme.canvasColor,
      child: Scaffold(
        backgroundColor: theme.canvasColor,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 80),
                    debugBanner,
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


  // (Removed broken _buildTopBanner)

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
