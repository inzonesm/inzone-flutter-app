import 'package:contacts_service/contacts_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final MonetizationService _monetizationService = MonetizationService();
  List<Contact> _selectedContacts = [];
  bool _isLoading = false;
  String? _referralLink;
  List<Map<String, dynamic>> _referralHistory = [];

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
          child: Row(
            children: [
              Expanded(
                child: Button(
                  text: "Sync Contacts",
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await _handleContactSelection();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Button(
                  text: "Send to All Contacts",
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await _handleSendToAllContacts();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

      Future<void> _handleSendToAllContacts() async {
        final permissionStatus = await Permission.contacts.request();
        if (!permissionStatus.isGranted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
            message: 'Contacts permission denied.',
          );
          return;
        }
        Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);
        List<Contact> contactList = contacts.where((c) => c.phones != null && c.phones!.isNotEmpty).toList();
        if (contactList.isEmpty) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
            message: 'No contacts found.',
          );
          return;
        }
        setState(() {
          _selectedContacts = contactList;
        });
        final userUid = FirebaseAuth.instance.currentUser?.uid;
        if (userUid != null) {
          final referralLink = AppsFlyerService().generateReferralLink(userUid);
          final message = _getMessageInfo(referralLink);
          int sentCount = 0;
          for (final contact in contactList) {
            final phone = contact.phones?.isNotEmpty == true ? contact.phones!.first.value : null;
            if (phone != null && phone.isNotEmpty) {
              await sendSMS(message, phone);
              sentCount++;
              // Sync referral to backend
              await _monetizationService.addReferralHistory({
                'name': contact.displayName ?? 'Referred User',
                'phone': phone,
                'date': DateTime.now().toUtc().toString().split(' ')[0],
              });
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

      Future<void> _handleContactSelection() async {
        final permissionStatus = await Permission.contacts.request();
        if (!permissionStatus.isGranted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
            message: 'Contacts permission denied.',
          );
          return;
        }
        Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);
        List<Contact> contactList = contacts.where((c) => c.phones != null && c.phones!.isNotEmpty).toList();

        List<Contact> selectedContacts = await showDialog(
          context: context,
          builder: (context) => _ContactMultiSelectDialog(contacts: contactList),
        ) ?? [];

        if (selectedContacts.isEmpty) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
            message: 'No contacts selected.',
          );
          return;
        }

        setState(() {
          _selectedContacts = selectedContacts;
        });
        final userUid = FirebaseAuth.instance.currentUser?.uid;
        if (userUid != null) {
          final referralLink = AppsFlyerService().generateReferralLink(userUid);
          final message = _getMessageInfo(referralLink);
          int sentCount = 0;
          for (final contact in selectedContacts) {
            final phone = contact.phones?.isNotEmpty == true ? contact.phones!.first.value : null;
            if (phone != null && phone.isNotEmpty) {
              await sendSMS(message, phone);
              sentCount++;
              // Sync referral to backend
              await _monetizationService.addReferralHistory({
                'name': contact.displayName ?? 'Referred User',
                'phone': phone,
                'date': DateTime.now().toUtc().toString().split(' ')[0],
              });
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
      // ...existing code...
    }

  Future<void> sendSMS(String message, String number) async {
    // Always send real SMS in production
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

  Future<void> _handleContactSelection() async {
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
        message: 'Contacts permission denied.',
      );
      return;
    }
    Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);
    List<Contact> contactList = contacts.where((c) => c.phones != null && c.phones!.isNotEmpty).toList();

    List<Contact> selectedContacts = await showDialog(
      context: context,
      builder: (context) => _ContactMultiSelectDialog(contacts: contactList),
    ) ?? [];

    if (selectedContacts.isEmpty) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(FeatherIcons.xCircle, color: Colors.redAccent),
        message: 'No contacts selected.',
      );
      return;
    }

    setState(() {
      _selectedContacts = selectedContacts;
    });
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null) {
      final referralLink = AppsFlyerService().generateReferralLink(userUid);
      final message = _getMessageInfo(referralLink);
      int sentCount = 0;
      for (final contact in selectedContacts) {
        final phone = contact.phones?.isNotEmpty == true ? contact.phones!.first.value : null;
        if (phone != null && phone.isNotEmpty) {
          await sendSMS(message, phone);
          sentCount++;
          // Sync referral to backend
          await _monetizationService.addReferralHistory({
            'name': contact.displayName ?? 'Referred User',
            'phone': phone,
            'date': DateTime.now().toUtc().toString().split(' ')[0],
          });
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

// Custom dialog for multi-selecting contacts
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
              title: Text(contact.displayName ?? 'No Name'),
              subtitle: Text(contact.phones!.isNotEmpty ? contact.phones!.first.value ?? '' : ''),
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
  // ...existing code...
}
  // ...existing code...
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
