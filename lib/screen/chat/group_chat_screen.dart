import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
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

    // Update the group's isMember status if not already a member
    if (!widget.group.isMember) {
      widget.group.isMember = true;
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
    _msgController.clear();

    // Get current user ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      // Handle not logged in case
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to send messages')),
      );
      return;
    }

    // Check if user has paid for the group chat
    final hasPaid = await _hasPaidForGroup();
    if (!hasPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('You need to join this group before sending messages')),
      );
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
          'updatedAt': Timestamp.now(),
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
                      child: Image.network(
                        imageUrl,
                        height: 40,
                        width: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
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
                        child: Image.network(
                          avatars[0].toString(),
                          height: 40,
                          width: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
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
              leadingWidth: 30,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () {
                  try {
                    context.pop();
                  } catch (e) {
                    // Fallback to Navigator if Go Router fails
                    Navigator.of(context).pop();
                  }
                },
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
        final now = DateTime.now();
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
                  'Undated Messages',
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(dateTime);
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isMe =
        message.sender.uid == FirebaseAuth.instance.currentUser?.uid;

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

    // For AI users, fetch their profile image from aiUsers collection
    if (sender.type == 'ai' && sender.uid.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('aiUsers')
            .doc(sender.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 35),
            );
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            final aiUserData = snapshot.data!.data() as Map<String, dynamic>?;
            final profileImage = aiUserData?['profilePicture'] ?? 
                                 aiUserData?['profileImage'] ?? 
                                 aiUserData?['character']?['profilePicture'];

            if (profileImage != null && profileImage.toString().isNotEmpty) {
              return ClipOval(
                child: Image.network(
                  profileImage.toString(),
                  fit: BoxFit.cover,
                  height: 35,
                  width: 35,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.smart_toy,
                          color: Colors.blueAccent, size: 35),
                    );
                  },
                ),
              );
            }
          }

          // Fallback to AI icon if no profile image is found
          return const Center(
            child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 35),
          );
        },
      );
    }

    // For human users, try to load their profile image from Firebase
    if (sender.type != 'ai' && sender.uid.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(sender.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Icon(Icons.account_circle,
                  color: Colors.blueAccent, size: 35),
            );
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final profileImage =
                userData?['profilePicture'] ?? userData?['profileImage'];

            if (profileImage != null && profileImage.toString().isNotEmpty) {
              return ClipOval(
                child: Image.network(
                  profileImage.toString(),
                  fit: BoxFit.cover,
                  height: 35,
                  width: 35,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.account_circle,
                          color: Colors.blueAccent, size: 35),
                    );
                  },
                ),
              );
            }
          }

          // Fallback to icon if no profile image is found
          return const Center(
            child:
                Icon(Icons.account_circle, color: Colors.blueAccent, size: 35),
          );
        },
      );
    }

    // Fallback to icon
    return const Center(
      child: Icon(Icons.account_circle, color: Colors.blueAccent, size: 35),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(dateTime);
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  // Method to show the participants dialog
  void _showParticipantsDialog(BuildContext context) {
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

                // MODIFIED: Filter to only show AI participants
                // Original code (commented out for future use):
                /*
                // Sort participants - AI participants first, then others
                participants.sort((a, b) {
                  if (a.type == 'ai' && b.type != 'ai') {
                    return -1; // a comes before b
                  } else if (a.type != 'ai' && b.type == 'ai') {
                    return 1; // b comes before a
                  } else {
                    // If both same type, sort alphabetically by name
                    return a.name.compareTo(b.name);
                  }
                });
                */

                // New code: Filter to only show AI participants
                participants =
                    participants.where((p) => p.type == 'ai').toList();
                // Sort AI participants alphabetically by name
                participants.sort((a, b) => a.name.compareTo(b.name));

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
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
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
                                  : null,
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
        return Participant.fromMap(participant.cast<String, dynamic>());
      } else {
        // Return a default participant if the format is unexpected
        return Participant(uid: '', type: 'unknown', name: 'Unknown');
      }
    }).toList();
  }

  // Build avatar for participant
  // Method to join a group chat with InCash payment
  Future<void> _joinGroup(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to join this group')),
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the group!')),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Error opening purchase options: $e')),
                      );
                    }
                  },
                  child: const Text("Get more"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/referral');
                  },
                  child: const Text("Refer a friend"),
                ),
              ],
            ),
          );
        } else {
          // Show generic error message for other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(response['error'] ?? 'Failed to join the group')),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (context.mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining group: $e')),
      );
    }
  }

  Widget _buildParticipantAvatar(Participant participant) {
    // For Messi (special AI user), use Barcelona crest
    if (participant.type == 'ai' && participant.name == 'Lionel Messi') {
      return const Center(
        child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 24),
      );
    }

    // For AI users, fetch their profile image from aiUsers collection
    if (participant.type == 'ai' && participant.uid.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('aiUsers')
            .doc(participant.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 24),
            );
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            final aiUserData = snapshot.data!.data() as Map<String, dynamic>?;
            final profileImage = aiUserData?['profilePicture'] ?? 
                                 aiUserData?['profileImage'] ?? 
                                 aiUserData?['character']?['profilePicture'];

            if (profileImage != null && profileImage.toString().isNotEmpty) {
              return ClipOval(
                child: Image.network(
                  profileImage.toString(),
                  fit: BoxFit.cover,
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.smart_toy,
                          color: Colors.blueAccent, size: 24),
                    );
                  },
                ),
              );
            }
          }

          // Fallback to AI icon if no profile image is found
          return const Center(
            child: Icon(Icons.smart_toy, color: Colors.blueAccent, size: 24),
          );
        },
      );
    }

    // For regular users
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
