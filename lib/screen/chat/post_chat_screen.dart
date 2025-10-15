import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/theme/light_theme.dart'; // Import for ChatTheme extension
import 'package:cached_network_image/cached_network_image.dart';
import 'package:toasty_box/toast_service.dart';

class PostChatScreen extends StatefulWidget {
  String name;
  String? profileImageURL;
  String chat;
  String avatarID;

  PostChatScreen(
      {super.key,
      required this.name,
      required this.profileImageURL,
      required this.chat,
      required this.avatarID});

  @override
  State<PostChatScreen> createState() => _PostChatScreenState();
}

class _PostChatScreenState extends State<PostChatScreen> {
  late DateTime _startTime; // To store the start time
  int pageOpened = 0;
  String? postContent;
  double moveValue = 0.928;
  double high = 0.928;
  double medium = 0.8;
  double low = 0.4;
  double maxWidth = 0.0;
  double maxMovable = 0.928;
  bool doesNotWork = false;

  void setPostContent(String postContentF) {
    postContent = postContentF;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _startTime = DateTime.now().toUtc();
    pageOpened += 1;
  }

  @override
  void dispose() {
    DateTime endTime = DateTime.now().toUtc();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('post_chat_screen',
        {"timeSpent": timeSpent.inSeconds, "pageOpenedCount": pageOpened});

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: theme.iconTheme.color,
              size: 24.0,
            ),
            onPressed: () {
              context.pop();
            },
          ),
          title: Text(
            "Share this chat",
            style: theme.textTheme.titleLarge,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (postContent != null && postContent!.isNotEmpty) {
                  try {
                    // Enhanced sentiment analysis
                    final analysis =
                        await InZoneDatabase.analyzeSentiment(
                          postContent!,
                          imageUrls: [], // No images in chat sharing
                          videoUrls: [], // No videos in chat sharing
                        );

                    // Update state before proceeding with post creation
                    int sentiment = analysis["sentiment"] as int;
                    bool isBlocked = analysis["blocked"] ?? false;
                    
                    setState(() {
                      if (sentiment == -2 || isBlocked) {
                        moveValue = low;
                        doesNotWork = true;
                      } else if (sentiment == -1) {
                        moveValue = low;
                        doesNotWork = true;
                      } else if (sentiment == 0) {
                        moveValue = medium;
                        doesNotWork = false;
                      } else if (sentiment == 1) {
                        moveValue = high;
                        doesNotWork = false;
                      }
                    });

                    // Show error message and return if content is blocked or inappropriate
                    if (sentiment == -2 || isBlocked) {
                      String blockReason = analysis["block_reason"] ?? "Content violates our guidelines";
                      ToastService.showToast(
                        context,
                        backgroundColor: theme.canvasColor,
                        shadowColor: Colors.transparent,
                        leading: const Icon(
                          Icons.error,
                          color: Colors.redAccent,
                        ),
                        message: "Post blocked: $blockReason",
                      );
                      return;
                    }

                    if (sentiment == -1) {
                      ToastService.showToast(
                        context,
                        backgroundColor: theme.canvasColor,
                        shadowColor: Colors.transparent,
                        leading: const Icon(
                          Icons.error,
                          color: Colors.redAccent,
                        ),
                        message:
                            'Your post contains inappropriate content. Please revise and try again.',
                      );
                      return;
                    }

                    // Only proceed with repost if sentiment is acceptable (0 or 1)
                    final result = await InZoneDatabase.createRepost(
                      content: postContent!,
                      aiName: widget.name,
                      aiProfileImageURL: widget.profileImageURL ?? "",
                      aiChatContent: widget.chat,
                      aiId: widget.avatarID,
                      imageRefs: [],
                      videoRefs: [],
                    );

                    if (!result["success"]) {
                      ToastService.showToast(
                        context,
                        backgroundColor: theme.canvasColor,
                        shadowColor: Colors.transparent,
                        leading: const Icon(
                          Icons
                              .error, // or Icons.check_circle, Icons.cancel, etc.
                          color: Colors
                              .redAccent, // or Colors.greenAccent, Colors.orange, etc.
                        ),
                        message: result["error"] ?? 'Failed to create repost',
                      );
                      return;
                    }

                    Navigator.pop(context);
                    ToastService.showToast(
                      context,
                      backgroundColor: theme.colorScheme.primary,
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                      ),
                      message: "Post Successful",
                    );
                  } catch (e) {
                    ToastService.showToast(
                      context,
                      backgroundColor: theme.colorScheme.error,
                      leading: const Icon(
                        Icons.error,
                        color: Colors.redAccent,
                      ),
                      message: 'Error creating repost: $e',
                    );
                  }
                } else {
                  ToastService.showToast(
                    context,
                    backgroundColor: theme.colorScheme.error,
                    leading: const Icon(
                      Icons.error,
                      color: Colors.redAccent,
                    ),
                    message: 'Please enter some text for your post',
                  );
                }
              },
              child: Text(
                'Post',
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
        body: Container(
          color: theme.scaffoldBackgroundColor,
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 6.0,
                      right: 6.0,
                      top: 16.0,
                    ),
                    child: Center(
                      child: Text(
                        doesNotWork
                            ? "Please rephrase. Your message violates our guideline."
                            : "Your post works well with InZone guidelines",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: doesNotWork
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 50,
                    height: 30,
                    child: Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [
                        LayoutBuilder(builder:
                            (BuildContext context, BoxConstraints constraints) {
                          maxWidth = constraints.maxWidth;
                          return Container(
                            height: 14,
                            width: double.infinity,
                            margin: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xffff8d6c),
                                  Color(0xffe064f7),
                                  Color(0xff00b2e7)
                                ],
                              ),
                            ),
                          );
                        }),
                        AnimatedContainer(
                          height: 14,
                          width: 16,
                          margin: EdgeInsets.only(
                              left: maxWidth * maxMovable * moveValue),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(30),
                            color: theme.cardColor,
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      ],
                    ),
                  ),
                  RepostPostCard(
                    name: widget.name,
                    profileImageURL: widget.profileImageURL,
                    chat: widget.chat,
                    avatarID: widget.avatarID,
                    callback: setPostContent,
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

class RepostPostCard extends StatefulWidget {
  final Function(String)? onTap;
  String name;
  String? profileImageURL;
  String chat;
  String avatarID;
  void Function(String) callback;
  RepostPostCard(
      {super.key,
      required this.name,
      required this.profileImageURL,
      required this.chat,
      required this.avatarID,
      this.onTap,
      required this.callback});

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        // Navigator.push(context, MaterialPageRoute(builder: (context)=>MeScreen()));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
        child: Container(
          width: MediaQuery.of(context).size.width - 30,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(15),
          ),
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
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "What do you think about this chat?",
                        hintStyle: TextStyle(color: theme.hintColor),
                      ),
                      onChanged: (text) {
                        widget.callback(text);
                      },
                    ),
                  )
                ]),
                const SizedBox(
                  height: 10,
                ),
                Divider(
                  color: theme.dividerTheme.color,
                  thickness: theme.dividerTheme.thickness,
                ),
                Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 30,
                    child: Center(
                      child: widget.profileImageURL == null
                          ? Icon(
                              Icons.account_circle,
                              size: 40,
                              color: theme.colorScheme.primary,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: CachedNetworkImage(
                                imageUrl: widget.profileImageURL!,
                                fit: BoxFit.fitWidth,
                                width: MediaQuery.of(context).size.width - 60,
                                placeholder: (context, url) => const SizedBox(),
                                errorWidget: (context, url, error) {
                                  return Icon(
                                    Icons.account_circle,
                                    size: 40,
                                    color: theme.colorScheme.primary,
                                  );
                                },
                              ),
                            ),
                    ),
                  ),
                ),
                messageCard(widget.chat, false),
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

  Widget messageCard(String text, bool isMe) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Text(
                widget.name,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? theme.myChatBubbleColor
                          : theme.otherChatBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomRight: isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(18),
                        bottomLeft: isMe
                            ? const Radius.circular(18)
                            : const Radius.circular(0),
                      ),
                    ),
                    child: Text(
                      text,
                      overflow: TextOverflow.visible,
                      softWrap: true,
                      style: TextStyle(
                        color: isMe
                            ? theme.myChatTextColor
                            : theme.otherChatTextColor,
                      ),
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
  final InZonePost post;
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
    _loadLikedState();
  }

  Future<void> _loadLikedState() async {
    bool liked = await LikedPostsPreferences.isPostLiked(widget.post.id);
    setState(() {
      isLiked = liked;
    });
  }

  Future<void> _handleLike() async {
    if (isLiked) {
      await LikedPostsPreferences.removeLikedPost(widget.post.id);
    } else {
      await LikedPostsPreferences.addLikedPost(widget.post);
    }
    setState(() {
      isLiked = !isLiked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleLike,
      child: SizedBox(
        height: 30,
        width: 30,
        child: SvgPicture.asset(
          isLiked ? CustomIcons.like : CustomIcons.notlike,
          colorFilter: ColorFilter.mode(
            isLiked
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).iconTheme.color!,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
