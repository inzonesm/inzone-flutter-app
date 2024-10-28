import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inzone/chat_screen.dart';
import 'package:inzone/inzone_database.dart';
import 'package:random_avatar/random_avatar.dart';

class AllChatsScreen extends StatefulWidget {
  const AllChatsScreen({super.key});

  @override
  State<AllChatsScreen> createState() => _AllChatsScreenState();
}

class _AllChatsScreenState extends State<AllChatsScreen> {
  List<ChatUser> _chatUsers = [];
  bool _isLoading = false;
  String? id = "";
  late DateTime _startTime; // To store the start time
  int pageOpened = 0;

  setID() async {
    id = await InZoneDatabase.getCurrentUserUid();
  }

  @override
  void initState() {
    super.initState();
    _isLoading = true;

    _fetchConversations();
    setID();
    _startTime = DateTime.now();

  }


  Future<void> _fetchConversations() async {
    _chatUsers.clear();
    List<dynamic>? data  = await InZoneDatabase.getConversations();

    if (data!= null) {
      // Create a Set to store unique conversation IDs
      Set<dynamic> uniqueConversationIds = {};
      List<dynamic> uniqueConversations = [];

      for (var conversation in data) {
        // Check if conversationId is not in the Set
        if (uniqueConversationIds.add(conversation['aiProfile']['username'])) {
          // Add conversation to unique list if the ID is new
          uniqueConversations.add(conversation);
        }
      }
      print(data.length);
      if (data.isEmpty){
        _chatUsers = [];
        return;
      }
      List<ChatUser?> users =
      uniqueConversations.map((json) => ChatUser.fromJson(json)).toList();
      print(users.length);
      List<ChatUser> nonNullUsers = users.where((user) => user != null).cast<ChatUser>().toList();
      print(nonNullUsers.length);
      users.clear();
      _chatUsers.clear();

      setState(() {
        _chatUsers = nonNullUsers;
        print(_chatUsers.length);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    DateTime endTime = DateTime.now();
  Duration timeSpent = endTime.difference(_startTime);
  InZoneDatabase.logEvent('all_chats_screen', {"timeSpent" : timeSpent.inSeconds,  "pageOpenedCount" : pageOpened});

    super.dispose();

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
          title: const Text("Chats",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
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
                      ? const Center(
                          child:
                              CircularProgressIndicator()) // Show loading indicator while fetching data
                      : SingleChildScrollView(
                          child: Column(
                            children: _chatUsers
                                .map((user) => ChatUserCard(userData: user))
                                .toList(),
                          ),
                        ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ChatUser {
  String? name;
  String? email;
  String? chatId;


  ChatUser({
    this.name,
    this.email,
    this.chatId,
  });

  // Static method to handle null returning logic
  static ChatUser? fromJson(Map<String, dynamic> map) {
    try {
      // Check if 'aiProfile' and 'conversationId' exist in the map
      if (map.containsKey('aiProfile') && map['aiProfile'] != null && map.containsKey('conversationId')) {
        return ChatUser(
          email: map['aiProfile']['username'] ?? '',
          name: map['aiProfile']["name"] ?? '',
          chatId: map['conversationId'] ?? '',
        );
      }
      // Return null if required fields are missing
      return null;
    } catch (e) {
      // Return null if any error occurs during parsing
      return null;
    }
  }
}

class ChatUserCard extends StatefulWidget {
  ChatUser userData;

  ChatUserCard({super.key, required this.userData});

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard> {
  List<ChatUser> userData = [];

  final user = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userData: widget.userData,
              ),
            ),
          );
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
                shape: BoxShape.circle),
            child: RandomAvatar(widget.userData.name.toString(),
                height: 30, width: 30),
          ),
          title: Text(
            '${widget.userData.name}',
            style: GoogleFonts.openSans(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${widget.userData.email}',
            maxLines: 1,
            style: GoogleFonts.openSans(
              color: Colors.black45,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ));
  }
}
