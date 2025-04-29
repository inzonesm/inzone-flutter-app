import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:random_avatar/random_avatar.dart';
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

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;

    // Send message to Firestore, using the specific group ID
    GroupChatService.sendMessageToGroup(_groupId, _msgController.text.trim());

    _msgController.clear();
    _scrollToBottom();
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
            Widget groupAvatar =
                RandomAvatar(widget.group.name, height: 40, width: 40);

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
                    groupAvatar = ClipOval(
                      child: Image.network(
                        imageUrl,
                        height: 40,
                        width: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading group image: $error');
                          // Fallback to RandomAvatar if image fails to load
                          return RandomAvatar(groupName, height: 40, width: 40);
                        },
                      ),
                    );
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
                onPressed: () => context.pop(),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xffFFE2A9),
                        width: 1.5,
                      ),
                    ),
                    child: groupAvatar,
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
                IconButton(
                  icon: Icon(Icons.more_vert,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    // Show group options
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

                    print('Found ${messagesData.length} messages in Firestore');

                    // Convert the data to GroupChatData
                    _groupChatData = GroupChatData.fromSnapshot(snapshot.data!);

                    if (_groupChatData!.messages.isEmpty) {
                      print('Messages parsed but resulted in empty list');
                      return const Center(
                        child: Text(
                            'No messages parsed correctly. Check data format.'),
                      );
                    }

                    print(
                        'Parsed ${_groupChatData!.messages.length} messages successfully');

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

    print('Building message list with ${messages.length} messages');

    // Create a single list of widgets if there are no timestamps
    bool hasTimestamps = messages.any((msg) => msg.timestamp != null);

    if (!hasTimestamps) {
      print(
          'No message timestamps found, showing messages without date grouping');
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
      senderAvatar: ClipOval(
        child: Container(
          width: 35,
          height: 35,
          color: Theme.of(context).cardColor,
          child: _buildSenderAvatar(message.sender),
        ),
      ),
    );
  }

  // Build sender avatar based on type
  Widget _buildSenderAvatar(MessageSender sender) {
    // For Messi (special AI user), use Barcelona crest
    if (sender.type == 'ai' && sender.name == 'Lionel Messi') {
      return Image.network(
        "https://upload.wikimedia.org/wikipedia/sco/4/47/FC_Barcelona_%28crest%29.svg",
        fit: BoxFit.cover,
        height: 35,
        width: 35,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading Messi avatar: $error');
          return RandomAvatar(sender.uid, height: 35, width: 35);
        },
      );
    }

    // For other AI users, check if group has an image
    if (sender.type == 'ai' && _groupChatData?.imageUrl.isNotEmpty == true) {
      return Image.network(
        _groupChatData!.imageUrl,
        fit: BoxFit.cover,
        height: 35,
        width: 35,
        errorBuilder: (context, error, stackTrace) {
          return RandomAvatar(sender.uid, height: 35, width: 35);
        },
      );
    }

    // For regular users, use a random avatar based on UID
    return RandomAvatar(sender.uid, height: 35, width: 35);
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
