import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comment_tree/widgets/comment_tree_widget.dart';
import 'package:comment_tree/widgets/tree_theme_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzone/router/routes.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:inzone/services/appsflyer_service.dart';

class RepostCard extends StatefulWidget {
  InZonePost post;
  InZoneAvatar repost;
  final Function(String)? onTap;
  final String aiChat;

  RepostCard(
      {super.key,
      required this.post,
      this.onTap,
      required this.repost,
      required this.aiChat});

  @override
  State<RepostCard> createState() => _RepostCardState();
}

class _RepostCardState extends State<RepostCard>
    with AutomaticKeepAliveClientMixin {
  bool imageSuccess = false;

  bool isLiked = false;
  bool isUnLike = false;

  String username = '';
  CommentClass? comment;
  String? _editedTextContent;
  String? _resolvedPostId;

  String get _currentTextContent =>
      _editedTextContent ?? widget.post.textContent;

  String? _extractGameIdFromLink(String link) {
    try {
      final uri = Uri.parse(link);
      final gameId = uri.queryParameters['gameId'];
      if (gameId != null && gameId.trim().isNotEmpty) return gameId.trim();

      final sub1 = uri.queryParameters['deep_link_sub1'];
      if (sub1 != null && sub1.trim().isNotEmpty) return sub1.trim();

      final afDp = uri.queryParameters['af_dp'];
      if (afDp != null && afDp.trim().isNotEmpty) {
        final decoded = Uri.decodeComponent(afDp);
        final afUri = Uri.tryParse(decoded);
        final afGameId = afUri?.queryParameters['gameId'];
        if (afGameId != null && afGameId.trim().isNotEmpty) {
          return afGameId.trim();
        }
      }
    } catch (_) {}

    return null;
  }

  String? _resolveGameIdForTap() {
    final minigameLink = widget.post.minigameLink?.trim();
    if (minigameLink != null && minigameLink.isNotEmpty) {
      final gameIdFromLink = _extractGameIdFromLink(minigameLink);
      if (gameIdFromLink != null && gameIdFromLink.isNotEmpty) {
        return gameIdFromLink;
      }
    }

    final aiId = widget.repost.id.trim();
    if (aiId.isNotEmpty && aiId != '2') {
      return aiId;
    }

    return null;
  }

  Future<String?> _resolveBackendPostId() async {
    if (_resolvedPostId != null && _resolvedPostId!.isNotEmpty) {
      return _resolvedPostId;
    }

    final rawId = widget.post.id.trim();
    if (rawId.isNotEmpty && !rawId.startsWith('generated_')) {
      _resolvedPostId = rawId;
      return _resolvedPostId;
    }

    final resolved = await InZoneDatabase.resolveRepostPostId(
      textContent: _currentTextContent,
      aiChatContent: widget.aiChat,
    );

    if (resolved != null && resolved.isNotEmpty) {
      _resolvedPostId = resolved;
      return _resolvedPostId;
    }

    return null;
  }

  bool _isPostOwner() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final postIdStr = widget.post.id.toString();
    if (postIdStr.contains(currentUser.uid)) {
      return true;
    }
    if (postIdStr.contains('post_')) {
      final parts = postIdStr.split('_');
      if (parts.length >= 2) {
        final userIdFromPostId = parts[1];
        return currentUser.uid == userIdFromPostId;
      }
    }

    final normalizedRef = widget.post.userReference.trim().toLowerCase();
    if (normalizedRef.isEmpty) return false;

    if (normalizedRef == currentUser.uid.toLowerCase()) {
      return true;
    }

    final currentEmail = currentUser.email?.trim().toLowerCase();
    if (currentEmail != null &&
        currentEmail.isNotEmpty &&
        normalizedRef == currentEmail) {
      return true;
    }

    final currentDisplayName = currentUser.displayName?.trim().toLowerCase();
    if (currentDisplayName != null &&
        currentDisplayName.isNotEmpty &&
        normalizedRef == currentDisplayName) {
      return true;
    }

    return false;
  }

  Future<void> _deletePost() async {
    try {
      const String deletedContent = "[This post has been deleted by the user]";

      final postId = await _resolveBackendPostId();
      if (postId == null) {
        if (!mounted) return;
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message:
              'Could not resolve this repost ID. Please refresh and try again.',
          leading: const Icon(Icons.error, color: Colors.white),
        );
        return;
      }

      bool deleteSuccess = await InZoneDatabase.updatePost(
        postId: postId,
        content: deletedContent,
      );

      if (!mounted) return;

      if (deleteSuccess) {
        setState(() {
          _editedTextContent = deletedContent;
        });
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message: 'Post deleted successfully',
          leading: const Icon(Icons.delete, color: Colors.white),
        );
      } else {
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message: 'Failed to delete post from server',
          leading: const Icon(Icons.error, color: Colors.white),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ToastService.showToast(
        context,
        backgroundColor: Colors.red,
        message: 'Error: Could not delete post',
        leading: const Icon(Icons.error, color: Colors.white),
      );
    }
  }

  Future<void> _updatePost(String newText) async {
    if (newText.isEmpty || newText == _currentTextContent) {
      return;
    }

    try {
      final postId = await _resolveBackendPostId();
      if (postId == null) {
        if (!mounted) return;
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message:
              'Could not resolve this repost ID. Please refresh and try again.',
          leading: const Icon(Icons.error, color: Colors.white),
        );
        return;
      }

      bool updateSuccess = await InZoneDatabase.updatePost(
        postId: postId,
        content: newText,
      );

      if (!mounted) return;

      if (updateSuccess) {
        setState(() {
          _editedTextContent = newText;
        });
        ToastService.showToast(
          context,
          backgroundColor: Colors.green,
          message: 'Post updated successfully',
          leading: const Icon(Icons.check_circle, color: Colors.white),
        );
      } else {
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message: 'Failed to save changes',
          leading: const Icon(Icons.error, color: Colors.white),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ToastService.showToast(
        context,
        backgroundColor: Colors.red,
        message: 'Error: Could not update post',
        leading: const Icon(Icons.error, color: Colors.white),
      );
    }
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: _currentTextContent);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Edit your post content...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _updatePost(controller.text.trim());
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkIfLiked(); // Check if the current post is liked when the widget is initialized
  }

// Function to check if the current post is liked
  Future<void> _checkIfLiked() async {
    bool liked = await LikedPostsPreferences.isPostLiked(
        widget.post.id); // Check if postId is in SharedPreferences
    setState(() {
      isLiked = liked;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return GestureDetector(
      onTap: () {
        // Navigator.push(context, MaterialPageRoute(builder: (context)=>MeScreen()));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
        child: Container(
          constraints: BoxConstraints(
            minHeight: imageSuccess ? 350 : 190,
          ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  // Image.asset(post.profilePicturePath),
                  const Icon(Icons.account_circle,
                      size: 40, color: Colors.grey),
                  const SizedBox(
                    width: 10,
                  ),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.userName,
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        ),
                      ]),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      _showOptionsBottomSheet(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: SvgPicture.asset(
                        CustomIcons.threeDots,
                        height: 40,
                        width: 40,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              _currentTextContent.isEmpty
                  ? const SizedBox()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _currentTextContent,
                        textAlign: TextAlign.start,
                        style:
                            const TextStyle(height: 1.5, color: Colors.black),
                      ),
                    ),
              const SizedBox(
                height: 10,
              ),
              const Divider(
                color: Colors.blue,
              ),
              Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 30,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () async {
                              final gameId = _resolveGameIdForTap();
                              if (gameId == null || gameId.isEmpty) {
                                if (!mounted) return;
                                ToastService.showToast(
                                  context,
                                  backgroundColor: Colors.red,
                                  message:
                                      'Could not determine minigame for this repost.',
                                  leading: const Icon(Icons.error,
                                      color: Colors.white),
                                );
                                return;
                              }

                              try {
                                await AppsFlyerService()
                                    .queueMinigameDeepLink(gameId);
                              } catch (_) {
                                if (!mounted) return;
                                ToastService.showToast(
                                  context,
                                  backgroundColor: Colors.red,
                                  message: 'Could not open minigame.',
                                  leading: const Icon(Icons.error,
                                      color: Colors.white),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Stack(
                                children: [
                                  Image.network(
                                    widget.repost.profilePicture,
                                    fit: BoxFit.fitWidth,
                                    width:
                                        MediaQuery.of(context).size.width - 60,
                                    errorBuilder: (context, object, st) {
                                      return const SizedBox();
                                    },
                                  ),
                                  // Show play icon if this is a minigame accomplishment
                                  if (widget.post.minigameLink != null &&
                                      widget.post.minigameLink!.isNotEmpty)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withOpacity(0.3),
                                        child: const Center(
                                          child: Icon(
                                            Icons.play_circle_fill,
                                            color: Colors.white,
                                            size: 60,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              messageCard(widget.aiChat, false),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // LikeButtonWidget(post: widget.post, liked: isLiked),
                  // const SizedBox(
                  //   width: 10,
                  // ),
                  // InkWell(
                  //     onTap: () {
                  //
                  //       filterSheetModel();
                  //
                  //     },
                  //     child: SizedBox(height: 35, width: 35, child: SvgPicture.asset(CustomIcons.comment))),
                  // const SizedBox(
                  //   width: 10,
                  // ),
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
                  ElevatedButton(
                    onPressed: () {
                      // Update to use go_router
                      context.push(Routes.chat,
                          extra: ChatUser(
                              name: widget.repost.username,
                              email: widget.repost.id,
                              profilePictureURL: widget.repost.profilePicture,
                              chatId: null));
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            16), // Adjust the value to make it less round
                      ),
                    ),
                    child: const Text("Chat"),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    final bool isOwner = _isPostOwner();

    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(30),
            topLeft: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 15),
            if (isOwner) ...[
              ListTile(
                leading: Icon(
                  FeatherIcons.edit,
                  color: Theme.of(context).iconTheme.color,
                  size: 24,
                ),
                title: Text(
                  'Edit Post',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  FeatherIcons.trash2,
                  color: Colors.red,
                  size: 24,
                ),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Delete Post'),
                        content: const Text(
                            'Are you sure you want to delete this post? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _deletePost();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
            ],
            _optionItem(
              CustomIcons.notInterested,
              "Flag this post",
              "not_interested",
            ),
            Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
            _optionItem(
              CustomIcons.dontShow,
              "Block ${widget.post.userName}",
              "dont_show",
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _optionItem(String iconPath, String title, String value) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context); // Close the bottom sheet
        if (value == "chat") {
          String? chatID =
              await InZoneDatabase.startConversation(widget.post.id);
        } else if (value == "not_interested") {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.xCircle,
              color: Colors.redAccent,
            ),
            message: "This post has been flagged for review.",
          );
        } else if (value == "dont_show") {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.xCircle,
              color: Colors.redAccent,
            ),
            message: "Posts from ${widget.post.userName} will not be shown.",
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            SvgPicture.asset(iconPath),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  final TextEditingController _replyController = TextEditingController();
  TextEditingController mySearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String type = '';

  String? selectedCommentId;

  Widget chatInput(String? commentId, String? name) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 2),
      child: Padding(
        padding: EdgeInsets.only(
          left: 15,
          right: 15,
          top: 10,
          bottom: 6,
        ),
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
      ),
    );
  }

  // Add comment to Firestore
  void _addComment() async {
    String commentText = mySearchController.text.trim();
    if (commentText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Clear the input immediately so posting feels instant; restored on error.
    mySearchController.clear();

    final now = DateTime.now().toUtc();

    // New comment to add - full schema shared with PostCard comments.
    Map<String, dynamic> newComment = {
      'id': '${now.millisecondsSinceEpoch}_${user.uid}',
      'author': user.displayName ?? 'Anonymous',
      'text': commentText,
      'userId': user.uid,
      'postId': widget.post.id.toString(),
      'timestamp': now.millisecondsSinceEpoch.toString(),
      'likedBy': [], // Initialize likedBy as an empty list
      'dislikedBy': [],
      'replyCount': 0,
      'parentCommentId': null,
      'isReply': false,
    };

    try {
      // Single atomic write: appends without a prior read and creates the
      // document if it doesn't exist yet.
      await _firestore
          .collection('postComments')
          .doc(widget.post.id.toString())
          .set({
        'comments': FieldValue.arrayUnion([newComment]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error adding comment: $e');
      if (mounted) {
        mySearchController.text = commentText;
      }
    }
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

// Inside the retrieveLikedComments method
  Future<void> retrieveLikedComments() async {
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // likedComments.clear(); // Clear the existing map
    // for (String commentId in prefs.getKeys()) {
    //   if (prefs.getBool(commentId)!) {
    //     likedComments[commentId] = true;
    //   }
    // }
  }

// Inside the retrieveUnLikedComments method
//   Future<void> retrieveUnLikedComments() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     dislikedComments.clear(); // Clear the existing map
//     for (String commentId in prefs.getKeys()) {
//       if (!prefs.getBool(commentId)!) {
//         dislikedComments[commentId] = true;
//       }
//     }
//   }

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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          var width = MediaQuery.of(context).size.width;
          return GestureDetector(
            onTap: () {
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
                      height: 5,
                    ),
                    Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: _firestore
                            .collection('postComments')
                            .doc(widget.post.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            if (snapshot.data!.exists) {
                            } else {}
                            dynamic data =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            data ??= {};
                            final commentsList = data['comments'] ?? [];
                            final comments =
                                commentsList.map<CommentClass>((comment) {
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
                              return Center(
                                child: Text(
                                  'No Comments Available',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                              );
                            }
                            return ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 5, 20, 100),
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
                                          author: comment == null
                                              ? "john!"
                                              : comment!.author,
                                          text: comment == null
                                              ? "Great!"
                                              : comment!.text,
                                          timestamp: "",
                                          replies: [],
                                          id: "",
                                          postId: "",
                                          userId: ""),
                                      const [],
                                      treeThemeData: const TreeThemeData(
                                          lineColor: Colors.blue, lineWidth: 3),
                                      avatarRoot: (context, data) =>
                                          const PreferredSize(
                                        preferredSize: Size.fromRadius(12),
                                        child: Icon(Icons.account_circle,
                                            size: 40, color: Colors.grey),
                                      ),
                                      avatarChild: (context, data) =>
                                          const PreferredSize(
                                        preferredSize: Size.fromRadius(12),
                                        child: Icon(Icons.account_circle,
                                            size: 40, color: Colors.grey),
                                      ),
                                      contentChild: (context, data) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 8),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
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
                                                            color:
                                                                Colors.black),
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
                                                            color:
                                                                Colors.black),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 8),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
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
                    chatInput(
                        comment?.id.toString(), comment?.author.toString())
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
                widget.repost.name,
                style: const TextStyle(color: Colors.blue),
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

// Fullscreen image viewer for repost images
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  _FullScreenImageViewerState createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  bool _isLoading = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _loadImageInfo();
  }

  Future<void> _loadImageInfo() async {
    final imageProvider = NetworkImage(widget.imageUrl);
    final completer = Completer<ImageInfo>();

    final imageStream = imageProvider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        completer.complete(info);
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        completer.completeError(exception);
      },
    );

    imageStream.addListener(listener);

    try {
      await completer.future;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading image: $e');
      setState(() {
        _isLoading = false;
      });
    } finally {
      imageStream.removeListener(listener);
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      // Always use portrait orientation for fullscreen
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Hide system UI
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Exit fullscreen - reset to portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Show system UI
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    // Make sure to reset orientation and UI when viewer is closed
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final Size screenSize = MediaQuery.of(context).size;

    Widget imageWidget = CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.broken_image, size: 64, color: Colors.white),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      body: GestureDetector(
        onTap: _toggleFullscreen,
        child: _isFullscreen
            ? Container(
                width: screenSize.width,
                height: screenSize.height,
                color: Colors.black,
                child: SafeArea(
                  child: Center(child: imageWidget),
                ),
              )
            : Center(child: imageWidget),
      ),
      floatingActionButton: !_isFullscreen
          ? FloatingActionButton(
              onPressed: _toggleFullscreen,
              backgroundColor: Colors.black.withOpacity(0.7),
              mini: true,
              child: const Icon(Icons.fullscreen, color: Colors.white),
            )
          : null,
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
