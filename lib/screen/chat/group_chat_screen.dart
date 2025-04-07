import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:inzone/data/group_data.dart';
import 'package:intl/intl.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupData group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final bool _isLoading = false;

  // Sample data for messages
  final List<GroupMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadSampleMessages();

    // Update the group's isMember status if not already a member
    if (!widget.group.isMember) {
      widget.group.isMember = true;
    }
  }

  void _loadSampleMessages() {
    // Create sample users
    final List<GroupChatUser> sampleUsers = [
      GroupChatUser(
        id: '1',
        name: 'Emma Watson',
        avatar: 'emma',
      ),
      GroupChatUser(
        id: '2',
        name: 'Daniel Radcliffe',
        avatar: 'daniel',
      ),
      GroupChatUser(
        id: '3',
        name: 'Rupert Grint',
        avatar: 'rupert',
      ),
      GroupChatUser(
        id: 'current',
        name: 'Me',
        avatar: 'current',
      ),
    ];

    // Sample messages
    final List<GroupMessage> sampleMessages = [
      GroupMessage(
        id: '1',
        sender: sampleUsers[0],
        text: 'Welcome to the ${widget.group.name} group!',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      ),
      GroupMessage(
        id: '2',
        sender: sampleUsers[1],
        text: 'Hey everyone! Excited to join this group.',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 2)),
      ),
      GroupMessage(
        id: '3',
        sender: sampleUsers[2],
        text: 'Same here! What are we discussing today?',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
      ),
      GroupMessage(
        id: '4',
        sender: sampleUsers[0],
        text:
            'I think we should talk about the latest developments in our community.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      ),
      GroupMessage(
        id: '5',
        sender: sampleUsers[1],
        text: 'Has anyone seen the new announcement?',
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      GroupMessage(
        id: '6',
        sender: sampleUsers[2],
        text:
            'Yes! It was really exciting. I think it will change how we interact with each other.',
        timestamp: DateTime.now().subtract(const Duration(hours: 11)),
      ),
      GroupMessage(
        id: '7',
        sender: sampleUsers[0],
        text: 'I agree. The new features look promising.',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];

    setState(() {
      _messages.addAll(sampleMessages);
    });
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(
        GroupMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: GroupChatUser(
            id: 'current',
            name: 'Me',
            avatar: 'current',
          ),
          text: _msgController.text.trim(),
          timestamp: DateTime.now(),
        ),
      );
    });

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
      backgroundColor: Theme.of(context).canvasColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).canvasColor,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
            ),
            color: Colors.black,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Row(
            children: [
              Container(
                height: 35,
                width: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade200,
                ),
                child: Icon(
                  Icons.group,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.group.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    style: BorderStyle.solid,
                    width: 10.0,
                  ),
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                    topLeft: Radius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMessageList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: Colors.white,
              child: _buildChatInput(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    // Group messages by date
    Map<String, List<GroupMessage>> messagesByDate = {};

    for (var message in _messages) {
      final String dateKey = _getDateKey(message.timestamp);

      if (!messagesByDate.containsKey(dateKey)) {
        messagesByDate[dateKey] = [];
      }

      messagesByDate[dateKey]!.add(message);
    }

    // Create a list of widgets with date headers and messages
    List<Widget> messageWidgets = [];

    messagesByDate.forEach((dateKey, messages) {
      // Add date header
      messageWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                dateKey,
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

  Widget _buildMessageBubble(GroupMessage message) {
    final bool isMe = message.sender.id == 'current';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            RandomAvatar(
              message.sender.avatar,
              height: 35,
              width: 35,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                    child: Text(
                      message.sender.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // if (isMe) ...[
          //   const SizedBox(width: 8),
          //   RandomAvatar(
          //     message.sender.avatar,
          //     height: 35,
          //     width: 35,
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 8, bottom: 30, top: 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: TextField(
                controller: _msgController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(10),
                  border: InputBorder.none,
                  hintText: 'Send a message',
                  filled: true,
                  fillColor: Colors.blue.withOpacity(0.2),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
          MaterialButton(
            minWidth: 43,
            height: 43,
            color: Colors.blue,
            shape: const CircleBorder(),
            onPressed: _sendMessage,
            child: const Center(
              child: Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
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
