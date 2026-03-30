import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:inzone/screen/settings/referral_tile.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:toasty_box/toast_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

const _contactNameFallback = 'Unknown Contact';

// Main Referral Screen
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final MonetizationService _monetizationService = MonetizationService();
  static const MethodChannel _smsTrackingChannel = MethodChannel('inzone/sms_tracking');
  bool _isLoading = true;
  String? _referralLink;
  List<Map<String, dynamic>> _referralHistory = [];
  
  // ============ OLD LOGIC - COMMENTED OUT ============
  // For sequential SMS sending
  // bool _isSendingReferrals = false;
  // int _currentContactIndex = 0;
  // List<Contact>? _pendingContacts;
  // String? _pendingMessage;
  // ============ END OLD LOGIC ============

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReferralHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadReferralHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(user.uid)
            .collection('referralHistory')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();
        
        setState(() {
          _referralHistory = snapshot.docs.map((doc) => doc.data()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading referral history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // ============ OLD LOGIC - COMMENTED OUT ============
    // When user returns to the app after sending SMS
    // if (state == AppLifecycleState.resumed && _isSendingReferrals && _pendingContacts != null) {
    //   Future.delayed(const Duration(milliseconds: 300), () {
    //     if (mounted && _isSendingReferrals) {
    //       _currentContactIndex++;
    //       _sendToNextContact();
    //     }
    //   });
    // }
    // ============ END OLD LOGIC ============
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    const SizedBox(width: 40),
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
              await _syncContactsAndShareReferral();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _syncContactsAndShareReferral() async {
    if (Platform.isIOS) {
      await _syncContactsAndShareReferralIOS();
      return;
    }

    final permissionStatus = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    if (permissionStatus != PermissionStatus.granted) {
      if (!mounted) return;
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
        message: 'Contacts permission denied.',
      );
      return;
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final contactsByPhone = <String, Contact>{};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = _normalizePhone(phone.number);
        if (normalized.isNotEmpty && !contactsByPhone.containsKey(normalized)) {
          contactsByPhone[normalized] = contact;
        }
      }
    }

    if (Platform.isAndroid) {
      await permission_handler.Permission.sms.request();
    }

    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return;

    final referralLink = AppsFlyerService().generateReferralLink(userUid);
    final message = _getMessageInfo(referralLink);

    try {
      final shareResult = await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Join me on InZone!',
        ),
      );

      final shareStatus = shareResult.status.toString().split('.').last;

      if (shareStatus == 'success') {
        await _trackAndroidSmsRecipients(
          referralLink: referralLink,
          shareStatus: shareStatus,
          contactsByPhone: contactsByPhone,
        );
      }

      await _loadReferralHistory();

      if (mounted) {
        if (shareStatus == 'success') {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.checkCircle,
              color: Colors.greenAccent,
            ),
            message: '✅ Referral share completed.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error sharing referral: $e');
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Error sharing referral: $e',
        );
      }
    }
  }

  Future<void> _syncContactsAndShareReferralIOS() async {
    final permissionStatus = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    if (permissionStatus != PermissionStatus.granted) {
      if (!mounted) return;
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
        message: 'Contacts permission denied.',
      );
      return;
    }

    final allContacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final contactList = allContacts.where((c) => c.phones.isNotEmpty).toList();

    if (contactList.isEmpty) return;

    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return;

    final referralLink = AppsFlyerService().generateReferralLink(userUid);
    final message = _getMessageInfo(referralLink);

    try {
      final shareResult = await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Join me on InZone!',
        ),
      );

      final shareStatus = shareResult.status.toString().split('.').last;

      if (shareStatus == 'success') {
        await _monetizationService.addReferralHistory({
          'name': 'Native Share',
          'phone': 'N/A',
          'date': DateTime.now().toIso8601String(),
          'method': 'share_plus',
          'shareStatus': shareStatus,
          'syncedContactsCount': contactList.length,
          'source': 'contact_sync_native_share_ios',
        });
      }

      await _loadReferralHistory();

      if (mounted && shareStatus == 'success') {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.checkCircle,
            color: Colors.greenAccent,
          ),
          message: '✅ Referral share completed.',
        );
      }
    } catch (e) {
      debugPrint('Error sharing referral with synced contacts on iOS: $e');
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Error sharing referral: $e',
        );
      }
    }
  }

  Future<bool> _trackAndroidSmsRecipients({
    required String referralLink,
    required String shareStatus,
    required Map<String, Contact> contactsByPhone,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    final smsPermission = await permission_handler.Permission.sms.status;
    if (!smsPermission.isGranted) {
      return false;
    }

    try {
      final result = await _smsTrackingChannel.invokeMethod<List<dynamic>>(
        'getRecentReferralSmsRecipients',
        {
          'referralLink': referralLink,
          'lookbackMinutes': 20,
        },
      );

      if (result == null || result.isEmpty) {
        return false;
      }

      var trackedCount = 0;
      for (final item in result) {
        if (item is! Map) continue;
        final phoneRaw = (item['address'] ?? '').toString();
        final normalized = _normalizePhone(phoneRaw);
        if (normalized.isEmpty) continue;

        final alreadyTracked = await _isPhoneAlreadyTracked(phoneRaw);
        if (alreadyTracked) {
          continue;
        }

        final matchedContact = contactsByPhone[normalized];
        final displayName = (matchedContact?.displayName ?? '').trim().isEmpty
            ? _contactNameFallback
            : matchedContact!.displayName!.trim();

        await _monetizationService.addReferralHistory({
          'name': displayName,
          'phone': phoneRaw,
          'date': DateTime.now().toIso8601String(),
          'method': 'share_plus',
          'shareStatus': shareStatus,
          'source': 'android_sent_sms_tracking',
        });
        trackedCount++;
      }

      return trackedCount > 0;
    } catch (e) {
      debugPrint('Error tracking Android SMS recipients: $e');
      return false;
    }
  }

  Future<bool> _isPhoneAlreadyTracked(String phone) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final existing = await FirebaseFirestore.instance
        .collection('humanUsers')
        .doc(user.uid)
        .collection('referralHistory')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    return existing.docs.isNotEmpty;
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // ============ CONTACT PICKER LOGIC - COMMENTED OUT ============
  // Future<Contact?> _showContactPickerForNativeShare(
  //   List<Contact> contacts,
  // ) async {
  //   return showModalBottomSheet<Contact>(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Theme.of(context).cardColor,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (sheetContext) {
  //       final theme = Theme.of(sheetContext);
  //       return SafeArea(
  //         child: SizedBox(
  //           height: MediaQuery.of(sheetContext).size.height * 0.75,
  //           child: Column(
  //             children: [
  //               const SizedBox(height: 10),
  //               Container(
  //                 width: 42,
  //                 height: 4,
  //                 decoration: BoxDecoration(
  //                   color: theme.dividerColor,
  //                   borderRadius: BorderRadius.circular(20),
  //                 ),
  //               ),
  //               const SizedBox(height: 12),
  //               Text(
  //                 'Choose a contact',
  //                 style: theme.textTheme.titleMedium?.copyWith(
  //                   fontWeight: FontWeight.w700,
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //               Expanded(
  //                 child: ListView.separated(
  //                   padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
  //                   itemCount: contacts.length,
  //                   separatorBuilder: (_, __) => const SizedBox(height: 8),
  //                   itemBuilder: (_, index) {
  //                     final contact = contacts[index];
  //                     final displayName =
  //                         (contact.displayName ?? '').trim().isEmpty
  //                             ? _contactNameFallback
  //                             : contact.displayName!.trim();
  //                     final phone = contact.phones.isNotEmpty
  //                         ? contact.phones.first.number
  //                         : '';
  //
  //                     return ListTile(
  //                       shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(14),
  //                         side: BorderSide(
  //                           color: theme.dividerColor.withValues(alpha: 0.35),
  //                         ),
  //                       ),
  //                       tileColor: theme.canvasColor,
  //                       title: Text(
  //                         displayName,
  //                         maxLines: 1,
  //                         overflow: TextOverflow.ellipsis,
  //                         style: theme.textTheme.titleSmall,
  //                       ),
  //                       subtitle: Text(
  //                         phone,
  //                         maxLines: 1,
  //                         overflow: TextOverflow.ellipsis,
  //                         style: theme.textTheme.bodySmall,
  //                       ),
  //                       trailing: const Icon(Icons.chevron_right),
  //                       onTap: () => Navigator.of(sheetContext).pop(contact),
  //                     );
  //                   },
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }
  // ============ END CONTACT PICKER LOGIC ============

  // ============ OLD LOGIC - NO LONGER USED ============
  /*
  Future<void> _registerNativeShareTargets(
    List<Contact> selectedContacts,
    String shareStatus,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();

    for (final contact in selectedContacts) {
      final phoneRaw =
          contact.phones.isNotEmpty ? contact.phones.first.number : '';
      final phone = phoneRaw.trim().isEmpty ? 'N/A' : phoneRaw.trim();

      await _monetizationService.addReferralHistory({
        'name': (contact.displayName ?? '').trim().isEmpty
            ? _contactNameFallback
            : contact.displayName!.trim(),
        'phone': phone,
        'date': now,
        'method': 'share_plus_contact_sync',
        'shareStatus': shareStatus,
      });
    }
  }
  */

  /*
  Future<void> _shareReferralViaSharePlus() async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null) {
      final referralLink = AppsFlyerService().generateReferralLink(userUid);
      final message = _getMessageInfo(referralLink);
      
      try {
        // Share using SharePlus with ShareParams (like _shareChallengeLink)
        await SharePlus.instance.share(
          ShareParams(
            text: message,
            subject: 'Join me on InZone!',
          ),
        );

        // Track the referral attempt to Firebase
        // Even if the user shares to any platform, we log the referral
        await _monetizationService.addReferralHistory({
          'name': 'Shared via SharePlus',
          'phone': 'N/A',
          'date': DateTime.now().toUtc().toIso8601String(),
          'method': 'share_plus',
        });
        await _loadReferralHistory(); // Refresh the list
        
        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.checkCircle,
              color: Colors.greenAccent,
            ),
            message: '✅ Share sheet opened! Referral tracked.',
          );
        }
      } catch (e) {
        debugPrint('Error sharing referral: $e');
        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.xCircle,
              color: Colors.redAccent,
            ),
            message: 'Error sharing referral: $e',
          );
        }
      }
    }
  }
  */
  /*
  Future<void> _shareReferralLink() async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null) {
      final referralLink = AppsFlyerService().generateReferralLink(userUid);
      final message = _getMessageInfo(referralLink);
      await Share.share(
        message,
        subject: 'Join me on InZone!',
      );
    }
  }

  Future<void> _sendSMS(String message, String number) async {
    try {
      if (Platform.isAndroid) {
        String uri = 'sms:$number?body=${Uri.encodeComponent(message)}';
        await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
      } else if (Platform.isIOS) {
        String uri = 'sms:$number&body=${Uri.encodeComponent(message)}';
        await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
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
    }
  }

  Future<void> _handleContactSelection() async {
    final permissionStatus = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    if (permissionStatus != PermissionStatus.granted) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
        message: 'Contacts permission denied.',
      );
      return;
    }
    
    List<Contact> contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    List<Contact> contactList = contacts.where((c) => c.phones.isNotEmpty).toList();

    List<Contact> selectedContacts = await showDialog(
      context: context,
      builder: (context) => _ContactMultiSelectDialog(contacts: contactList),
    ) ?? [];

    if (selectedContacts.isEmpty) {
      return;
    }

    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null) {
      final referralLink = AppsFlyerService().generateReferralLink(userUid);
      final message = _getMessageInfo(referralLink);
      
      setState(() {
        _isSendingReferrals = true;
        _pendingContacts = selectedContacts;
        _pendingMessage = message;
        _currentContactIndex = 0;
      });

      _sendToNextContact();
    }
  }

  Future<void> _sendToNextContact() async {
    if (_pendingContacts == null || _currentContactIndex >= _pendingContacts!.length) {
      // All done
      _finishReferralProcess();
      return;
    }

    final contact = _pendingContacts![_currentContactIndex];
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;

    if (phone == null || phone.isEmpty) {
      _currentContactIndex++;
      _sendToNextContact();
      return;
    }

    // Simple toast showing progress
    if (mounted) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(FeatherIcons.send, color: Colors.blue),
        message: 'Opening SMS for ${contact.displayName ?? _contactNameFallback} (${_currentContactIndex + 1}/${_pendingContacts!.length})',
      );
    }

    // Open SMS app
    await _sendSMS(_pendingMessage!, phone);

    // Save to Firebase immediately
    try {
      await _monetizationService.addReferralHistory({
        'name': contact.displayName ?? _contactNameFallback,
        'phone': phone,
        'date': DateTime.now().toUtc().toIso8601String(),
      });
      await _loadReferralHistory(); // Refresh the list
    } catch (e) {
      debugPrint('Error saving referral: $e');
    }

    // The next contact will be handled automatically when app resumes (didChangeAppLifecycleState)
  }

  void _finishReferralProcess() {
    final totalSent = _currentContactIndex;
    if (mounted) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.checkCircle,
          color: Colors.greenAccent,
        ),
        message: '✅ Sent referrals to $totalSent contact(s)!',
      );
    }
    setState(() {
      _isSendingReferrals = false;
      _pendingContacts = null;
      _pendingMessage = null;
      _currentContactIndex = 0;
    });
  }
  */
  // ============ END OLD LOGIC ============


  String _getMessageInfo(String link) {
    return "Hey! 👋\n\nJoin me on InZone using this link: $link";
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
              Image.asset("icons/referral/instagram.png", width: 32, height: 32),
              const SizedBox(width: 14),
              Image.asset("icons/referral/tiktok.png", width: 32, height: 32),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: _syncContactsAndShareReferral,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FeatherIcons.share2,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
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

  void _copyReferralLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ToastService.showToast(
      context,
      backgroundColor: Theme.of(context).canvasColor,
      shadowColor: Colors.transparent,
      leading: const Icon(FeatherIcons.checkCircle, color: Colors.greenAccent),
      message: 'Referral link copied!',
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

// class _ContactMultiSelectDialog extends StatefulWidget {
//   final List<Contact> contacts;
//   const _ContactMultiSelectDialog({Key? key, required this.contacts}) : super(key: key);

//   @override
//   State<_ContactMultiSelectDialog> createState() => _ContactMultiSelectDialogState();
// }

// class _ContactMultiSelectDialogState extends State<_ContactMultiSelectDialog> {
//   late List<int> _selectedIndices;

//   @override
//   void initState() {
//     super.initState();
//     _selectedIndices = [];
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Select Contacts'),
//       content: SizedBox(
//         width: double.maxFinite,
//         height: 400,
//         child: ListView.builder(
//           itemCount: widget.contacts.length,
//           itemBuilder: (context, index) {
//             final contact = widget.contacts[index];
//             final isSelected = _selectedIndices.contains(index);
//             return CheckboxListTile(
//               value: isSelected,
//               onChanged: (val) {
//                 setState(() {
//                   if (val == true) {
//                     if (!_selectedIndices.contains(index)) {
//                       _selectedIndices.add(index);
//                     }
//                   } else {
//                     _selectedIndices.remove(index);
//                   }
//                 });
//               },
//               title: Text(contact.displayName ?? _contactNameFallback),
//               subtitle: Text(contact.phones.isNotEmpty ? contact.phones.first.number : ''),
//             );
//           },
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(<Contact>[]),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             final selected = _selectedIndices.map((i) => widget.contacts[i]).toList();
//             Navigator.of(context).pop(selected);
//           },
//           child: const Text('Send Referrals'),
//         ),
//       ],
//     );
//   }
// }
