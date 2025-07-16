import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/screen/chat/sample_chat.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:inzone/components/chat/chat_input.dart';
import 'package:inzone/components/chat/date_header.dart';
import 'package:inzone/components/chat/message_bubble.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/data/group_chat_data.dart';
import 'package:inzone/services/group_chat_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/theme/light_theme.dart'; // Import for ChatTheme extension
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/paywall_result.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Group Chat Session Tracker
class GroupChatSessionTracker {
  static final Map<String, DateTime> _sessionStartTimes = {};
  static final Map<String, int> _sessionMessageCounts = {};
  static final Map<String, Set<String>> _sessionParticipants = {};
  static final Map<String, List<String>> _sessionActivityTypes = {};

  static void startSession(String groupId, String userId) {
    _sessionStartTimes[groupId] = DateTime.now();
    _sessionMessageCounts[groupId] = 0;
    _sessionParticipants[groupId] = <String>{userId};
    _sessionActivityTypes[groupId] = ['session_start'];

    // Track group chat joined event
    AppsFlyerService().trackGroupChatJoined(
      groupId: groupId,
      userId: userId,
    );
  }

  static void incrementActivity(
      String groupId, String userId, String activityType) {
    _sessionMessageCounts[groupId] = (_sessionMessageCounts[groupId] ?? 0) + 1;
    _sessionParticipants[groupId]?.add(userId);
    _sessionActivityTypes[groupId]?.add(activityType);
  }

  static void endSession(String groupId, String userId) {
    final startTime = _sessionStartTimes[groupId];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inSeconds;
      final messageCount = _sessionMessageCounts[groupId] ?? 0;
      final participants = _sessionParticipants[groupId]?.length ?? 0;
      final activities = _sessionActivityTypes[groupId] ?? [];

      if (duration > 10) {
        // Only track sessions longer than 10 seconds
        AppsFlyerService().trackGroupChatActivity(
          groupId: groupId,
          userId: userId,
          durationSeconds: duration,
          messagesSent: messageCount,
        );

        // Track detailed group engagement
        AppsFlyerService().logEvent('group_chat_session_end', {
          'group_id': groupId,
          'user_id': userId,
          'session_duration_sec': duration,
          'messages_sent': messageCount,
          'active_participants': participants,
          'activity_types': activities.join(','),
          'engagement_quality':
              _calculateEngagementQuality(duration, messageCount),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      _sessionStartTimes.remove(groupId);
      _sessionMessageCounts.remove(groupId);
      _sessionParticipants.remove(groupId);
      _sessionActivityTypes.remove(groupId);
    }
  }

  static String _calculateEngagementQuality(int duration, int messageCount) {
    if (messageCount == 0) return 'lurker';
    if (duration < 60) return 'brief';
    if (messageCount < 3) return 'low';
    if (messageCount < 10) return 'medium';
    return 'high';
  }

  static void clearSession(String groupId) {
    _sessionStartTimes.remove(groupId);
    _sessionMessageCounts.remove(groupId);
    _sessionParticipants.remove(groupId);
    _sessionActivityTypes.remove(groupId);
  }
}

class GroupChatScreen extends StatefulWidget {
  final GroupData group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final bool _isLoading = true;

  GroupChatData? _groupChatData;
  late String _groupId;
  final Map<String, String> _userProfileImages =
      {}; // Cache for user profile images

  // Group Chat Activity Tracking
  late DateTime _sessionStartTime;
  late String _currentUserId;
  int _messagesSentThisSession = 0;
  int _totalMessagesViewed = 0;
  final Set<String> _observedParticipants = <String>{};
  final List<String> _sessionActivities = [];

  // Define the cost to join a group chat
  final int _joinGroupCost = 100; // Cost in InCash to join the group

  @override
  void initState() {
    super.initState();

    // Use the provided group ID if it's a valid Firestore group ID
    // Otherwise, use the default one
    _groupId = widget.group.id.contains('group_chat_')
        ? widget.group.id
        : GroupChatService.defaultGroupChatDocId;

    print('Opening group chat with ID: $_groupId');

    // Initialize session tracking
    _sessionStartTime = DateTime.now();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    // Start group chat session tracking
    GroupChatSessionTracker.startSession(_groupId, _currentUserId);

    // Track group chat session start
    AppsFlyerService().logEvent('group_chat_session_start', {
      'group_id': _groupId,
      'group_name': widget.group.name,
      'user_id': _currentUserId,
      'member_count': widget.group.memberCount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Update the group's isMember status if not already a member
    if (!widget.group.isMember) {
      widget.group.isMember = true;
      _trackGroupJoinEvent();
    }

    // Fetch user profile images
    _fetchUserProfileImages();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _checkFirstTimeAndShowPopup();
    // });
  }

  String _getGroupCategoryKey(String groupName) {
    final lowerCaseName = groupName.toLowerCase();
    const keyPrefix = 'group_popup_seen';

    if (lowerCaseName.contains('tiktok') ||
        lowerCaseName.contains('hiphop') ||
        lowerCaseName.contains('meme start') ||
        lowerCaseName.contains('disney')) {
      return '${keyPrefix}_social';
    }

    if (lowerCaseName.contains('marvel') ||
        lowerCaseName.contains('anime') ||
        lowerCaseName.contains('fantasy') ||
        lowerCaseName.contains('video game')) {
      return '${keyPrefix}_geek';
    }

    if (lowerCaseName.contains('sports superstars') ||
        lowerCaseName.contains('greatest cartoon')) {
      return '${keyPrefix}_icons';
    }

    return '${keyPrefix}_other';
  }

  // void _checkFirstTimeAndShowPopup() async {
  //   final categoryKey = _getGroupCategoryKey(widget.group.name);
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   bool isFirstTimeForCategory = prefs.getBool(categoryKey) ?? true;

  //   if (isFirstTimeForCategory) {
  //     HapticFeedback.mediumImpact();
  //     final category = categoryKey.split('_').last;
  //     await Navigator.push(
  //       context,
  //       PageRouteBuilder(
  //         opaque: false,
  //         pageBuilder: (context, animation, secondaryAnimation) =>
  //             SampleChatPage(category: category),
  //         transitionsBuilder: (context, animation, secondaryAnimation, child) {
  //           return FadeTransition(
  //             opacity: animation,
  //             child: child,
  //           );
  //         },
  //         transitionDuration: const Duration(milliseconds: 200),
  //       ),
  //     );
  //     await prefs.setBool(categoryKey, false);
  //   }
  // }

  void _trackGroupJoinEvent() {
    AppsFlyerService().logEvent('group_chat_join_action', {
      'group_id': _groupId,
      'group_name': widget.group.name,
      'user_id': _currentUserId,
      'join_method': 'direct', // or 'payment', 'invitation', etc.
      'member_count_at_join': widget.group.memberCount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  void dispose() {
    // End group chat session tracking
    GroupChatSessionTracker.endSession(_groupId, _currentUserId);

    // Track comprehensive session analytics
    final sessionDuration =
        DateTime.now().difference(_sessionStartTime).inSeconds;

    if (sessionDuration > 5) {
      AppsFlyerService().logEvent('group_chat_engagement_summary', {
        'group_id': _groupId,
        'group_name': widget.group.name,
        'user_id': _currentUserId,
        'session_duration_sec': sessionDuration,
        'messages_sent': _messagesSentThisSession,
        'messages_viewed': _totalMessagesViewed,
        'participants_observed': _observedParticipants.length,
        'activities_performed': _sessionActivities.join(','),
        'engagement_score': _calculateEngagementScore(),
        'is_active_participant': _messagesSentThisSession > 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Track group popularity metrics
      AppsFlyerService().logEvent('group_chat_popularity', {
        'group_id': _groupId,
        'group_name': widget.group.name,
        'member_count': widget.group.memberCount,
        'session_count': 1, // This session
        'avg_session_duration': sessionDuration,
        'active_messaging': _messagesSentThisSession > 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    super.dispose();
  }

  double _calculateEngagementScore() {
    double score = 0.0;
    final sessionMinutes =
        DateTime.now().difference(_sessionStartTime).inMinutes;

    // Base score from time spent
    score += sessionMinutes * 0.1;

    // Bonus for sending messages
    score += _messagesSentThisSession * 2.0;

    // Bonus for viewing messages
    score += _totalMessagesViewed * 0.5;

    // Bonus for observing multiple participants
    score += _observedParticipants.length * 1.0;

    return score.clamp(0.0, 100.0);
  }

  // Fetch user profile images for the participants
  Future<void> _fetchUserProfileImages() async {
    try {
      print('Starting to fetch user profile images');

      // Get the group chat document to find all participants
      final groupChatDoc = await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(_groupId)
          .get();

      if (groupChatDoc.exists) {
        final data = groupChatDoc.data();
        if (data != null && data['participants'] is List) {
          List<dynamic> participants = data['participants'];
          print('Found ${participants.length} participants in the group');

          // Loop through all participants to fetch profile images
          for (var participant in participants) {
            if (participant is Map) {
              String type = participant['type'] as String? ?? '';
              String uid = participant['uid'] as String? ?? '';

              print('Processing participant: $uid, type: $type');

              // For regular users, try to fetch from users collection
              if (type == 'user' && uid.isNotEmpty) {
                // First check if there's already a profilePictureUrl in participant data
                if (participant['profilePictureUrl'] != null &&
                    participant['profilePictureUrl'].toString().isNotEmpty) {
                  print(
                      'Found profilePictureUrl directly in participant data for $uid');
                  setState(() {
                    _userProfileImages[uid] =
                        participant['profilePictureUrl'].toString();
                  });
                  continue; // Skip to next participant if we already have the picture
                }

                // Try two different profile picture field names
                final userDocRef =
                    FirebaseFirestore.instance.collection('users').doc(uid);
                final userDoc = await userDocRef.get();

                if (userDoc.exists) {
                  final userData = userDoc.data();
                  if (userData != null) {
                    // Try different possible field names for profile picture
                    String? profileUrl;
                    if (userData['profilePictureUrl'] != null &&
                        userData['profilePictureUrl'].toString().isNotEmpty) {
                      profileUrl = userData['profilePictureUrl'].toString();
                    } else if (userData['profileImage'] != null &&
                        userData['profileImage'].toString().isNotEmpty) {
                      profileUrl = userData['profileImage'].toString();
                    } else if (userData['photoURL'] != null &&
                        userData['photoURL'].toString().isNotEmpty) {
                      profileUrl = userData['photoURL'].toString();
                    } else if (userData['avatar'] != null &&
                        userData['avatar'].toString().isNotEmpty) {
                      profileUrl = userData['avatar'].toString();
                    }

                    if (profileUrl != null) {
                      print('Found profile picture for user $uid: $profileUrl');
                      setState(() {
                        _userProfileImages[uid] = profileUrl!;
                      });
                    } else {
                      print('No profile picture found in user data for $uid');
                    }
                  }
                } else {
                  print('User document not found for $uid');

                  // As a fallback, try to get from auth user data
                  if (FirebaseAuth.instance.currentUser?.uid == uid) {
                    final photoURL =
                        FirebaseAuth.instance.currentUser?.photoURL;
                    if (photoURL != null && photoURL.isNotEmpty) {
                      print(
                          'Using photoURL from FirebaseAuth for current user');
                      setState(() {
                        _userProfileImages[uid] = photoURL;
                      });
                    }
                  }
                }
              }

              // For AI users, ensure we have their profile picture
              else if (type == 'ai' &&
                  uid.isNotEmpty &&
                  participant['profilePictureUrl'] != null &&
                  participant['profilePictureUrl'].toString().isNotEmpty) {
                print(
                    'Found AI profile picture for $uid: ${participant['profilePictureUrl']}');
                setState(() {
                  _userProfileImages[uid] =
                      participant['profilePictureUrl'].toString();
                });
              }
            }
          }
          print(
              'Finished processing all participants. Profile image cache size: ${_userProfileImages.length}');
        }
      }

      // Force UI update
      setState(() {});
    } catch (e) {
      print('Error fetching user profile images: $e');
    }
  }

  // Method to check if user has paid for the group chat
  Future<bool> _hasPaidForGroup() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return false;

      // Check if user is in the conversations collection for this group
      final docSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_groupId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data['participants'] is List) {
          final participants = data['participants'] as List;
          return participants.contains(currentUserId);
        }
      }
      return false;
    } catch (e) {
      print('Error checking if user has paid for group: $e');
      return false;
    }
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;

    final content = _msgController.text.trim();
    final messageLength = content.length;
    _msgController.clear();

    // Get current user ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      // Handle not logged in case
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'You need to be logged in to send messages',
      );
      return;
    }

    // Track message sending analytics
    _messagesSentThisSession++;
    _sessionActivities.add('message_sent');
    GroupChatSessionTracker.incrementActivity(
        _groupId, currentUserId, 'message_sent');

    final sessionDurationSoFar =
        DateTime.now().difference(_sessionStartTime).inSeconds;

    AppsFlyerService().logEvent('group_chat_message_sent', {
      'group_id': _groupId,
      'group_name': widget.group.name,
      'user_id': currentUserId,
      'message_length': messageLength,
      'message_number': _messagesSentThisSession,
      'session_duration_so_far': sessionDurationSoFar,
      'member_count': widget.group.memberCount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Check if user has paid for the group chat
    final hasPaid = await _hasPaidForGroup();
    if (!hasPaid) {
      // Show a floating SnackBar informing the user they need to join first
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'You need to join this group before sending messages'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      }
      return;
    }

    try {
      // Check if current user is already a participant
      bool isParticipant = false;

      if (_groupChatData != null) {
        // Check in the already loaded data
        isParticipant =
            _groupChatData!.participants.any((p) => p.uid == currentUserId);
      } else {
        // Fetch latest data from Firestore
        final docSnapshot = await FirebaseFirestore.instance
            .collection('groupChats')
            .doc(_groupId)
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          if (data != null && data['participants'] is List) {
            final participants = data['participants'] as List;
            isParticipant =
                participants.any((p) => p is Map && p['uid'] == currentUserId);
          }
        }
      }

      if (!isParticipant) {
        print('User is not a participant, adding to the group first');

        // Get current user info for adding as participant
        final currentUser = FirebaseAuth.instance.currentUser!;
        String displayName = currentUser.displayName ?? 't';
        if (displayName.length < 2) {
          try {
            // Try to get user profile from Firebase
            Map<String, dynamic>? userProfile =
                await InZoneDatabase.getUserProfile(currentUser.uid);
            if (userProfile != null) {
              displayName =
                  userProfile["username"] ?? userProfile["username"] ?? 'User';
              // currentUser.updateDisplayName(displayName);
            }
          } catch (e) {
            print('Error fetching user name from database: $e');
          }
        }

        // Create participant object
        final currentParticipant = {
          'uid': currentUser.uid,
          'type': 'user',
          'name': displayName,
        };

        // Add current user to participants
        await FirebaseFirestore.instance
            .collection('groupChats')
            .doc(_groupId)
            .update({
          'participants': FieldValue.arrayUnion([currentParticipant]),
          'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
        });

        print('Added current user to participants');
      }

      // Now send the message
      await GroupChatService.sendMessageToGroup(_groupId, content);
      _scrollToBottom();
    } catch (e) {
      print('Error checking/updating participant status: $e');
      // Fallback to direct message send
      GroupChatService.sendMessageToGroup(_groupId, content);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

          // Create monetization service instance
          final monetizationService = MonetizationService();

          // Process the purchase with our backend
          if (Platform.isAndroid) {
            if (productId == "2025incashadvanced") {
              await monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "2025incashelite") {
              await monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "2025incashbasic") {
              await monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "2025incashgold" ||
                productId == "2025incashgold:2025incashgold") {
              // For subscription, we also need to update subscription status
              await monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            }
          } else if (Platform.isIOS) {
            if (productId == "InCashGold") {
              // For subscription, we also need to update subscription status
              await monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "InCashAdvanced2025") {
              await monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "InCashElite2025") {
              await monetizationService.purchaseInCash(
                  productId, platform, receiptData);
            } else if (productId == "InCashBasic2025") {
              await monetizationService.purchaseInCash(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<DocumentSnapshot>(
          stream: GroupChatService.getGroupChatStreamById(_groupId),
          builder: (context, snapshot) {
            // Default values from the group data passed to constructor
            String groupName = widget.group.name;
            String memberCount = '${widget.group.memberCount} members';
            Widget groupAvatar = const Icon(Icons.account_circle, size: 40);

            // If we have Firebase data, use it instead
            if (snapshot.hasData && snapshot.data!.exists) {
              try {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  print(
                      'Group data from Firebase: name=${data['name']}, imageUrl=${data['imageUrl']}');

                  // Get participants info for debugging
                  if (data.containsKey('participants') &&
                      data['participants'] is List) {
                    final participantsList = data['participants'] as List;
                    print('Group participants: ${participantsList.length}');
                    for (var participant in participantsList) {
                      if (participant is Map) {
                        print(
                            ' - ${participant['name']} (${participant['type']})');
                      }
                    }
                  }

                  // Get name from Firebase
                  if (data.containsKey('name') && data['name'] != null) {
                    groupName = data['name'] as String;
                  }

                  // Get member count from Firebase participants
                  if (data.containsKey('participants') &&
                      data['participants'] is List) {
                    final participantsList = data['participants'] as List;
                    memberCount = '${participantsList.length} members';
                  }

                  // Get image from Firebase
                  if (data.containsKey('imageUrl') &&
                      data['imageUrl'] != null &&
                      data['imageUrl'].toString().isNotEmpty) {
                    final imageUrl = data['imageUrl'] as String;
                    groupAvatar = Container(
                      width: 40,
                      height: 40,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).cardColor,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 40,
                        width: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox(),
                        errorWidget: (context, url, error) {
                          print('Error loading group image: $error');
                          // Fallback to icon if image fails to load
                          return const Center(
                            child: Icon(Icons.account_circle, size: 40),
                          );
                        },
                      ),
                    );
                  } else if (data.containsKey('avatars') &&
                      data['avatars'] is List) {
                    // If there's no group image but there are member avatars, try to use the first one
                    final avatars = data['avatars'] as List;
                    if (avatars.isNotEmpty &&
                        avatars[0] is String &&
                        avatars[0].toString().isNotEmpty &&
                        avatars[0].toString().startsWith('http')) {
                      groupAvatar = Container(
                        width: 40,
                        height: 40,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: avatars[0].toString(),
                          height: 40,
                          width: 40,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(),
                          errorWidget: (context, url, error) {
                            return const Center(
                              child: Icon(Icons.account_circle, size: 40),
                            );
                          },
                        ),
                      );
                    }
                  }
                }
              } catch (e) {
                print('Error parsing group data in AppBar: $e');
              }
            }

            return AppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).canvasColor,
              leadingWidth: 50,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: GestureDetector(
                  onTap: () {
                    context.pop();
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: 18,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).cardColor,
                    ),
                    child: Center(child: groupAvatar),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          memberCount,
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // Join button to add group to user's chat list
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(_groupId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;
                    bool isJoined = false;

                    if (snapshot.hasData &&
                        snapshot.data!.exists &&
                        currentUserId != null) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data['participants'] is List) {
                        final participants = data['participants'] as List;
                        isJoined = participants.contains(currentUserId);
                      }
                    }

                    return isJoined
                        ? Container() // Already joined, don't show button
                        : TextButton.icon(
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                            label: Text(
                              'Join',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _joinGroup(context),
                          );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.more_vert,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    // Show the participants dialog
                    _showParticipantsDialog(context);
                  },
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: GroupChatService.getGroupChatStreamById(_groupId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(
                      child: Text('No data available'),
                    );
                  }

                  try {
                    // Print raw data for debugging
                    final rawData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    print('Raw Firestore data: $rawData');

                    // Check if messages exist in the data
                    final List<dynamic>? messagesData =
                        rawData['messages'] as List<dynamic>?;
                    if (messagesData == null || messagesData.isEmpty) {
                      print('No messages found in Firestore data');
                      return const Center(
                        child: Text('No messages yet. Start the conversation!'),
                      );
                    }

                    // Convert the data to GroupChatData
                    _groupChatData = GroupChatData.fromSnapshot(snapshot.data!);

                    if (_groupChatData!.messages.isEmpty) {
                      return const Center(
                        child: Text(
                            'No messages parsed correctly. Check data format.'),
                      );
                    }

                    // Track message viewing analytics
                    _totalMessagesViewed = _groupChatData!.messages.length;
                    for (var message in _groupChatData!.messages) {
                      _observedParticipants.add(message.sender.uid);
                    }
                    _sessionActivities.add('messages_viewed');

                    // Scroll to bottom when new messages come in
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());

                    return _buildMessageList(_groupChatData!.messages);
                  } catch (e) {
                    print('Error parsing Firestore data: $e');
                    return Center(
                      child: Text('Error parsing data: $e'),
                    );
                  }
                },
              ),
            ),
            ChatInput(
              controller: _msgController,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages yet. Start the conversation!'),
      );
    }

    // Create a single list of widgets if there are no timestamps
    bool hasTimestamps = messages.any((msg) => msg.timestamp != null);

    if (!hasTimestamps) {
      List<Widget> messageWidgets = [];

      // Add a "Today" header
      messageWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Messages',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );

      // Add all messages
      for (var message in messages) {
        messageWidgets.add(_buildMessageBubble(message));
      }

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: messageWidgets.length,
        itemBuilder: (context, index) {
          return messageWidgets[index];
        },
      );
    }

    // Group messages by date (original implementation)
    Map<String, List<ChatMessage>> messagesByDate = {};

    for (var message in messages) {
      if (message.timestamp == null) {
        // Skip messages without timestamp or add to a "No Date" group
        const String dateKey = 'No Date';
        if (!messagesByDate.containsKey(dateKey)) {
          messagesByDate[dateKey] = [];
        }
        messagesByDate[dateKey]!.add(message);
        continue;
      }

      final String dateKey = _getDateKey(message.timestamp!);

      if (!messagesByDate.containsKey(dateKey)) {
        messagesByDate[dateKey] = [];
      }

      messagesByDate[dateKey]!.add(message);
    }

    // Create a list of widgets with date headers and messages
    List<Widget> messageWidgets = [];

    messagesByDate.forEach((dateKey, messages) {
      // Add date header
      if (dateKey != 'No Date') {
        DateTime headerDate;
        final now = DateTime.now().toUtc();
        final today = DateTime(now.year, now.month, now.day);

        if (dateKey == 'Today') {
          headerDate = today;
        } else if (dateKey == 'Yesterday') {
          headerDate = today.subtract(const Duration(days: 1));
        } else {
          // Parse the date from the format "MMMM d, yyyy"
          headerDate = DateFormat('MMMM d, yyyy').parse(dateKey);
        }

        messageWidgets.add(DateHeader(dateTime: headerDate));
      } else {
        // For messages without timestamp
        messageWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Updated Messages',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Add messages for this date
      for (var message in messages) {
        messageWidgets.add(_buildMessageBubble(message));
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messageWidgets.length,
      itemBuilder: (context, index) {
        return messageWidgets[index];
      },
    );
  }

  String _getDateKey(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(dateTime.toLocal());
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isMe =
        message.sender.uid == FirebaseAuth.instance.currentUser?.uid;

    // Debug print to check sender data
    print(
        'Building message bubble for sender: ${message.sender.name}, type: ${message.sender.type}, uid: ${message.sender.uid}');
    if (_userProfileImages.containsKey(message.sender.uid)) {
      print(
          'Profile image found in cache for this sender: ${_userProfileImages[message.sender.uid]}');
    }

    return MessageBubble(
      message: message.content,
      isMe: isMe,
      timestamp: message.timestamp,
      senderName: message.sender.name,
      senderAvatar: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).cardColor,
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildSenderAvatar(message.sender),
      ),
    );
  }

  // Build sender avatar based on type
  Widget _buildSenderAvatar(MessageSender sender) {
    // For Messi (special AI user), use Barcelona crest
    if (sender.type == 'ai' && sender.name == 'Lionel Messi') {
      return const Center(
        child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 35),
      );
    }

    // Check for cached user profile image first for regular users
    if (sender.type == 'user' && _userProfileImages.containsKey(sender.uid)) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _userProfileImages[sender.uid]!,
          fit: BoxFit.cover,
          height: 35,
          width: 35,
          placeholder: (context, url) => const SizedBox(),
          errorWidget: (context, url, error) {
            return Center(
              child: Text(
                sender.name.isNotEmpty ? sender.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      );
    }

    // For both AI users and regular users, check for profile picture URL
    if (_groupChatData != null) {
      final participant = _groupChatData!.participants.firstWhere(
        (p) => p.uid == sender.uid,
        orElse: () => Participant(uid: '', type: '', name: ''),
      );

      if (participant.profilePictureUrl != null &&
          participant.profilePictureUrl!.isNotEmpty) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: participant.profilePictureUrl!,
            fit: BoxFit.cover,
            height: 35,
            width: 35,
            placeholder: (context, url) => const SizedBox(),
            errorWidget: (context, url, error) {
              // For AI fallback to AI icon, for users fallback to initials
              if (sender.type == 'ai') {
                return const Center(
                  child:
                      Icon(Icons.smart_toy, color: Colors.blueAccent, size: 35),
                );
              } else {
                return Center(
                  child: Text(
                    sender.name.isNotEmpty ? sender.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
            },
          ),
        );
      }
    }

    // Fallback based on user type
    if (sender.type == 'ai') {
      return const Center(
        child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 35),
      );
    } else {
      // For regular users with no profile image
      return Center(
        child: Text(
          sender.name.isNotEmpty ? sender.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(dateTime.toLocal());
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime.toLocal());
    }
  }

  // Method to show the participants dialog
  void _showParticipantsDialog(BuildContext context) {
    // Track participants dialog viewing
    _sessionActivities.add('participants_viewed');
    AppsFlyerService().logEvent('group_chat_participants_viewed', {
      'group_id': _groupId,
      'group_name': widget.group.name,
      'user_id': _currentUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: GroupChatService.getGroupChatStreamById(_groupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text('No data available')),
                );
              }

              try {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final List<dynamic> participantsData =
                    data['participants'] ?? [];
                List<Participant> participants =
                    _parseParticipantsList(participantsData);

                // Sort participants with AI first, then alphabetically by name
                participants.sort((a, b) {
                  if (a.type == 'ai' && b.type != 'ai') return -1;
                  if (a.type != 'ai' && b.type == 'ai') return 1;
                  return a.name.compareTo(b.name);
                });

                final groupName = data['name'] ?? widget.group.name;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Participants',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              context.pop();
                            },
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              child: Center(
                                child: Icon(
                                  FeatherIcons.x,
                                  size: 18,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Group: $groupName',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                        ),
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: participants.length,
                          itemBuilder: (context, index) {
                            final participant = participants[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                child: _buildParticipantAvatar(participant),
                              ),
                              title: Text(
                                participant.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                participant.type == 'ai'
                                    ? 'AI Assistant'
                                    : 'User',
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: participant.type == 'ai'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blueAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'AI',
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () {
                                        _showReportDialog(context, participant);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Report',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Information text about participants
                      Text(
                        'AI participants have special knowledge about the group topic.',
                        // Original text: 'Some AI participants have special knowledge about the group topic.'
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.flag,
                            size: 16,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Report",
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              } catch (e) {
                print('Error parsing participants data: $e');
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(child: Text('Error parsing data: $e')),
                );
              }
            },
          ),
        );
      },
    );
  }

  // Helper method to parse participants
  List<Participant> _parseParticipantsList(List<dynamic> participantsData) {
    return participantsData.map((participant) {
      if (participant is Map) {
        Map<String, dynamic> participantMap =
            participant.cast<String, dynamic>();

        // If this is a user (AI or regular) and we have a cached profile picture, add it to the map
        if (participantMap['uid'] != null &&
            _userProfileImages.containsKey(participantMap['uid'])) {
          print(
              'Adding cached profile picture to participant: ${participantMap['uid']}');
          participantMap['profilePictureUrl'] =
              _userProfileImages[participantMap['uid']];
        }

        return Participant.fromMap(participantMap);
      } else {
        // Return a default participant if the format is unexpected
        return Participant(uid: '', type: 'unknown', name: 'Unknown');
      }
    }).toList();
  }

  // Build avatar for participant
  Widget _buildParticipantAvatar(Participant participant) {
    // For Messi (special AI user), use Barcelona crest
    if (participant.type == 'ai' && participant.name == 'Lionel Messi') {
      return const Center(
        child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 24),
      );
    }

    // For regular users, check cached profile pictures first
    if (participant.type == 'user' &&
        _userProfileImages.containsKey(participant.uid)) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _userProfileImages[participant.uid]!,
          fit: BoxFit.cover,
          width: 24,
          height: 24,
          placeholder: (context, url) => const SizedBox(),
          errorWidget: (context, url, error) {
            return Center(
              child: Text(
                participant.name.isNotEmpty
                    ? participant.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      );
    }

    // For both AI and regular users, try to use profile picture if available
    if (participant.profilePictureUrl != null &&
        participant.profilePictureUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: participant.profilePictureUrl!,
          fit: BoxFit.cover,
          width: 24,
          height: 24,
          placeholder: (context, url) => const SizedBox(),
          errorWidget: (context, url, error) {
            // Different fallbacks based on user type
            if (participant.type == 'ai') {
              return const Center(
                child:
                    Icon(Icons.smart_toy, color: Colors.blueAccent, size: 24),
              );
            } else {
              return Center(
                child: Text(
                  participant.name.isNotEmpty
                      ? participant.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }
          },
        ),
      );
    }

    // Fallback based on user type
    if (participant.type == 'ai') {
      // Fallback to AI icon if no profile image is found
      return const Center(
        child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 24),
      );
    } else {
      // For regular users with no profile image
      return Center(
        child: Text(
          participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  // Method to join a group chat with InCash payment
  Future<void> _joinGroup(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'You need to be logged in to join this group',
      );
      return;
    }

    // Show confirmation dialog with the cost
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Join ${widget.group.name}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            content: Text(
                'Joining this group will cost $_joinGroupCost InCash. Do you want to continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Join'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Call the backend to spend InCash and join the group
      final monetizationService = MonetizationService();
      final response = await monetizationService.spendInCashForGroupAccess(
          _groupId, _joinGroupCost);

      // Close loading dialog
      Navigator.of(context).pop();

      if (response['success'] == true) {
        // Create or update the conversation document to include this user
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(_groupId)
            .set({
          'isGroupChat': true,
          'groupName': widget.group.name,
          'participants': FieldValue.arrayUnion([currentUserId]),
          'lastMessage': 'You joined the group',
          'lastMessageTime': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Track successful group join with payment
        AppsFlyerService().logEvent('group_chat_join_success', {
          'group_id': _groupId,
          'group_name': widget.group.name,
          'user_id': currentUserId,
          'join_method': 'payment',
          'cost_paid': _joinGroupCost,
          'member_count_after_join': widget.group.memberCount + 1,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        _sessionActivities.add('group_joined_with_payment');

        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.checkCircle,
            color: Colors.greenAccent,
          ),
          message: 'Successfully joined the group!',
        );
      } else {
        // Show insufficient InCash popup if the error is about insufficient balance
        if (response['error']
                ?.toString()
                .toLowerCase()
                .contains('insufficient balance') ==
            true) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("You don't have enough InCash"),
              content: const Text(
                "You need InCash to join this group chat. Get more InCash or refer a friend to earn some!",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    try {
                      presentPaywall();
                    } catch (e) {
                      ToastService.showToast(
                        context,
                        backgroundColor: Theme.of(context).canvasColor,
                        shadowColor: Colors.transparent,
                        leading: const Icon(
                          FeatherIcons.xCircle,
                          color: Colors.redAccent,
                        ),
                        message: 'Error opening purchase options: $e',
                      );
                    }
                  },
                  child: const Text("Get more"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(Routes.referral);
                  },
                  child: const Text("Refer a friend"),
                ),
              ],
            ),
          );
        } else {
          // Show generic error message for other errors using ToastService
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.xCircle,
              color: Colors.redAccent,
            ),
            message: response['error'] ?? 'Failed to join the group',
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (context.mounted) Navigator.of(context).pop();

      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Error joining group: $e',
      );
    }
  }

  // Show a dialog to report a participant
  void _showReportDialog(BuildContext context, Participant participant) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Report ${participant.name}'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Enter the reason for reporting',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isNotEmpty) {
                  await _submitGroupParticipantReport(participant, reason);
                  context.pop();

                  ToastService.showToast(
                    context,
                    backgroundColor: Theme.of(context).canvasColor,
                    shadowColor: Colors.transparent,
                    leading: const Icon(
                      FeatherIcons.checkCircle,
                      color: Colors.greenAccent,
                    ),
                    message: "Report submitted.",
                  );
                  context.pop();
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  // Submit group chat participant report to Firestore
  Future<void> _submitGroupParticipantReport(
      Participant participant, String reason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid.isNotEmpty) {
        final groupId = _groupId;
        final reportedUserId = participant.uid;
        final reporterUserId = currentUser.uid;

        // Check if a report for this group/user already exists
        final querySnapshot = await FirebaseFirestore.instance
            .collection('reportGroupParticipant')
            .where('groupId', isEqualTo: groupId)
            .where('reportedUserId', isEqualTo: reportedUserId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Report exists, increment count and update arrays
          final existingReport = querySnapshot.docs.first;
          final int currentCount = existingReport['count'] ?? 0;

          List<dynamic> existingReasons = existingReport['reasons'] ?? [];
          if (existingReasons is String) existingReasons = [existingReasons];

          List<dynamic> existingReporters = existingReport['reporters'] ?? [];
          if (existingReporters is String)
            existingReporters = [existingReporters];

          List<dynamic> existingDates = existingReport['dates'] ?? [];

          existingReasons.add(reason);
          existingReporters.add(reporterUserId);
          existingDates.add(Timestamp.now());

          await existingReport.reference.update({
            'count': currentCount + 1,
            'reasons': existingReasons,
            'reporters': existingReporters,
            'dates': existingDates,
          });
        } else {
          // Create new report
          final reportDocRef = FirebaseFirestore.instance
              .collection('reportGroupParticipant')
              .doc();
          await reportDocRef.set({
            'groupId': groupId,
            'reportedUserId': reportedUserId,
            'reporters': [reporterUserId],
            'reasons': [reason],
            'dates': [Timestamp.now()],
            'count': 1,
          });
        }
      }
    } catch (e) {
      print('Error submitting group participant report: $e');
    }
  }
}

// Models for sample data
class GroupChatUser {
  final String id;
  final String name;
  final String avatar;

  GroupChatUser({
    required this.id,
    required this.name,
    required this.avatar,
  });
}

class GroupMessage {
  final String id;
  final GroupChatUser sender;
  final String text;
  final DateTime timestamp;

  GroupMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
  });
}
