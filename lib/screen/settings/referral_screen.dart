import 'package:cloud_functions/cloud_functions.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/components/ui/button.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:inzone/screen/settings/referral_tile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final MonetizationService _monetizationService = MonetizationService();
  String? _referralCode;
  String? _referralLink;
  List<Map<String, dynamic>> _referralHistory = [];
  bool _isLoading = true;

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
        _referralCode = generateResponse['data']['referral_code'];
        _referralLink = 'https://inzone.ai/referral?code=$_referralCode';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading referral data: $e')),
        );
      }
    }
  }

  Future<void> _copyReferralLink() async {
    if (_referralLink != null) {
      await Clipboard.setData(ClipboardData(text: _referralLink!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral link copied to clipboard')),
        );
      }
    }
  }

  Future<void> _launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(url, forceSafariVC: false, forceWebView: false);
    } else {
      throw 'Could not launch $url';
    }
  }

  /* -------------------------------------*/
  Future<List<Contact>> fetchContacts() async {
    try {
      var status = await Permission.contacts.status;

      if (!status.isGranted) {
        status = await Permission.contacts.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Permission denied. Cannot access contacts.')),
            );
          }
          return [];
        }
      }

      final contacts = await ContactsService.getContacts(withThumbnails: false);

      return contacts.toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching contacts: $e')),
        );
      }
      return [];
    }
  }

  Future<List<Contact>> selectContacts(BuildContext context) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final contacts = await fetchContacts();

      if (contacts.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return [];
      }

      List<Contact> selectedContacts = [];

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select Contacts to Refer',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  Expanded(
                    child: ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        final isSelected = selectedContacts.contains(contact);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            child: const Icon(Icons.person),
                          ),
                          title: Text(contact.displayName ?? 'No Name'),
                          subtitle: contact.phones?.isNotEmpty == true
                              ? Text(contact.phones!.first.value ?? '')
                              : const Text('No phone number'),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: contact.phones?.isEmpty == true
                                ? null
                                : (bool? selected) {
                                    setModalState(() {
                                      if (selected == true) {
                                        selectedContacts.add(contact);
                                      } else {
                                        selectedContacts.remove(contact);
                                      }
                                    });
                                  },
                          ),
                          onTap: contact.phones?.isEmpty == true
                              ? null
                              : () {
                                  setModalState(() {
                                    if (isSelected) {
                                      selectedContacts.remove(contact);
                                    } else {
                                      selectedContacts.add(contact);
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: Button(
                        text: "Invite Selected Contacts",
                        onPressed: selectedContacts.isEmpty
                            ? () {}
                            : () {
                                context.pop();
                              },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      setState(() {
        _isLoading = false;
      });

      return selectedContacts;
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting contacts: $e')),
        );
      }

      return [];
    }
  }

  Future<void> sendReferralSMS(
      List<Contact> contacts, String referralCode) async {
    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No contacts selected or referral code missing')),
        );
      }
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('sendReferralSMS');

      final phoneNumbers = contacts
          .map((c) =>
              c.phones?.isNotEmpty == true ? c.phones!.first.value : null)
          .where((number) => number != null)
          .toList();

      if (phoneNumbers.isEmpty) {
        throw Exception('No valid phone numbers found');
      }

      await callable.call({
        'phoneNumbers': phoneNumbers,
        'referralCode': referralCode,
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending SMS: $e')),
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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CustomAppBar(
              isHome: true,
              isSettings: true,
              isImage: false,
              title: "Referral",
              userPoints: "100",
              onSearchTap: () {},
              onProfileTap: () {},
              onPointsTap: () {},
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildTopBanner(theme),
                const SizedBox(height: 20),
                _buildReferralLinkSection(theme),
                const SizedBox(height: 20),
                Text(
                  "Your Referrals",
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                // const ReferralTile(photoUrl: "", name: "name", date: "date"),
                _isLoading
                    ? _buildLoadingList()
                    : _buildReferralHistoryList(theme),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
          child: Button(
            text: _isLoading ? "Loading..." : "Sync Contacts",
            onPressed: _isLoading
                ? () {}
                : () async {
                    try {
                      final selectedContacts = await selectContacts(context);

                      if (selectedContacts.isNotEmpty &&
                          _referralCode != null) {
                        await sendReferralSMS(selectedContacts, _referralCode!);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Referral SMS sent successfully!')),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
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
              _referralLink ?? "Loading...",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _copyReferralLink,
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
