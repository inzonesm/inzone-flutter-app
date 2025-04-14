import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/ui/appbar.dart';
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
    // Create sample users based on the group theme
    List<GroupChatUser> sampleUsers = [];
    
    // Generate themed users and messages based on group name
    if (widget.group.name == 'Hogwarts') {
      sampleUsers = [
        GroupChatUser(id: '1', name: 'Harry Potter', avatar: 'Harry'),
        GroupChatUser(id: '2', name: 'Hermione Granger', avatar: 'Hermione'),
        GroupChatUser(id: '3', name: 'Ron Weasley', avatar: 'Ron'),
      ];
    } else if (widget.group.name == 'Assemble') {
      sampleUsers = [
        GroupChatUser(id: '1', name: 'Tony Stark', avatar: 'Tony'),
        GroupChatUser(id: '2', name: 'Steve Rogers', avatar: 'Steve'),
        GroupChatUser(id: '3', name: 'Thor', avatar: 'Thor'),
      ];
    } else if (widget.group.name == 'Superstars') {
      sampleUsers = [
        GroupChatUser(id: '1', name: 'LeBron James', avatar: 'Lebron'),
        GroupChatUser(id: '2', name: 'Lionel Messi', avatar: 'Messi'),
        GroupChatUser(id: '3', name: 'Serena Williams', avatar: 'Serena'),
      ];
    } else if (widget.group.name == 'Anime') {
      sampleUsers = [
        GroupChatUser(id: '1', name: 'Naruto Uzumaki', avatar: 'Naruto'),
        GroupChatUser(id: '2', name: 'Goku', avatar: 'Goku'),
        GroupChatUser(id: '3', name: 'Monkey D. Luffy', avatar: 'Luffy'),
      ];
    } else {
      // Default users for any other group
      sampleUsers = [
        GroupChatUser(id: '1', name: 'Emma Watson', avatar: 'emma'),
        GroupChatUser(id: '2', name: 'Daniel Radcliffe', avatar: 'daniel'),
        GroupChatUser(id: '3', name: 'Rupert Grint', avatar: 'rupert'),
      ];
    }
    
    // Add current user to all groups
    sampleUsers.add(GroupChatUser(id: 'current', name: 'Me', avatar: 'current'));

    // Create themed messages based on the group
    List<String> welcomeMessages = [];
    List<String> discussionTopics = [];
    
    if (widget.group.name == 'Hogwarts') {
      welcomeMessages = [
        'Welcome to Hogwarts! Remember, the forbidden forest is strictly off-limits.',
        'Hey everyone! Has anyone seen my wand?',
        'Quidditch practice at 5pm today!'
      ];
      discussionTopics = [
        'Did you see the latest announcement about the Triwizard Tournament?',
        'Snape assigned way too much homework this week.',
        'Anyone want to visit Hogsmeade this weekend?',
        'The password to the common room has been changed to "Fizzing Whizbees".'
      ];
    } else if (widget.group.name == 'Assemble') {
      welcomeMessages = [
        'Avengers, assemble!',
        'Hey team, who\'s got monitor duty tonight?',
        'New mission briefing in 30 minutes.'
      ];
      discussionTopics = [
        'Has anyone seen my shield?',
        'Tony, can you upgrade my suit?',
        'Thor, we need to talk about your hammer being left in the middle of the living room.',
        'Anyone heard from Fury lately?'
      ];
    } else if (widget.group.name == 'Superstars') {
      welcomeMessages = [
        'Welcome to the Superstars group!',
        'Who\'s watching the big game tonight?',
        'Training schedule has been updated for next week.'
      ];
      discussionTopics = [
        'That was an incredible match yesterday!',
        'Any tips for improving my vertical jump?',
        'New equipment arriving next week.',
        'Who\'s your pick for rookie of the year?'
      ];
    } else if (widget.group.name == 'Anime') {
      welcomeMessages = [
        'Welcome to the Anime group!',
        'What\'s everyone watching this season?',
        'New episodes dropping today!'
      ];
      discussionTopics = [
        'That plot twist in the latest episode was crazy!',
        'Who\'s your favorite character and why?',
        'Are you going to the convention next month?',
        'Do you prefer sub or dub?'
      ];
    } else {
      welcomeMessages = [
        'Welcome to the ${widget.group.name} group!',
        'Hey everyone! Excited to join this group.',
        'Same here! What are we discussing today?'
      ];
      discussionTopics = [
        'I think we should talk about the latest developments in our community.',
        'Has anyone seen the new announcement?',
        'Yes! It was really exciting. I think it will change how we interact with each other.',
        'I agree. The new features look promising.'
      ];
    }

    // Create the sample messages with the themed content
    List<GroupMessage> sampleMessages = [];
    
    // Add welcome messages from 2-3 days ago
    for (int i = 0; i < welcomeMessages.length && i < sampleUsers.length; i++) {
      sampleMessages.add(
        GroupMessage(
          id: i.toString(),
          sender: sampleUsers[i],
          text: welcomeMessages[i],
          timestamp: DateTime.now().subtract(Duration(days: 2, hours: 3 - i)),
        ),
      );
    }
    
    // Add discussion topics from yesterday and today
    for (int i = 0; i < discussionTopics.length && i < sampleUsers.length; i++) {
      sampleMessages.add(
        GroupMessage(
          id: (i + welcomeMessages.length).toString(),
          sender: sampleUsers[i % sampleUsers.length],
          text: discussionTopics[i],
          timestamp: DateTime.now().subtract(Duration(hours: 12 - (i * 3))),
        ),
      );
    }

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leadingWidth: 30,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
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
              child: ClipOval(
                child: RandomAvatar(widget.group.name, height: 40, width: 40),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.group.memberCount} members',
                    style: const TextStyle(
                      color: Colors.grey,
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
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // Show group options
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessageList(),
            ),
            _buildChatInput(),
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
