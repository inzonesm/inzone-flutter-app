import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';
import 'package:inzone/router/routes.dart';
import 'package:flutter/cupertino.dart';
// import 'package:inzone/components/ui/inzone_text_field.dart';
// import 'package:inzone/components/ui/my_button.dart';
// import 'package:inzone/models/chat_model.dart';
// import 'package:inzone/models/user_model.dart';
// import 'package:inzone/screen/chat/chat_screen.dart';
// import 'package:inzone/screen/chat/human_chat_screen.dart';

// Global key to access AllChatsScreen state from anywhere
final GlobalKey<_AllChatsScreenState> allChatsScreenKey =
    GlobalKey<_AllChatsScreenState>();

class AllChatsScreen extends StatefulWidget {
  const AllChatsScreen({super.key});

  @override
  State<AllChatsScreen> createState() => _AllChatsScreenState();
}

class _AllChatsScreenState extends State<AllChatsScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatUser> _chatUsers = [];
  List<ChatUser> _groupChats = [];
  bool _isLoading = false;
  String? currentUserId;
  late DateTime _startTime;
  int pageOpened = 0;
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _startTime = DateTime.now();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCurrentUser();
  }

  void _handleTabChange() {
    if (_tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('all_chats_screen',
        {"timeSpent": timeSpent.inSeconds, "pageOpenedCount": pageOpened});
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
          // Handle group chat - fetch the actual group data to get the correct name
          try {
            // Get the group chat document to get the correct name
            DocumentSnapshot groupDoc =
                await _firestore.collection('groupChats').doc(doc.id).get();

            // Try different field names for the group name
            String groupName = 'Group Chat';
            if (groupDoc.exists && groupDoc.data() != null) {
              var groupData = groupDoc.data() as Map<String, dynamic>;
              debugPrint('Group data from Firestore: $groupData');

              // Try different possible field names for the group name
              groupName = groupData['name'] ??
                  groupData['groupName'] ??
                  data['groupName'] ??
                  'Group Chat';

              debugPrint('Using group name in list: $groupName');
            }

            allChats.add(ChatUser(
              name: groupName,
              email: doc.id,
              chatId: doc.id,
              lastMessage: data['lastMessage'],
              lastMessageTime: data['lastMessageTime'],
              isHuman: true,
              isGroupChat: true,
            ));
          } catch (e) {
            debugPrint('Error fetching group details: $e');
            // Fallback to basic info if there's an error
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
          }
        } else {
          List<dynamic> participants = data['participants'] ?? [];
          String? otherUserId = participants
              .firstWhere((id) => id != currentUserId, orElse: () => null);

          if (otherUserId != null) {
            Map<String, dynamic> participantNames =
                data['participantNames'] ?? {};
            String otherUserName = participantNames[otherUserId] ?? 'User';

            if (otherUserName == 'User') {
              try {
                DocumentSnapshot userDoc = await _firestore
                    .collection('humanUsers')
                    .doc(otherUserId)
                    .get();

                if (userDoc.exists && userDoc.data() != null) {
                  var userData = userDoc.data() as Map<String, dynamic>;
                  otherUserName =
                      userData['name'] ?? userData['Name'] ?? 'User';
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
          SnackBar(content: Text('Error loading conversations: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the count based on current tabç
    int chatCount =
        _currentTabIndex == 0 ? _chatUsers.length : _groupChats.length;
    String subtitle = '$chatCount';

    return ColorfulSafeArea(
      topColor: Theme.of(context).canvasColor,
      left: false,
      right: false,
      top: true,
      bottom: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: CustomAppBar(
          isHome: true,
          isChat: true,
          userPoints: "100",
          profileImageUrl: null,
          subtitle: subtitle, // Pass the chat count as subtitle
          onSearchTap: () {},
          onProfileTap: () {},
          onPointsTap: () {},
        ),
        body: Column(
          children: [
            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: Theme.of(context).colorScheme.primary,
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
        color: Theme.of(context).dialogBackgroundColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          topLeft: Radius.circular(30),
        ),
      ),
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ))
          : users.isEmpty
              ? Center(
                  child: Text(
                  "No conversations yet",
                  style: Theme.of(context).textTheme.bodyLarge,
                ))
              : ListView.builder(
                  itemCount: users.length + 1,
                  itemBuilder: (context, index) {
                    if (index == users.length) {
                      return const SizedBox(height: 100);
                    }
                    return ChatUserCard(
                      userData: users[index],
                      currentUserId: currentUserId ?? '',
                    );
                  },
                ),
    );
  }

  // Helper method to get the current user's name
  Future<String> _getUserName() async {
    try {
      Map<String, dynamic>? userProfile =
          await InZoneDatabase.getCurrentUserProfile();
      if (userProfile != null) {
        return userProfile["Name"] ?? userProfile["name"] ?? "User";
      }
    } catch (e) {
      print('Error getting user name: $e');
    }
    return "User";
  }

  // Method to set active tab from outside
  void setActiveTab(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }
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
      if (map.containsKey('aiProfile') &&
          map['aiProfile'] != null &&
          map.containsKey('conversationId')) {
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
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    if (widget.userData.profilePictureURL == null ||
        widget.userData.profilePictureURL!.isEmpty) {
      try {
        // Skip for group chats
        if (widget.userData.isGroupChat) return;

        final String userId = widget.userData.email ?? '';
        if (userId.isEmpty) return;

        final userData = await InZoneDatabase.getUserProfile(userId);
        if (userData != null && mounted) {
          setState(() {
            _profileImageUrl = userData['profilePicture'] ?? "";
          });
        }
      } catch (e) {
        print('Error loading profile image: $e');
      }
    } else {
      _profileImageUrl = widget.userData.profilePictureURL;
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedTime = '';
    if (widget.userData.lastMessageTime != null) {
      DateTime messageTime = widget.userData.lastMessageTime!.toDate();
      DateTime now = DateTime.now();

      if (now.difference(messageTime).inDays == 0) {
        // Today - show time
        formattedTime =
            '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
      } else if (now.difference(messageTime).inDays == 1) {
        // Yesterday
        formattedTime = 'Yesterday';
      } else {
        // Other days - show date
        formattedTime =
            '${messageTime.day}/${messageTime.month}/${messageTime.year}';
      }
    }

    return InkWell(
      onTap: () {
        if (widget.userData.isHuman) {
          if (widget.userData.isGroupChat) {
            // Navigate to group chat
            debugPrint('Navigating to group chat: ${widget.userData.chatId}');
            // Show loading indicator while fetching group data
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            // Fetch the group data first
            FirebaseFirestore.instance
                .collection('groupChats')
                .doc(widget.userData.chatId)
                .get()
                .then((doc) {
              // Close loading dialog
              Navigator.of(context).pop();

              if (doc.exists) {
                debugPrint('Group document data: ${doc.data()}');

                // Get the actual group name from the document
                // First try to get it from the 'name' field, then from 'groupName', then fallback to userData name
                final String groupName = doc.data()?['name'] ??
                    doc.data()?['groupName'] ??
                    widget.userData.name ??
                    'Group Chat';

                debugPrint('Using group name: $groupName');

                // Extract avatars if available
                List<String> avatars = [];
                if (doc.data()?['avatars'] != null &&
                    doc.data()?['avatars'] is List) {
                  avatars = List<String>.from(doc.data()?['avatars']);
                }

                // Create GroupData from the document
                final groupData = GroupData(
                  id: widget.userData.chatId ?? '',
                  name: groupName,
                  description: doc.data()?['description'] ?? '',
                  memberCount:
                      (doc.data()?['participants'] as List?)?.length ?? 0,
                  messageCount: doc.data()?['messageCount'] ?? 0,
                  avatars: avatars,
                  isMember: true,
                );

                // Navigate to the group chat screen
                debugPrint('Navigating to group chat with data: $groupData');

                // Try using Go Router first with fallback to direct navigation
                try {
                  context.push(Routes.groupChat, extra: groupData).then((_) {
                    // Refresh the conversation list when returning from chat
                    if (mounted) {
                      (context.findAncestorStateOfType<_AllChatsScreenState>())
                          ?._fetchConversations();
                    }
                  });
                } catch (e) {
                  debugPrint('Go Router navigation failed: $e');
                }
              } else {
                // Fallback to regular chat if group data not found
                context.pushNamed('chat', extra: {
                  'conversationId': widget.userData.chatId ?? '',
                  'otherUserName': widget.userData.name ?? 'Group Chat',
                  'otherUserId': '',
                }).then((_) {
                  if (mounted) {
                    (context.findAncestorStateOfType<_AllChatsScreenState>())
                        ?._fetchConversations();
                  }
                });
              }
            });
          } else {
            // Navigate to human chat
            context.pushNamed('chat', extra: {
              'conversationId': widget.userData.chatId ?? '',
              'otherUserName': widget.userData.name ?? 'User',
              'otherUserId': widget.userData.email ?? '',
            }).then((_) {
              // Refresh the conversation list when returning from chat
              if (mounted) {
                (context.findAncestorStateOfType<_AllChatsScreenState>())
                    ?._fetchConversations();
              }
            });
          }
        } else {
          // Navigate to AI chat
          context.pushNamed('chat', extra: widget.userData);
        }
      },
      child: ListTile(
        leading: Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? const Color(0xffFFE2A9)
                  : AppColors.primaryBlue.withOpacity(0.3),
              width: 1.5,
            ),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                ? Image.network(
                    _profileImageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.account_circle,
                        size: 30,
                        color: Colors.grey),
                  )
                : const Icon(Icons.account_circle,
                    size: 30, color: Colors.grey),
          ),
        ),
        title: Text(
          widget.userData.name ?? 'Unknown',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: widget.userData.lastMessage != null
            ? Text(
                widget.userData.lastMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : Text(
                widget.userData.email ?? '',
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall,
              ),
        trailing: formattedTime.isNotEmpty
            ? Text(
                formattedTime,
                style: Theme.of(context).textTheme.labelSmall,
              )
            : null,
      ),
    );
  }
}
