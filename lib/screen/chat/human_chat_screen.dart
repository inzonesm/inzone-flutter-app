import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:intl/intl.dart';
import 'package:random_avatar/random_avatar.dart';

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
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            RandomAvatar(
              widget.otherUserId,
              height: 40,
              width: 40,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUserName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
                          child: Text(
                            dateKey == 'Today'
                                ? 'Today'
                                : dateKey == 'Yesterday'
                                    ? 'Yesterday'
                                    : dateKey,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );

                  // Add messages for this date
                  for (var message in messageDocs) {
                    var messageData = message.data() as Map<String, dynamic>;
                    String senderId = messageData['senderId'] ?? '';
                    String messageText = messageData['text'] ?? '';
                    Timestamp? timestamp =
                        messageData['timestamp'] as Timestamp?;

                    // Check if message is from current user
                    bool isMe = senderId == currentUserId;

                    messageWidgets.add(
                      _messageBubble(
                        messageText,
                        isMe,
                        timestamp,
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
          _chatInput(),
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

  Widget _chatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(String text, bool isMe, Timestamp? timestamp) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Wrap(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFD1E7F0) : Colors.grey[300],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
