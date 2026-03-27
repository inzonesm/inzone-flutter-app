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
  bool _isLoading = true;
  String? _referralLink;
  List<Map<String, dynamic>> _referralHistory = [];
  
  // For sequential SMS sending
  bool _isSendingReferrals = false;
  int _currentContactIndex = 0;
  List<Contact>? _pendingContacts;
  String? _pendingMessage;

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
    
    // When user returns to the app after sending SMS
    if (state == AppLifecycleState.resumed && _isSendingReferrals && _pendingContacts != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isSendingReferrals) {
          _currentContactIndex++;
          _sendToNextContact();
        }
      });
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
              await _handleContactSelection();
            },
          ),
        ),
      ),
    );
  }

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
                onTap: _shareReferralLink,
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

// Place this at the very end of the file, outside any other class!
class _ContactMultiSelectDialog extends StatefulWidget {
  final List<Contact> contacts;
  const _ContactMultiSelectDialog({Key? key, required this.contacts}) : super(key: key);

  @override
  State<_ContactMultiSelectDialog> createState() => _ContactMultiSelectDialogState();
}

class _ContactMultiSelectDialogState extends State<_ContactMultiSelectDialog> {
  late List<int> _selectedIndices;

  @override
  void initState() {
    super.initState();
    _selectedIndices = [];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Contacts'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: widget.contacts.length,
          itemBuilder: (context, index) {
            final contact = widget.contacts[index];
            final isSelected = _selectedIndices.contains(index);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    if (!_selectedIndices.contains(index)) {
                      _selectedIndices.add(index);
                    }
                  } else {
                    _selectedIndices.remove(index);
                  }
                });
              },
              title: Text(contact.displayName ?? _contactNameFallback),
              subtitle: Text(contact.phones.isNotEmpty ? contact.phones.first.number : ''),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(<Contact>[]),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final selected = _selectedIndices.map((i) => widget.contacts[i]).toList();
            Navigator.of(context).pop(selected);
          },
          child: const Text('Send Referrals'),
        ),
      ],
    );
  }
}
