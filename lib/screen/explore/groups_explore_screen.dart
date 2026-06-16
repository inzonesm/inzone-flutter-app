import 'dart:io';
import 'dart:async';

import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/data/group_chat_data.dart';
import 'package:inzone/data/group_data_mapper.dart';
import 'package:inzone/components/cards/group_card.dart';
import 'package:inzone/components/cards/ad_card.dart';
import 'package:inzone/services/group_chat_service.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:inzone/services/reward_ad_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:flutter/services.dart';

class GroupsExploreScreen extends StatefulWidget {
  const GroupsExploreScreen({super.key});

  @override
  State<GroupsExploreScreen> createState() => _GroupsExploreScreenState();
}

class _GroupsExploreScreenState extends State<GroupsExploreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MonetizationService _monetizationService = MonetizationService();
  final RewardAdService _rewardAdService = RewardAdService();
  List<GroupData> _defaultGroups = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _userBalance = '0'; // Will be updated by _loadUserBalance method
  StreamSubscription<DocumentSnapshot>? _balanceSubscription;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  // Map to store participants for each group
  final Map<String, List<Participant>> _groupParticipants = {};
  bool _isRefreshing = false;

  // Memoized — the StreamBuilder used to call snapshots() inline in build,
  // tearing down and re-attaching a whole-collection listener on every
  // rebuild (including each search keystroke).
  late final Stream<QuerySnapshot> _groupChatsStream;

  @override
  void initState() {
    super.initState();
    _groupChatsStream = _firestore.collection('groupChats').snapshots();
    _loadDefaultGroups();
    _setupBalanceStream(); // Setup stream instead of one-time load
    _rewardAdService.initialize();
  }

  void _setupBalanceStream() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('No authenticated user found');
        return;
      }

      debugPrint('Setting up balance stream for UID: ${currentUser.uid}');

      _balanceSubscription = _firestore
          .collection('humanUsers')
          .doc(currentUser.uid)
          .snapshots()
          .listen(
        (DocumentSnapshot userDoc) {
          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final balance = userData['balance'];
            debugPrint(
                'Balance from Firestore stream: $balance (type: ${balance.runtimeType})');

            setState(() {
              _userBalance = balance?.toString() ?? '0';
              debugPrint('Updated _userBalance to: $_userBalance');
            });
          } else {
            debugPrint('User document does not exist in humanUsers collection');
            setState(() {
              _userBalance = '0';
            });
          }
        },
        onError: (error) {
          debugPrint('Error in balance stream: $error');
          setState(() {
            _userBalance = '0';
          });
        },
      );
    } catch (e) {
      debugPrint('Error setting up balance stream: $e');
      setState(() {
        _userBalance = '0';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _balanceSubscription?.cancel(); // Cancel the stream subscription
    _rewardAdService.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultGroups() async {
    _defaultGroups = [
      GroupData(
        id: '1',
        name: 'Hogwarts',
        description:
            'Hogwarts. Enchanted halls, secret passages, and a slight risk of death—but totally worth it.',
        memberCount: 3490,
        messageCount: 760,
        avatars: ['Harry', 'Hermione', 'Ron', 'Dumbledore'],
        isMember: false,
        showRandomCharacters: true,
        showFirst: true, // This group will appear first
      ),
      GroupData(
        id: '2',
        name: 'Assemble',
        description:
            'The Avengers. Earth\'s mightiest heroes, assembling chaos into victory.',
        memberCount: 5900,
        messageCount: 1760,
        avatars: ['Tony', 'Steve', 'Thor', 'Natasha'],
        isMember: false,
        showRandomCharacters: true,
        showFirst: false,
      ),
      GroupData(
        id: '3',
        name: 'Superstars',
        description: 'Athletes. Limits shattered, legends, greatness chased.',
        memberCount: 4560,
        messageCount: 460,
        avatars: ['Lebron', 'Messi', 'Serena', 'Ronaldo'],
        isMember: false,
        showRandomCharacters: true,
        showFirst: false,
      ),
      GroupData(
        id: '4',
        name: 'Anime',
        description: 'Anime. Emotions unleashed, worlds explored.',
        memberCount: 5160,
        messageCount: 960,
        avatars: ['Naruto', 'Goku', 'Luffy', 'Eren'],
        isMember: false,
        showRandomCharacters: true,
        showFirst: false,
      ),
    ];
  }

  List<GroupData> _convertFirestoreDataToGroups(
      List<DocumentSnapshot> documents) {
    List<GroupData> groups = [];
    for (var doc in documents) {
      try {
        GroupChatData chatData = GroupChatData.fromSnapshot(doc);

        // Extract showFirst from the document data directly
        final docData = doc.data() as Map<String, dynamic>?;
        bool showFirst = docData?['showFirst'] == true;

        GroupData groupData = GroupDataMapper.fromGroupChatData(chatData);

        // Update the group data with the showFirst field if it was set in Firestore
        if (showFirst) {
          groupData = groupData.copyWith(showFirst: true);
        }

        // Store participants in the map
        _groupParticipants[groupData.id] = chatData.participants;

        groups.add(groupData);
      } catch (e) {
        print('Error converting group data: $e');
      }
    }
    return groups;
  }

  // Helper method to check if a group has a participant matching the search query
  bool _hasMatchingParticipant(GroupData group, String query) {
    // Check for participants in our map
    if (_groupParticipants.containsKey(group.id) &&
        _groupParticipants[group.id]!.isNotEmpty) {
      return _groupParticipants[group.id]!
          .any((participant) => participant.name.toLowerCase().contains(query));
    }

    // Fallback to avatars for default groups
    return group.avatars.any((avatar) => avatar.toLowerCase().contains(query));
  }

  void presentPaywall() async {
    final paywallResult = await RevenueCatUI.presentPaywall();

    print('Paywall result: $paywallResult ${paywallResult.name}');
    if (paywallResult == PaywallResult.purchased ||
        paywallResult == PaywallResult.restored) {
      // Retrieve the latest customer information
      final customerInfo = await Purchases.getCustomerInfo();
      final transactions =
          List<StoreTransaction>.from(customerInfo.nonSubscriptionTransactions);
      if (transactions.isNotEmpty) {
        // Sort transactions by purchase date in descending order
        print(transactions);
        transactions.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

        for (var item in transactions) {
          print(item.productIdentifier);
          print(item.purchaseDate);
          print("\n\n");
        }

        try {
          // Get the most recent transaction
          final latestTransaction = transactions.first;
          final String productId = latestTransaction.productIdentifier;
          final String platform = Platform.isIOS ? 'ios' : 'android';

          // Get receipt data from the transaction
          final String receiptData = latestTransaction.transactionIdentifier;

          // P
          // rocess the purchase with our backend
          if (Platform.isAndroid) {
            if (productId == "2025incashadvanced") {
              await _monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "2025incashelite") {
              await _monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "2025incashbasic") {
              await _monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "2025incashgold" ||
                productId == "2025incashgold:2025incashgold") {
              // For subscription, we also need to update subscription status
              await _monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            }
          } else if (Platform.isIOS) {
            if (productId == "InCashGold") {
              // For subscription, we also need to update subscription status
              await _monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "InCashAdvanced2025") {
              await _monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "InCashElite2025") {
              await _monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "InCashBasic2025") {
              await _monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            }
          }
        } catch (e) {
          print('Error processing purchase: $e');
        }
      }
    } else if (paywallResult == PaywallResult.cancelled) {
      print("User closed the paywall without making a purchase.");
    } else if (paywallResult == PaywallResult.error) {
      print("An error occurred while presenting the paywall.");
    }
  }

  void _onRefresh() async {
    try {
      setState(() {
        _isRefreshing = true;
      });

      // Reload default groups
      await _loadDefaultGroups();

      // Clear the participants map to force reload
      _groupParticipants.clear();

      // Track analytics for refresh action
      print('User refreshed groups screen');

      // If you need to force a rebuild of the UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error during refresh: $e');
    } finally {
      // Wait a bit to show the refresh animation
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isRefreshing = false;
      });
      // Tell the RefreshController to finish the refresh process
      _refreshController.refreshCompleted();
    }
  }

  Widget refreshIcon() {
    return Image.asset(
      'assets/icons/dark.png',
      width: 35,
      height: 35,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      topColor: Theme.of(context).canvasColor,
      left: false,
      right: false,
      top: true,
      bottom: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        body: SmartRefresher(
          enablePullDown: true,
          controller: _refreshController,
          onRefresh: _onRefresh,
          physics: const BouncingScrollPhysics(),
          header: ClassicHeader(
            releaseIcon: refreshIcon(),
            refreshingIcon: refreshIcon(),
            completeIcon: refreshIcon(),
            idleIcon: refreshIcon(),
            failedIcon: refreshIcon(),
            refreshingText: "",
            releaseText: "",
            completeText: "",
            idleText: "",
            failedText: "",
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: _groupChatsStream,
            builder: (context, snapshot) {
              // Common top UI elements (appbar and search)
              List<Widget> commonSlivers = [
                SliverAppBar(
                  pinned: false,
                  floating: true,
                  snap: true,
                  toolbarHeight: 70,
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: CustomAppBar(
                    isHome: true,
                    isGroup: true,
                    userPoints: _userBalance,
                    profileImageUrl: null,
                    onSearchTap: null,
                    onProfileTap: () {},
                    onPointsTap: () {
                      try {
                        _showInCashOptionsBottomSheet();
                        HapticFeedback.lightImpact();
                      } catch (e) {
                        ToastService.showToast(
                          context,
                          backgroundColor: Theme.of(context).canvasColor,
                          shadowColor: Colors.transparent,
                          leading: const Icon(
                            FeatherIcons.xCircle,
                            color: Colors.redAccent,
                          ),
                          message: 'Error showing options: $e',
                        );
                      }
                    },
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverSearchBarDelegate(
                    child: Container(
                      color: Theme.of(context).canvasColor,
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase().trim();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search participants...',
                            prefixIcon: Icon(Icons.search,
                                color: Theme.of(context).iconTheme.color),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface
                                            .withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Icon(
                                          Icons.clear,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                        FocusScope.of(context).unfocus();
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: false,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                    ),
                    minHeight: 80.0,
                    maxHeight: 80.0,
                  ),
                ),
              ];

              if (snapshot.connectionState == ConnectionState.waiting ||
                  _isRefreshing) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    ...commonSlivers,
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: GroupCardLoading(context),
                            );
                          },
                          childCount: 8, // Show 8 loading cards
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 130)),
                  ],
                );
              }

              if (snapshot.hasError) {
                print('Error loading groups: ${snapshot.error}');
                return CustomScrollView(
                  slivers: [
                    ...commonSlivers,
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading groups',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Using default groups instead',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: _onRefresh,
                              child: Text(
                                'Try Again',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              List<GroupData> groups = [];

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                groups = _convertFirestoreDataToGroups(snapshot.data!.docs);
              }

              if (groups.isEmpty) {
                groups = _defaultGroups;
                GroupChatService.ensureDefaultGroupExists();
              }

              if (_searchQuery.isNotEmpty) {
                groups = groups
                    .where((group) =>
                        group.name.toLowerCase().contains(_searchQuery) ||
                        _hasMatchingParticipant(group, _searchQuery))
                    .toList();
              }

              groups.sort((a, b) {
                if (a.showFirst && !b.showFirst) {
                  return -1;
                } else if (!a.showFirst && b.showFirst) {
                  return 1;
                } else {
                  return 0;
                }
              });

              final List<dynamic> listItems = [];
              if (groups.isNotEmpty) {
                const int adInterval = 4;
                const int itemsPerAd = adInterval - 1;

                for (int i = 0; i < groups.length; i++) {
                  listItems.add(groups[i]);
                  if ((i + 1) % itemsPerAd == 0) {
                    listItems.add('ad');
                  }
                }
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  ...commonSlivers,
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    sliver: listItems.isEmpty
                        ? SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.group_off,
                                    size: 60,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No groups available',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _onRefresh,
                                    child: Text(
                                      'Refresh',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (listItems[index] is String &&
                                    listItems[index] == 'ad') {
                                  return const AdCard();
                                }
                                final group = listItems[index] as GroupData;
                                return GroupCard(group: group);
                              },
                              childCount: listItems.length,
                            ),
                          ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 130)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController imageUrlController = TextEditingController(
      text:
          "https://upload.wikimedia.org/wikipedia/sco/4/47/FC_Barcelona_%28crest%29.svg",
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Enter a name for your group',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter a description for your group',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'Enter an image URL for your group',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ToastService.showToast(
                    context,
                    backgroundColor: Theme.of(context).canvasColor,
                    shadowColor: Colors.transparent,
                    leading: const Icon(
                      FeatherIcons.xCircle,
                      color: Colors.redAccent,
                    ),
                    message: 'Please enter a group name',
                  );
                  return;
                }

                try {
                  final groupId = await GroupChatService.createNewGroup(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    imageUrlController.text.trim(),
                  );

                  Navigator.of(dialogContext).pop();

                  ToastService.showToast(
                    context,
                    backgroundColor: Theme.of(context).canvasColor,
                    shadowColor: Colors.transparent,
                    leading: const Icon(
                      FeatherIcons.checkCircle,
                      color: Colors.greenAccent,
                    ),
                    message:
                        'Group "${nameController.text}" created successfully',
                  );
                } catch (e) {
                  print('Error creating group: $e');
                  ToastService.showToast(
                    context,
                    backgroundColor: Theme.of(context).canvasColor,
                    shadowColor: Colors.transparent,
                    leading: const Icon(
                      FeatherIcons.xCircle,
                      color: Colors.redAccent,
                    ),
                    message: 'Error creating group: $e',
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showInCashOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Get InCash',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 24),

              // Purchase Option
              _buildInCashOptionTile(
                icon: Icons.credit_card,
                title: 'Purchase InCash',
                subtitle: 'Buy InCash packages',
                onTap: () {
                  Navigator.pop(context);
                  presentPaywall();
                },
              ),
              const SizedBox(height: 16),

              // Watch Ad Option
              FutureBuilder<int>(
                future: _rewardAdService.getRemainingRewardAds(),
                builder: (context, snapshot) {
                  final remainingAds = snapshot.data ?? 0;
                  final canWatch = remainingAds > 0;

                  String title = 'Watch Ad for InCash';

                  String subtitle = canWatch
                      ? 'Earn ${RewardAdService.rewardAmountPerAd} InCash ($remainingAds left today)'
                      : 'Daily limit reached (${RewardAdService.maxDailyRewardAds}/day)';

                  return _buildInCashOptionTile(
                    icon: Icons.play_circle_outline,
                    title: title,
                    subtitle: subtitle,
                    onTap: canWatch
                        ? () {
                            Navigator.pop(context);
                            _watchRewardAd();
                          }
                        : null,
                    isEnabled: canWatch,
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInCashOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEnabled
                ? Theme.of(context).canvasColor
                : Theme.of(context).canvasColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: isEnabled ? Theme.of(context).primaryColor : Colors.grey,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isEnabled
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Colors.grey,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isEnabled
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Colors.grey,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _watchRewardAd() {
    _rewardAdService.showRewardAd(
      context,
      onRewardEarned: () {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.checkCircle,
            color: Colors.greenAccent,
          ),
          message: 'You earned ${RewardAdService.rewardAmountPerAd} InCash!',
        );
      },
      onError: (error) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: error,
        );
      },
    );
  }
}

class _SliverSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _SliverSearchBarDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  bool shouldRebuild(_SliverSearchBarDelegate oldDelegate) {
    return child != oldDelegate.child ||
        minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight;
  }
}
