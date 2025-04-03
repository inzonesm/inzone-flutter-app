import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inzone/chat_screen.dart';
import 'package:inzone/human_chat_screen.dart';
import 'package:inzone/inzone_database.dart';
import 'package:random_avatar/random_avatar.dart';

class AllChatsScreen extends StatefulWidget {
  const AllChatsScreen({super.key});

  @override
  State<AllChatsScreen> createState() => _AllChatsScreenState();
}

class _AllChatsScreenState extends State<AllChatsScreen> with SingleTickerProviderStateMixin {
  final List<ChatUser> _chatUsers = [];
  List<ChatUser> _groupChats = [];
  bool _isLoading = false;
  String? currentUserId;
  late DateTime _startTime;
  int pageOpened = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _startTime = DateTime.now();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('all_chats_screen', {"timeSpent" : timeSpent.inSeconds,  "pageOpenedCount" : pageOpened});
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    currentUserId = await InZoneDatabase.getCurrentUserUid();
    if (currentUserId != null) {
      _fetchConversations();
    } else {
      setState(() => _isLoading = false);
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _fetchConversations() async {
    _chatUsers.clear();
    _groupChats.clear();
    setState(() => _isLoading = true);

    if (currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    List<ChatUser> allChats = [];
    List<ChatUser> groupChats = [];

    try {
      // Fetch AI user conversations
      List<dynamic>? aiData = await InZoneDatabase.getConversations();
      if (aiData != null) {
        for (var conversation in aiData) {
          ChatUser? aiUser = ChatUser.fromJson(conversation);
          if (aiUser != null) allChats.add(aiUser);
        }
      }

      // Fetch human conversations
      QuerySnapshot conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in conversationsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        
        // Check if this is a group chat
        bool isGroupChat = data['isGroupChat'] ?? false;
        
        if (isGroupChat) {
          // Handle group chat
          String groupName = data['groupName'] ?? 'Group Chat';
          allChats.add(ChatUser(
            name: groupName,
            email: doc.id,
            chatId: doc.id,
            lastMessage: data['lastMessage'],
            lastMessageTime: data['lastMessageTime'],
            isHuman: true,
            isGroupChat: true,
          ));
        } else {
          // Handle individual chat
          List<dynamic> participants = data['participants'] ?? [];
          String? otherUserId = participants.firstWhere(
            (id) => id != currentUserId, 
            orElse: () => null
          );
          
          if (otherUserId != null) {
            Map<String, dynamic> participantNames = data['participantNames'] ?? {};
            String otherUserName = participantNames[otherUserId] ?? 'User';
            
            if (otherUserName == 'User') {
              try {
                DocumentSnapshot userDoc = await _firestore
                    .collection('humanUsers')
                    .doc(otherUserId)
                    .get();
                
                if (userDoc.exists && userDoc.data() != null) {
                  var userData = userDoc.data() as Map<String, dynamic>;
                  otherUserName = userData['name'] ?? userData['Name'] ?? 'User';
                }
              } catch (e) {
                print('Error getting user name: $e');
              }
            }
            
            allChats.add(ChatUser(
              name: otherUserName,
              email: otherUserId,
              chatId: doc.id,
              lastMessage: data['lastMessage'],
              lastMessageTime: data['lastMessageTime'],
              isHuman: true,
              isGroupChat: false,
            ));
          }
        }
      }

      // Sort conversations by lastMessageTime
      allChats.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      // Separate group chats and individual chats
      for (var chat in allChats) {
        if (chat.isGroupChat) {
          groupChats.add(chat);
        } else {
          _chatUsers.add(chat);
        }
      }

      setState(() {
        _groupChats = groupChats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching conversations: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading conversations: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Individual Chats'),
                Tab(text: 'Group Chats'),
              ],
            ),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Individual Chats Tab
                  _buildChatsList(_chatUsers),
                  // Group Chats Tab
                  _buildChatsList(_groupChats),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatsList(List<ChatUser> users) {
    return Container(
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
          : users.isEmpty
              ? const Center(child: Text("No conversations yet"))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return ChatUserCard(
                      userData: users[index],
                      currentUserId: currentUserId ?? '',
                    );
                  },
                ),
    );
  }
}

class ChatUser {
  String? name;
  String? email;
  String? chatId;
  String? profilePictureURL;
  String? lastMessage;
  Timestamp? lastMessageTime;
  bool isHuman;
  bool isGroupChat;

  ChatUser({
    this.name,
    this.email,
    this.chatId,
    this.profilePictureURL,
    this.lastMessage,
    this.lastMessageTime,
    this.isHuman = false,
    this.isGroupChat = false,
  });

  static ChatUser? fromJson(Map<String, dynamic> map) {
    try {
      if (map.containsKey('aiProfile') && map['aiProfile'] != null && map.containsKey('conversationId')) {
        return ChatUser(
          email: map['aiProfile']['username'] ?? '',
          name: map['aiProfile']["name"] ?? '',
          chatId: map['conversationId'],
          profilePictureURL: map['aiProfile']['profilePicture'],
          isHuman: false,
          isGroupChat: false,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class ChatUserCard extends StatefulWidget {
  final ChatUser userData;
  final String currentUserId;

  const ChatUserCard({
    super.key, 
    required this.userData,
    required this.currentUserId,
  });

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard> {
  @override
  Widget build(BuildContext context) {
    String formattedTime = '';
    if (widget.userData.lastMessageTime != null) {
      DateTime messageTime = widget.userData.lastMessageTime!.toDate();
      DateTime now = DateTime.now();
      
      if (now.difference(messageTime).inDays == 0) {
        // Today - show time
        formattedTime = '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
      } else if (now.difference(messageTime).inDays == 1) {
        // Yesterday
        formattedTime = 'Yesterday';
      } else {
        // Other days - show date
        formattedTime = '${messageTime.day}/${messageTime.month}/${messageTime.year}';
      }
    }

    return InkWell(
      onTap: () {
        if (widget.userData.isHuman) {
          // Navigate to human chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HumanChatScreen(
                conversationId: widget.userData.chatId ?? '',
                otherUserName: widget.userData.name ?? 'User',
                otherUserId: widget.userData.email ?? '',
              ),
            ),
          ).then((_) {
            // Refresh the conversation list when returning from chat
            if (mounted) {
              (context.findAncestorStateOfType<_AllChatsScreenState>())?._fetchConversations();
            }
          });
        } else {
          // Navigate to AI chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userData: widget.userData,
              ),
            ),
          );
        }
      },
      child: ListTile(
        leading: Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xffFFE2A9),
              width: 1.5,
            ),
            shape: BoxShape.circle,
          ),
          child: widget.userData.profilePictureURL != null && widget.userData.profilePictureURL!.isNotEmpty
              ? ClipOval(
                child: Image.network(
                  widget.userData.profilePictureURL!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to RandomAvatar if the image fails to load
                    return RandomAvatar(widget.userData.name.toString(), height: 30, width: 30);
                  },
                ),
              )
              : RandomAvatar(widget.userData.name.toString(), height: 30, width: 30),
        ),
        title: Text(
          widget.userData.name ?? 'Unknown',
          style: GoogleFonts.openSans(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: widget.userData.lastMessage != null
            ? Text(
                widget.userData.lastMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.openSans(
                  color: Colors.black45,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              )
            : Text(
                widget.userData.email ?? '',
                maxLines: 1,
                style: GoogleFonts.openSans(
                  color: Colors.black45,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
        trailing: formattedTime.isNotEmpty
            ? Text(
                formattedTime,
                style: GoogleFonts.openSans(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              )
            : null,
      ),
    );
  }
}
