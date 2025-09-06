import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inzone/components/chat/chat_app_bar.dart';
import 'package:inzone/components/chat/chat_input.dart';
import 'package:inzone/components/chat/date_header.dart';
import 'package:inzone/components/chat/message_bubble.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/notification_event_service.dart';
import 'package:inzone/services/notification_service.dart';
import 'package:inzone/theme/light_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:toasty_box/toast_service.dart';

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
  String _otherUserProfileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadOtherUserProfileImage();
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

  Future<void> _loadOtherUserProfileImage() async {
    try {
      if (widget.otherUserId.isEmpty) return;

      // First try from API
      final userData = await InZoneDatabase.getUserProfile(widget.otherUserId);
      if (userData != null &&
          userData['profilePicture'] != null &&
          userData['profilePicture'].toString().isNotEmpty &&
          mounted) {
        setState(() {
          _otherUserProfileImageUrl = userData['profilePicture'];
        });
        return;
      }

      // If API doesn't return a profile image or returns empty, try Firestore directly
      final userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(widget.otherUserId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userDocData = userDoc.data()!;
        final profilePic =
            userDocData['profilePicture'] ?? userDocData['profileImage'] ?? "";

        if (mounted && profilePic.toString().isNotEmpty) {
          setState(() {
            _otherUserProfileImageUrl = profilePic.toString();
          });
        }
      }
    } catch (e) {
      print('Error loading other user profile image: $e');
    }
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

      // Trigger DM notification event
      await NotificationEventService.onDirectMessage(
        widget.conversationId,
        _msgController.text.trim(),
        currentUserId!,
        widget.otherUserId,
      // Trigger DM notification
      // await NotificationService.sendDirectMessageNotification(
      //   chatId: widget.conversationId,
      //   content: _msgController.text.trim(),
      //   senderId: currentUserId!,
      //   receiverId: widget.otherUserId,
      );

      // Fallback: ensure a notification doc exists in Firestore for the receiver even if the event endpoint is delayed or fails. Resolve the receiver to a canonical humanUsers uid (doc/uid/username) and write a deduplicated `direct_message` notification.
      try {
        final notifRef = FirebaseFirestore.instance.collection('notifications');

        final humanUsersRef = FirebaseFirestore.instance.collection('humanUsers');
        DocumentSnapshot? receiverDoc;
        String? resolvedReceiverUid;
        String resolvedReceiverName = widget.otherUserName;

        try {
          final byId = await humanUsersRef.doc(widget.otherUserId).get();
          if (byId.exists) {
            receiverDoc = byId;
          } else {
            final q1 = await humanUsersRef.where('username', isEqualTo: widget.otherUserId).limit(1).get();
            if (q1.docs.isNotEmpty) {
              receiverDoc = q1.docs.first;
            } else {
              final q2 = await humanUsersRef.where('uid', isEqualTo: widget.otherUserId).limit(1).get();
              if (q2.docs.isNotEmpty) {
                receiverDoc = q2.docs.first;
              } else {
                final q3 = await humanUsersRef.where('user_document_id', isEqualTo: widget.otherUserId).limit(1).get();
                if (q3.docs.isNotEmpty) receiverDoc = q3.docs.first;
              }
            }
          }

          if (receiverDoc != null && receiverDoc.exists) {
            final data = receiverDoc.data() as Map<String, dynamic>;
            resolvedReceiverUid = data['uid'] ?? receiverDoc.id;
            resolvedReceiverName = data['name'] ?? data['username'] ?? resolvedReceiverName;
            debugPrint('Resolved DM receiver "${widget.otherUserId}" -> uid: $resolvedReceiverUid name: $resolvedReceiverName');
          } else {
            debugPrint('Could not resolve DM receiver "${widget.otherUserId}" to humanUsers doc; skipping fallback notification');
          }
        } catch (e) {
          debugPrint('Error resolving receiver for DM fallback notification: $e');
        }

        if (resolvedReceiverUid != null && resolvedReceiverUid != currentUserId) {
          final query = await notifRef
              .where('userId', isEqualTo: resolvedReceiverUid)
              .where('data.chatId', isEqualTo: widget.conversationId)
              .where('data.senderId', isEqualTo: currentUserId)
              .limit(1)
              .get();

          if (query.docs.isEmpty) {
            final bodyText = _msgController.text.trim();
            final added = await notifRef.add({
              'userId': resolvedReceiverUid,
              'type': 'direct_message',
              'title': currentUserName,
              'body': bodyText.length > 100 ? '${bodyText.substring(0, 100)}...' : bodyText,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
              'data': {
                'chatId': widget.conversationId,
                'senderId': currentUserId,
                'senderName': currentUserName,
                'messageContent': bodyText,
              },
              // deeplink removed per notification deeplink deprecation
            });

            debugPrint('Fallback DM notification written: ${added.id} -> user $resolvedReceiverUid');
          }
        }
      } catch (e) {
        debugPrint('Failed to write fallback DM notification: $e');
      }

      _msgController.clear();
      _scrollToEnd();
    } catch (e) {
      print('Error sending message: $e');
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          Icons.error,
          color: Colors.redAccent,
        ),
        message: 'Failed to send message. Please try again.',
      );
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
          leadingWidth: 50,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: GestureDetector(
              onTap: () {
                context.pop();
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
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
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: ChatAppBar(
        title: widget.otherUserName,
        avatarId: widget.otherUserId,
        avatarUrl: _otherUserProfileImageUrl,
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
                    final DateTime dateTime = timestamp.toDate().toUtc();
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Updated Messages',
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
                    DateTime? messageDateTime = timestamp?.toDate().toUtc();

                    messageWidgets.add(
                      MessageBubble(
                        message: messageText,
                        isMe: isMe,
                        timestamp: messageDateTime,
                        senderName: isMe ? null : senderName,
                        senderAvatar: isMe
                            ? null
                            : Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).cardColor,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _otherUserProfileImageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: _otherUserProfileImageUrl,
                                        width: 35,
                                        height: 35,
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: Icon(Icons.account_circle,
                                            size: 35),
                                      ),
                              ),
                      ),
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  itemCount: messageWidgets.length,
                  itemBuilder: (context, index) {
                    return messageWidgets[index];
                  },
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
}
