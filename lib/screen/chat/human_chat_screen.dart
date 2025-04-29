import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/chat/chat_app_bar.dart';
import 'package:inzone/components/chat/chat_input.dart';
import 'package:inzone/components/chat/date_header.dart';
import 'package:inzone/components/chat/message_bubble.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/theme/light_theme.dart';
import 'package:intl/intl.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

class HumanChatScreen extends StatefulWidget {
  final String conversationId; // Unique ID for this conversation
  final String otherUserName; // Name of the person we're chatting with
  final String otherUserId; // ID of the person we're chatting with

  const HumanChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<HumanChatScreen> createState() => _HumanChatScreenState();
}

class _HumanChatScreenState extends State<HumanChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? currentUserId;
  String currentUserName = "Me";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    // Get current user ID
    currentUserId = await InZoneDatabase.getCurrentUserUid();

    // Try to get current user's name
    if (currentUserId != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('humanUsers').doc(currentUserId).get();

      if (userDoc.exists && userDoc.data() != null) {
        var userData = userDoc.data() as Map<String, dynamic>;
        currentUserName = userData['name'] ?? userData['Name'] ?? "Me";
      }
    }

    setState(() {
      isLoading = false;
    });

    // Scroll to bottom when messages load
    _scrollToEnd();
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty || currentUserId == null) return;

    // Reference to the conversation document
    final conversationRef =
        _firestore.collection('conversations').doc(widget.conversationId);

    // Create a new message document
    final newMessage = {
      'text': _msgController.text.trim(),
      'senderId': currentUserId,
      'senderName': currentUserName,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    try {
      // Add message to the messages subcollection
      await conversationRef.collection('messages').add(newMessage);

      // Update conversation metadata
      await conversationRef.set({
        'lastMessage': _msgController.text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [currentUserId, widget.otherUserId],
        'participantNames': {
          currentUserId: currentUserName,
          widget.otherUserId: widget.otherUserName,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _msgController.clear();
      _scrollToEnd();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to send message. Please try again.')));
    }
  }

  void _scrollToEnd() {
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
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.otherUserName),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: ChatAppBar(
        title: widget.otherUserName,
        avatarId: widget.otherUserId,
        avatarUrl: widget.otherUserName,
        onBack: () => context.pop(),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("No messages yet. Say hello!"));
                }

                final messages = snapshot.data!.docs;

                // Group messages by date
                Map<String, List<DocumentSnapshot>> messagesByDate = {};

                for (var message in messages) {
                  var messageData = message.data() as Map<String, dynamic>;
                  Timestamp? timestamp = messageData['timestamp'] as Timestamp?;

                  if (timestamp != null) {
                    final DateTime dateTime = timestamp.toDate();
                    final String dateKey = _getDateKey(dateTime);

                    if (!messagesByDate.containsKey(dateKey)) {
                      messagesByDate[dateKey] = [];
                    }

                    messagesByDate[dateKey]!.add(message);
                  } else {
                    // Handle messages without timestamp
                    const String dateKey = 'No Date';
                    if (!messagesByDate.containsKey(dateKey)) {
                      messagesByDate[dateKey] = [];
                    }
                    messagesByDate[dateKey]!.add(message);
                  }
                }

                // Create a list of widgets with date headers and messages
                List<Widget> messageWidgets = [];

                messagesByDate.forEach((dateKey, messageDocs) {
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Undated Messages',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // Add messages for this date
                  for (var message in messageDocs) {
                    var messageData = message.data() as Map<String, dynamic>;
                    String senderId = messageData['senderId'] ?? '';
                    String messageText = messageData['text'] ?? '';
                    String senderName = messageData['senderName'] ?? '';
                    Timestamp? timestamp =
                        messageData['timestamp'] as Timestamp?;

                    // Check if message is from current user
                    bool isMe = senderId == currentUserId;
                    DateTime? messageDateTime = timestamp?.toDate();

                    messageWidgets.add(
                      MessageBubble(
                        message: messageText,
                        isMe: isMe,
                        timestamp: messageDateTime,
                        senderName: isMe ? null : senderName,
                        senderAvatar: isMe
                            ? null
                            : ClipOval(
                                child: Container(
                                  width: 35,
                                  height: 35,
                                  color: Theme.of(context).cardColor,
                                  child: RandomAvatar(
                                    senderId,
                                    height: 35,
                                    width: 35,
                                  ),
                                ),
                              ),
                      ),
                    );
                  }
                });

                return ListView(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  children: messageWidgets,
                );
              },
            ),
          ),
          ChatInput(
            controller: _msgController,
            onSend: _sendMessage,
          ),
        ],
      ),
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
}
