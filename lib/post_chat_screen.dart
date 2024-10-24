import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comment_tree/widgets/comment_tree_widget.dart';
import 'package:comment_tree/widgets/tree_theme_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inzone/components/avatar_card.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/inzone_database.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostChatScreen extends StatefulWidget {
String name;
String? profileImageURL;
String chat;
String avatarID;


   PostChatScreen({super.key, required this.name, required this.profileImageURL, required this.chat, required this.avatarID});


  @override
  State<PostChatScreen> createState() => _PostChatScreenState();
}


class _PostChatScreenState extends State<PostChatScreen> {

  late DateTime _startTime; // To store the start time
  int pageOpened = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _startTime = DateTime.now();
    pageOpened+=1;
  }

  @override
  void dispose() {

    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('post_chat_screen', {"timeSpent" : timeSpent.inSeconds, "pageOpenedCount" : pageOpened});

    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0, // No shadow/elevation
          backgroundColor: Colors.transparent, // Blend with background
          leading: const BackButton(), // Default back button
          title: const  Text("Share this chat"),
          actions: [
            TextButton(
              onPressed: () {
                // Action for Post button
              },
              child: Text(
                'Post',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor, // Set to primary color
                ),
              ),
            ),
          ],
        ),
        body: Center(
            child: RepostPostCard(
              name: widget.name,
              profileImageURL: widget.profileImageURL,
              chat: widget.chat,
              avatarID: widget.avatarID,


            )));
  }
}

class RepostPostCard extends StatefulWidget {
  final Function(String)? onTap;
  String name;
  String? profileImageURL;
  String chat;
  String avatarID;
  RepostPostCard({super.key, required this.name, required this.profileImageURL, required this.chat, required this.avatarID, this.onTap});



  @override
  State<RepostPostCard> createState() => _RepostPostCardState();
}

class _RepostPostCardState extends State<RepostPostCard> {
  bool imageSuccess = false;

  bool isLiked = false;
  bool isUnLike = false;

  String username = '';
  CommentClass? comment;

  @override
  void initState() {
    super.initState();
    // _checkIfLiked();  // Check if the current post is liked when the widget is initialized
  }

// Function to check if the current post is liked
//   Future<void> _checkIfLiked() async {
//     bool liked = await LikedPostsPreferences.isPostLiked(widget.post.id);  // Check if postId is in SharedPreferences
//     setState(() {
//       isLiked = liked;
//     });
//   }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigator.push(context, MaterialPageRoute(builder: (context)=>MeScreen()));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 10),
        child: Container(
          width: MediaQuery.of(context).size.width - 30,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(boxShadow: [
            BoxShadow(
              color: const Color(0xff959595).withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 15,
              offset: const Offset(0, 4), // changes position of shadow
            ),
          ], color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      maxLines: null,
                      textInputAction: TextInputAction.done,
            autofocus: true,
                      textAlign: TextAlign.start,
                      style:  TextStyle(height: 1.5, color: Colors.black),
                      decoration:  InputDecoration(
                        border: InputBorder.none, // No underline/border
                        hintText: "What do you think about this chat?"
                      ),
                      onChanged: (text) {},
                    ),
                  )
                ]),
                const SizedBox(
                  height: 10,
                ),
                Divider(
                  color: Colors.blue,
                ),
                Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 30,
                    child: Center(
                      child: widget.profileImageURL == null ? Align(
                          alignment: Alignment.center,
                          child: RandomAvatar(widget.name)) :ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          widget.profileImageURL!,
                          fit: BoxFit.fitWidth,
                          width: MediaQuery.of(context).size.width - 60,
                          errorBuilder: (context, object, st) {
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                messageCard(
                  widget.chat,
                   false),
                const SizedBox(
                  height: 10,
                ),
            
              ],
            ),
          ),
        ),
      ),
    );
  }

  // PopupMenuItem menuOption(String iconPath, String title, String value,
  //     BuildContext context, String userEmail, String userName) {
  //   return PopupMenuItem(
  //     value: value,
  //     onTap: () async {
  //       if (value == "chat") {
  //         String? chatID = await InZoneDatabase.startConversation(widget.post.id);
  //         print(chatID);
  //       } else if(value == "not_interested"){
  //         final snackBar = SnackBar(
  //           content: Text("This post has been flagged for review."),
  //           backgroundColor: Colors.red,
  //         );
  //         ScaffoldMessenger.of(context).showSnackBar(snackBar);
  //       }else if(value == "dont_show"){
  //         final snackBar = SnackBar(
  //           content: Text("Posts from ${widget.post.userName} will not be shown."),
  //           backgroundColor: Colors.red,
  //         );
  //         ScaffoldMessenger.of(context).showSnackBar(snackBar);
  //       }else if(value == "dont_show"){
  //         final snackBar = SnackBar(
  //           content: Text("Posts from ${widget.post.userName} will not be shown."),
  //           backgroundColor: Colors.red,
  //         );
  //         ScaffoldMessenger.of(context).showSnackBar(snackBar);
  //       }
  //     },
  //     child: Row(children: [
  //       SvgPicture.asset(iconPath),
  //       const SizedBox(
  //         width: 6,
  //       ),
  //       Text(title)
  //     ]),
  //   );
  // }


  Widget messageCard(String text, bool isMe) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start, // Align properly for different users
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Text(
                widget.name,
                style: TextStyle(color: Colors.blue),
              ),
            ),
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Flexible(
                  // Flexible allows the text to take up available space and wrap when needed
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Theme.of(context).canvasColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomRight: isMe
                            ? const Radius.circular(18)
                            : const Radius.circular(0),
                        bottomLeft: isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(18),
                      ),
                    ),
                    child: Text(
                      text,
                      overflow: TextOverflow
                          .visible, // Ensures the text wraps when necessary
                      softWrap: true, // Allows the text to wrap naturally
                      style:
                          TextStyle(color: isMe ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LikeButtonWidget extends StatefulWidget {
  final InZonePost post; // Unique ID for the post
  bool liked;
  LikeButtonWidget({super.key, required this.post, required this.liked});

  @override
  _LikeButtonWidgetState createState() => _LikeButtonWidgetState();
}

class _LikeButtonWidgetState extends State<LikeButtonWidget> {
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    isLiked = widget.liked;
    _loadLikedState(); // Load the liked state when the widget is initialized
  }

  // Load the liked state from SharedPreferences
  Future<void> _loadLikedState() async {
    bool liked = await LikedPostsPreferences.isPostLiked(widget.post.id);
    setState(() {
      isLiked = liked;
    });
  }

  // Handle like and unlike actions
  Future<void> _handleLike() async {
    if (isLiked) {
      await LikedPostsPreferences.removeLikedPost(widget.post.id);
    } else {
      await LikedPostsPreferences.addLikedPost(widget.post);
    }
    setState(() {
      isLiked = !isLiked; // Toggle the like state
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleLike, // Toggle like/unlike when tapped
      child: SizedBox(
        height: 30,
        width: 30,
        child: SvgPicture.asset(
          isLiked
              ? CustomIcons.like
              : CustomIcons.notlike, // Show correct icon based on state
        ),
      ),
    );
  }
}
