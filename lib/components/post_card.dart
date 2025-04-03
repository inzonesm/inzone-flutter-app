import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comment_tree/widgets/comment_tree_widget.dart';
import 'package:comment_tree/widgets/tree_theme_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inzone/components/video_widget.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/inzone_database.dart';
import 'package:inzone/profile_screen.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';


class PostCard extends StatefulWidget {
  InZonePost post;
  final Function(String)? onTap;
  final bool showHue;
  
  InZonePost getPost () {
    return post;
  }
  
  PostCard({
    super.key, 
    required this.post, 
    this.onTap,
    this.showHue = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool imageSuccess = false;


  String username = '';
  CommentClass? comment;

  bool isLiked = false;
  Future<bool> isCommentPresent() async {
    DocumentReference postDocumentReference = _firestore.collection('postComments').doc(widget.post.id.toString());

    // Get the document snapshot
    DocumentSnapshot postSnapshot = await postDocumentReference.get();

    // Initialize currentComments
    List<dynamic> currentComments = [];

    if (postSnapshot.exists) {
      // If the document exists, retrieve the current comments list
      currentComments = postSnapshot['comments'] ?? [];
      return currentComments.isNotEmpty;
    }

    return false;
  }
  @override
  void initState() {
    super.initState();
    _loadLikedState(); // Load the liked state when the widget is initialized
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the post ID changed, reload the liked state
    if (oldWidget.post.id != widget.post.id) {
      _loadLikedState();
    }
  }

  Future<void> _loadLikedState() async {
    // Skip loading like state for posts with unknown IDs
    if (widget.post.id == "unknown" || widget.post.id.isEmpty) {
      setState(() {
        isLiked = false; // Always set to false for unknown posts
      });
      return;
    }
    
    bool liked = await LikedPostsPreferences.isPostLiked(widget.post.id);
    if (mounted) {
      setState(() {
        isLiked = liked;
      });
    }
  }

  Future<void> handleLike() async {
    // Skip like handling for posts with unknown IDs
    if (widget.post.id == "unknown" || widget.post.id.isEmpty) {
      return;
    }
    
    // Check current like status
    bool currentLikeStatus = isLiked;
    
    if (currentLikeStatus) {
      await LikedPostsPreferences.removeLikedPost(widget.post.id);
    } else {
      await LikedPostsPreferences.addLikedPost(widget.post);
    }
    
    if (mounted) {
      setState(() {
        isLiked = !currentLikeStatus; // Toggle the like state
      });
    }
  }
  checkComment() async {
    isCommentPresent().then((value) {
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          isCommentPresentbool = value;
        });
      }
    });
  }

bool isCommentPresentbool = false;
  @override
  Widget build(BuildContext context)  {

checkComment();

    return GestureDetector(
      onDoubleTap: handleLike, // Handle like on double tap


      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Container(
          constraints: BoxConstraints(
            minHeight: imageSuccess ? 350 : 190,
          ),
          width: MediaQuery.of(context).size.width - 30,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),

          decoration: BoxDecoration(
              boxShadow: [
            BoxShadow(
              color: const Color(0xff959595).withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 15,
              offset: const Offset(0, 4), // changes position of shadow

            ),
            
                // Only add blue hue for human posts (not AI)
                if (!widget.post.isAi && widget.showHue) 
                  BoxShadow(
                    color: Colors.lightBlueAccent.withOpacity(0.5), // Blue hue color
                    spreadRadius: 5, // Spread of the hue
                    blurRadius: 12, // Soft edges for blending
                    offset: const Offset(0, 0), // Center the glow around the container
                  ),

          ], color: Colors.white.withOpacity(0.97), borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  // Image.asset(post.profilePicturePath),
                  RandomAvatar(widget.post.userName, height: 40, width: 40),
                  const SizedBox(
                    width: 10,
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(
                      onTap: (){
                        if (widget.post.isAi) {
                          print(widget.post.userName);
                          Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfileScreen(
                            uid: widget.post.userName,
                            isAI: true, // AI user
                          )));

                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfileScreen(
                            uid: widget.post.userReference,
                            isAI: widget.post.isAi, // Use the post's isAi field
                          )));

                        }
                      },
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          widget.post.userName,
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        ),
                      ),
                    ),

                  ]),
                  const Spacer(),
                  PopupMenuButton(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.all(15),
                    child: SvgPicture.asset(
                      CustomIcons.threeDots,
                      height: 40,
                      width: 40,
                    ),
                    onSelected: (value) {
                      // your logic
                    },
                    itemBuilder: (BuildContext bc) {
                      return [
                        menuOption(
                            CustomIcons.notInterested,
                            "Flag this post",
                            "not_interested",
                            context,
                            widget.post.userName,
                            widget.post.userReference),
                        menuOption(
                            CustomIcons.dontShow,
                            "Block ${widget.post.userName}",
                            "dont_show",
                            context,
                            widget.post.userName,
                            widget.post.userReference),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              widget.post.textContent == null
                  ? const SizedBox()
                  : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.post.textContent,
                  textAlign: TextAlign.start,
                  style: const TextStyle(height: 1, color: Colors.black),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              (widget.post.imageContent.isNotEmpty) ||
                  (widget.post.videoContent.isNotEmpty ?? false)
               ?SizedBox(
                width: MediaQuery.of(context).size.width - 30,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Display all images first
                      if (widget.post.imageContent.isNotEmpty)
                        ...widget.post.imageContent.map((imageUrl) {
                          return imageUrl.isNotEmpty
                              ? Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.fitWidth,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    return child; // The image has loaded
                                  } else {
                                    return Container(
                                      width: MediaQuery.of(context).size.width - 60,
                                      height: 200, // Adjust to the approximate expected height
                                      color: Colors.grey[300], // Placeholder color
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                },

                                width: MediaQuery.of(context).size.width - 60,
                                errorBuilder: (context, object, st) {
                                  return const SizedBox();
                                },
                              ),
                            ),
                          )
                              : const SizedBox();
                        }),

                      // Display all videos after images
                      if (widget.post.videoContent.isNotEmpty && widget.post.videoContent.first.length > 3)
                        ...widget.post.videoContent.map((videoUrl) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 60,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child:  VideoWidget(videoUrl: videoUrl),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              )
                  : const SizedBox(),

              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                GestureDetector(
                onTap: handleLike, // Toggle like/unlike when tapped
                child: SizedBox(
                  height: 30,
                  width: 30,
                  child: SvgPicture.asset(
                    isLiked ? CustomIcons.like : CustomIcons.notlike, // Show correct icon based on state
                  ),
                ),
              ),
                  const SizedBox(
                    width: 10,
                  ),
                  // InkWell(
                  //     onTap: () {
                  //       filterSheetModel();
                  //     },
                  //     child: SizedBox(height: 35, width: 35, child: SvgPicture.asset(CustomIcons.comment))),
                  if (isCommentPresentbool == true)
                    InkWell(
                        onTap: () {
                          filterSheetModel();
                        },
                        child: SizedBox(height: 35, width: 35, child: SvgPicture.asset(CustomIcons.comment
                        ))),
                  if (isCommentPresentbool == false)  InkWell(
                      onTap: () {
                        filterSheetModel();
                      },
                      child: SizedBox(height: 35, width: 35, child: Image.asset(CustomIcons.uncomment))),
                  const SizedBox(
                    width: 10,
                  ),
                  // GestureDetector(
                  //     onTap: () {
                  //       // Navigator.push(context,
                  //       //     MaterialPageRoute(builder: (context) {
                  //       //   return CommentScreen();
                  //       // }));
                  //       // showSlidingBottomSheet(context,
                  //       //     builder: (context) => SlidingSheetDialog(
                  //       //       cornerRadius: 30,
                  //       //       snapSpec: const SnapSpec(snappings: [0.7, 0.9]),
                  //       //       builder: (context, state) {
                  //       //
                  //       //         // return CommentPage(
                  //       //         //   post: widget.post,
                  //       //         // );
                  //       //       },
                  //       //     ));
                  //     },
                  //     child: SvgPicture.asset(CustomIcons.send)),
                  const Spacer(),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }


  PopupMenuItem menuOption(String iconPath, String title, String value,
      BuildContext context, String userEmail, String userName) {
    return PopupMenuItem(
      value: value,
      onTap: () async {
        if(value == "not_interested"){
          const snackBar = SnackBar(
            content: Text("This post has been flagged for review."),
            backgroundColor: Colors.red,
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        } else if(value == "dont_show"){
          final snackBar = SnackBar(
            content: Text("Posts from ${widget.post.userName} will not be shown."),
            backgroundColor: Colors.red,
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      },
      child: Row(children: [
        SvgPicture.asset(iconPath),
        const SizedBox(
          width: 6,
        ),
        Text(title)
      ]),
    );
  }

  final TextEditingController _replyController = TextEditingController();
  TextEditingController mySearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String type = '';

  String? selectedCommentId;

  Widget chatInput(String? commentId, String? name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 30),
      child: Row(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: TextFormField(
                  scrollController: _scrollController,
                  cursorColor: Colors.black,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  controller:
                  type == 'Reply' ? _replyController : mySearchController,
                  onTap: () {},
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  // cursorHeight: 17,
                  decoration: InputDecoration(
                    suffixIconColor: Colors.grey.withOpacity(0.4),
                    contentPadding:
                    const EdgeInsets.only(top: 10, left: 16, right: 16),
                    border: InputBorder.none,
                    hintText: type == 'Reply' ? 'Add Reply' : 'Add Comment',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black26,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Colors.black38,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Colors.black,
                      ),
                    ),
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
            onPressed: () {
              if (type == 'Reply') {
                if (selectedCommentId != null) {
                  // _addReply(
                  //     selectedCommentId!); // Pass stored commentId to _addReply function
                  _replyController.clear();
                  setState(() {
                    type = '';
                    selectedCommentId =
                    null; // Clear selected comment ID after replying
                  });
                }
              } else {
                _addComment();
              }
            },
            child: const Center(
              child: Icon(
                Icons.send,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add comment to Firestore
  void _addComment() async {
    print(widget.post.id);
    String commentText = mySearchController.text.trim();
    // Reference to the document where comments are stored
    DocumentReference postDocumentReference = _firestore.collection('postComments').doc(widget.post.id.toString());

    // Get the document snapshot
    DocumentSnapshot postSnapshot = await postDocumentReference.get();

    // Initialize currentComments
    List<dynamic> currentComments = [];

    if (postSnapshot.exists) {
      // If the document exists, retrieve the current comments list
      currentComments = postSnapshot['comments'] ?? [];
    } else {
      // If the document does not exist, create it with an empty comments list
      await postDocumentReference.set({'comments': currentComments});
    }

    // New comment to add
    Map<String, dynamic> newComment = {
      'author': FirebaseAuth.instance.currentUser!.uid,
      'text': commentText,
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'timestamp': DateTime.now().toString(),
      'likedBy': [], // Initialize likedBy as an empty list
    };

    // Add the new comment to the existing comments list
    currentComments.add(newComment);

    // Update the document with the new comments list
    await postDocumentReference.update({'comments': currentComments});

    setState(() {
      mySearchController.clear();
    });
  }



  // void _addReply(String commentId) async {
  //   String replyText = _replyController.text.trim();
  //   if (replyText.isNotEmpty) {
  //     await _firestore
  //         .collection('comments')
  //         .doc(commentId)
  //         .collection('replies')
  //         .add({
  //       'author': username,
  //       // Replace with actual user name
  //       'text': replyText,
  //       'commentId': commentId,
  //       'timestamp': DateTime.now().toString(),
  //     });
  //     _replyController.clear();
  //   }
  // }


// Function to toggle like status and store it in SharedPreferences
  toggleLikeComment(String commentId) async {
    CommentClass comment = await getComment(commentId);
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Check if the current user has already liked or disliked the comment
    bool isLiked = comment.likedBy!.contains(currentUserId);
    bool isDisliked = comment.dislikedBy!.contains(currentUserId);

    // Remove from dislikedBy if the comment was previously disliked
    if (isDisliked) {
      comment.dislikedBy!.remove(currentUserId);
    }

    // Toggle like status
    if (isLiked) {
      // Remove from likedBy if the comment was previously liked
      comment.likedBy!.remove(currentUserId);
    } else {
      // Add to likedBy if the comment was not previously liked
      comment.likedBy!.add(currentUserId);
      // Make sure to remove from dislikedBy if the comment was previously disliked
      comment.dislikedBy!.remove(currentUserId);
    }

    // Update the likedBy and dislikedBy fields in Firestore
    await _firestore
        .collection('comments')
        .doc(commentId)
        .update({'likedBy': comment.likedBy, 'dislikedBy': comment.dislikedBy});

    // Store the updated like status in SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(commentId, !isLiked);

    // If the comment was disliked, update the disliked status as well
    if (isDisliked) {
      setState(() {
        dislikedComments[commentId] = false;
      });
      await prefs.setBool(commentId, false);
    }

    // Return the updated like status
    return !isLiked;
  }

// Function to toggle dislike status and store it in SharedPreferences
  toggleUnLikeComment(String commentId) async {
    CommentClass comment = await getComment(commentId);
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Check if the current user has already liked or disliked the comment
    bool isDisliked = comment.dislikedBy!.contains(currentUserId);
    bool isLiked = comment.likedBy!.contains(currentUserId);

    // Remove from likedBy if the comment was previously liked
    if (isLiked) {
      comment.likedBy!.remove(currentUserId);
    }

    // Toggle dislike status
    if (isDisliked) {
      // Remove from dislikedBy if the comment was previously disliked
      comment.dislikedBy!.remove(currentUserId);
    } else {
      // Add to dislikedBy if the comment was not previously disliked
      comment.dislikedBy!.add(currentUserId);
      // Make sure to remove from likedBy if the comment was previously liked
      comment.likedBy!.remove(currentUserId);
    }

    // Update the likedBy and dislikedBy fields in Firestore
    await _firestore
        .collection('comments')
        .doc(commentId)
        .update({'likedBy': comment.likedBy, 'dislikedBy': comment.dislikedBy});

    // Store the updated dislike status in SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(commentId, !isDisliked);

    // If the comment was liked, update the liked status as well
    if (isLiked) {
      setState(() {
        likedComments[commentId] = false;
      });
      await prefs.setBool(commentId, false);
    }

    // Return the updated dislike status
    return !isDisliked;
  }


  Future<CommentClass> getComment(String commentId) async {
    DocumentSnapshot snapshot =
    await _firestore.collection('comments').doc(commentId).get();
    return CommentClass.fromJson(snapshot.data() as Map<String, dynamic>);
  }

  Map<String, bool> likedComments = {};
  Map<String, bool> dislikedComments = {};
  bool showReplies = false; // Flag to track whether to show replies or not

  filterSheetModel() {
    setState(() {
      _replyController.clear();
      selectedCommentId = null;
      type = '';
    });

    showModalBottomSheet(
      isScrollControlled: true
      ,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          var width = MediaQuery.of(context).size.width;
          return GestureDetector(
            onTap: (){
              FocusScope.of(context).unfocus();
            },
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.56,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(30),
                    topLeft: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 20,
                    ),
                    const Text(
                      'Comments',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Expanded(
                      child:StreamBuilder<DocumentSnapshot>(
                        stream: _firestore
                            .collection('postComments')
                            .doc(widget.post.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData)  {
                            if ( snapshot.data!.exists){

                            } else {

                            }
                            dynamic data = snapshot.data!.data() as Map<String, dynamic>?;
                            data ??= {};
                            final commentsList = data['comments'] ?? [];
                            final comments = commentsList.map<CommentClass>((comment) {
                              return CommentClass(
                                author: comment['author'],
                                text: comment['text'],
                                replies: [], // Assuming you will handle replies separately
                                timestamp: "",
                                id: '', // Make sure each comment has a unique ID
                                postId: widget.post.id.toString(),
                                userId: comment['userId'],
                              );
                            }).toList();

                            if (comments.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No Comments Available',
                                  style: TextStyle(color: Colors.black, fontSize: 20),
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 5, 20, 100),
                              itemCount: comments.length,
                              itemBuilder: (BuildContext context, int index) {
                                comment = comments[index];
                                return AnimatedContainer(
                                  duration: const Duration(seconds: 1),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0, vertical: 10),
                                    child: CommentTreeWidget<CommentClass,
                                        CommentClass>(
                                      CommentClass(
                                          author:  comment==null ? "john!" : comment!.author,
                                          text:  comment==null ? "Great!" : comment!.text,
                                          timestamp: "",
                                          replies: [], id: "",
                                          postId: "",
                                          userId: ""),
                                      const [

                                      ],
                                      treeThemeData: const TreeThemeData(
                                          lineColor: Colors.blue, lineWidth: 3),
                                      avatarRoot: (context, data) =>
                                          PreferredSize(
                                            preferredSize: const Size.fromRadius(12),
                                            child: RandomAvatar(comment!.author,
                                                height: 40, width: 40),
                                          ),
                                      avatarChild: (context, data) =>
                                          PreferredSize(
                                            preferredSize: const Size.fromRadius(12),
                                            child: RandomAvatar(
                                                comment!.author,
                                                height: 40,
                                                width: 40),
                                          ),
                                      contentChild: (context, data) {
                                        return Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 8, horizontal: 8),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                  BorderRadius.circular(12)),
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "aadesh18",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                        fontWeight:
                                                        FontWeight.w600,
                                                        color: Colors.black),
                                                  ),
                                                  const SizedBox(
                                                    height: 4,
                                                  ),
                                                  Text(
                                                    "",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                        fontWeight:
                                                        FontWeight.w300,
                                                        color: Colors.black),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                      contentRoot: (context, data) {
                                        return Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 8, horizontal: 8),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                  BorderRadius.circular(12)),
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [

                                                  Text(
                                                    '${data.content}',

                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Padding(
                                            //   padding: const EdgeInsets.all(0),
                                            //   child: TextButton(
                                            //     child: const  Text(
                                            //       'Reply',
                                            //       style: TextStyle(
                                            //         color: Colors.blue,
                                            //       ),
                                            //     ),
                                            //     onPressed: () {},
                                            //     style: ButtonStyle(
                                            //       padding: MaterialStateProperty
                                            //           .all<EdgeInsets>(
                                            //           EdgeInsets.zero),
                                            //     ),
                                            //   ),
                                            // )
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                );

                              },
                            );
                          } else if (snapshot.hasError) {

                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          } else {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                        },
                      ),
                    ),
                    chatInput(comment?.id.toString(), comment?.author.toString())
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }





}
