import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comment_tree/widgets/comment_tree_widget.dart';
import 'package:comment_tree/widgets/tree_theme_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/components/video/video_widget.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/screen/profile/profile_screen.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'dart:io' show Platform;

class PostCard extends StatefulWidget {
  InZonePost post;
  final Function(String)? onTap;
  final String? profileImageUrl;
  final bool showHue;
  final bool isAd; // Flag to determine if this is an ad

  InZonePost getPost() {
    return post;
  }

  PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.showHue = true,
    this.profileImageUrl,
    this.isAd = false, // Default to false
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool imageSuccess = false;

  String username = '';
  String profileImageUrl = '';
  CommentClass? comment;
  final PageController _mediaPageController = PageController(
    viewportFraction: 1,
  );

  // Native Ad variables
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  
  // Ad Unit IDs
  final String _androidAdUnitId = 'ca-app-pub-4474122990542651~2720978162';
  final String _iosAdUnitId = 'ca-app-pub-4474122990542651~2508616366';
  
  bool isLiked = false;
  Future<bool> isCommentPresent() async {
    DocumentReference postDocumentReference =
        _firestore.collection('postComments').doc(widget.post.id.toString());

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

  Future<void> _loadUserProfileImage() async {
    try {
      // First try to get image from API
      final userData =
          await InZoneDatabase.getUserProfile(widget.post.userReference);

      if (userData != null &&
          userData['profilePicture'] != null &&
          userData['profilePicture'].toString().isNotEmpty) {
        if (mounted) {
          setState(() {
            profileImageUrl = userData['profilePicture'];
          });
        }
        return;
      }

      // If API doesn't return a profile image or returns empty, try Firestore directly
      if (widget.post.userReference.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(widget.post.userReference)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userDocData = userDoc.data()!;
          final profilePic = userDocData['profilePicture'] ??
              userDocData['profileImage'] ??
              "";

          if (mounted && profilePic.toString().isNotEmpty) {
            setState(() {
              profileImageUrl = profilePic.toString();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile image: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLikedState(); // Load the liked state when the widget is initialized
    _loadUserProfileImage();
    
    // Load native ad if isAd is true
    if (widget.isAd) {
      _loadNativeAd();
    }
  }
  
  void _loadNativeAd() {
    // Use test ad units during development
    final testAdUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/2247696110'  // Android test ad unit
        : 'ca-app-pub-3940256099942544/3986624511'; // iOS test ad unit

    _nativeAd = NativeAd(
      adUnitId: testAdUnitId, // Use test ad unit during development
      factoryId: 'adFactoryExample', // Must match the factory ID registered in native code
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('Native ad loaded');
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          // Dispose the ad here to free resources
          debugPrint('Native ad failed to load: $error');
          ad.dispose();
        },
        onAdClicked: (ad) {
          debugPrint('Native ad clicked');
        },
        onAdImpression: (ad) {
          debugPrint('Native ad impression');
        },
      ),
      request: const AdRequest(),
    );
    
    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the post ID changed, reload the liked state
    if (oldWidget.post.id != widget.post.id) {
      _loadLikedState();
    }
    
    // If the isAd flag changed, load or dispose the ad
    if (oldWidget.isAd != widget.isAd) {
      if (widget.isAd) {
        _loadNativeAd();
      } else {
        _nativeAd?.dispose();
        _nativeAd = null;
        _nativeAdIsLoaded = false;
      }
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
      if (mounted) {
        // Check if the widget is still in the tree
        setState(() {
          isCommentPresentbool = value;
        });
      }
    });
  }

  bool isCommentPresentbool = false;
  @override
  Widget build(BuildContext context) {
    // If this is an ad and it's loaded, show the ad view
    if (widget.isAd && _nativeAdIsLoaded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Container(
          height: 250, // Fixed height instead of constraints
          width: MediaQuery.of(context).size.width - 30,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 250, // Fixed height for the AdWidget
              child: AdWidget(ad: _nativeAd!),
            ),
          ),
        ),
      );
    }

    checkComment();

    final validImages = widget.post.imageContent
        .where((url) =>
            url.isNotEmpty &&
            (url.startsWith('http') || url.startsWith('https')))
        .toList();

    final validVideos = widget.post.videoContent
        .where((url) =>
            url.isNotEmpty &&
            (url.startsWith('http') || url.startsWith('https')))
        .toList();

    final totalMediaCount = validImages.length + validVideos.length;

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
              border: Border.all(
                color: (!widget.post.isAi && widget.showHue)
                    ? Colors.lightBlueAccent.withOpacity(0.5)
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                // Uncomment the following lines if you want to add a blue hue effect
                // Only add blue hue for human posts (not AI)
                // if (!widget.post.isAi && widget.showHue)
                //   BoxShadow(
                //     color: Colors.lightBlueAccent
                //         .withOpacity(0.5), // Blue hue color
                //     spreadRadius: 5, // Spread of the hue
                //     blurRadius: 12, // Soft edges for blending
                //     offset: const Offset(
                //         0, 0), // Center the glow around the container
                //   ),
              ],
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: widget.profileImageUrl != null
                        ? Image.network(
                            widget.profileImageUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.account_circle, size: 40),
                          )
                        : profileImageUrl.isNotEmpty
                            ? Image.network(
                                profileImageUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.account_circle, size: 40),
                              )
                            : const Icon(Icons.account_circle, size: 40),
                  ),
                  // Image.asset(post.profilePicturePath),
                  // RandomAvatar(widget.post.userName, height: 40, width: 40),

                  const SizedBox(
                    width: 10,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (widget.post.isAi) {
                            print(widget.post.userName);
                            context.push(
                                Routes.aiProfilePath(widget.post.userName));
                          } else {
                            context.push(Routes.regularProfilePath(
                                widget.post.userReference));
                          }
                        },
                        child: SizedBox(
                          width: 230,
                          child: Text(
                            widget.post.userName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.titleLarge?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showOptionsBottomSheet(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Icon(
                        Icons.more_horiz,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
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
                        style: TextStyle(
                            height: 1,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                    ),
              (validImages.isNotEmpty || validVideos.isNotEmpty)
                  ? const SizedBox(height: 30)
                  : const SizedBox(height: 10),
              (validImages.isNotEmpty || validVideos.isNotEmpty)
                  ? _DynamicPageView(
                      images: validImages,
                      videos: validVideos,
                      controller: _mediaPageController,
                    )
                  : const SizedBox(),
              const SizedBox(
                height: 10,
              ),
              Column(
                children: [
                  if (totalMediaCount > 1)
                    SmoothPageIndicator(
                      controller: _mediaPageController,
                      count: totalMediaCount,
                      effect: ScrollingDotsEffect(
                        activeDotColor: Theme.of(context).primaryColor,
                        dotColor: AppColors.lightGrey,
                        dotHeight: 8,
                        dotWidth: 8,
                        activeDotScale: 1.4,
                        spacing: 8,
                        maxVisibleDots: 5,
                      ),
                    ),
                  if (totalMediaCount > 1) const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        onTap: handleLike, // Toggle like/unlike when tapped
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: SvgPicture.asset(
                            isLiked
                                ? CustomIcons.like
                                : CustomIcons
                                    .notlike, // Show correct icon based on state
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
                      // if (isCommentPresentbool == true)
                      GestureDetector(
                          onTap: () {
                            filterSheetModel();
                          },
                          child: isCommentPresentbool
                              ? SizedBox(
                                  height: 25,
                                  width: 25,
                                  child: SvgPicture.asset(
                                    CustomIcons
                                        .comment, // Show correct icon based on state
                                  ),
                                )
                              : SizedBox(
                                  height: 25,
                                  width: 25,
                                  child: SvgPicture.asset(
                                    CustomIcons
                                        .uncomment, // Show correct icon based on state
                                  ),
                                )),
                      // if (isCommentPresentbool == false)
                      //   InkWell(
                      //       onTap: () {
                      //         filterSheetModel();
                      //       },
                      //       child: SizedBox(
                      //           height: 35,
                      //           width: 35,
                      //           child: Image.asset(CustomIcons.uncomment))),
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
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    Future.microtask(() {
      showModalBottomSheet(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        context: context,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(30),
              topLeft: Radius.circular(30),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _optionItem(
                CustomIcons.notInterested,
                "Flag this post",
                "not_interested",
              ),
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
    });
  }

  Widget _buildVideoWidget(String videoUrl, double aspectRatio) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: VideoWidget(videoUrl: videoUrl),
        ),
      ),
    );
  }

  Widget _optionItem(String iconPath, String title, String value) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context); // Close the bottom sheet
        if (value == "not_interested") {
          const snackBar = SnackBar(
            content: Text("This post has been flagged for review."),
            backgroundColor: Colors.red,
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        } else if (value == "dont_show") {
          final snackBar = SnackBar(
            content:
                Text("Posts from ${widget.post.userName} will not be shown."),
            backgroundColor: Colors.red,
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
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
                  cursorColor: Theme.of(context).colorScheme.primary,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
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
                    suffixIconColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                    contentPadding:
                        const EdgeInsets.only(top: 10, left: 16, right: 16),
                    border: InputBorder.none,
                    hintText: type == 'Reply' ? 'Add Reply' : 'Add Comment',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).hintColor,
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.3),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
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
            color: Theme.of(context).colorScheme.primary,
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
    DocumentReference postDocumentReference =
        _firestore.collection('postComments').doc(widget.post.id.toString());

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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.56,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                    topLeft: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(
                      height: 15,
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
                                      // treeThemeData: const TreeThemeData(
                                      //     lineColor: Colors.transparent,
                                      //     lineWidth: 0),
                                      avatarRoot: (context, data) =>
                                          const PreferredSize(
                                        preferredSize: Size.fromRadius(12),
                                        child: Icon(Icons.account_circle,
                                            size: 40),
                                      ),
                                      avatarChild: (context, data) =>
                                          const PreferredSize(
                                        preferredSize: Size.fromRadius(12),
                                        child: Icon(Icons.account_circle,
                                            size: 40),
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
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withOpacity(0.5),
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
                                                            color: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .titleMedium
                                                                ?.color),
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
                                                            color: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.color),
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
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withOpacity(0.5),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${data.content}',
                                                    style: TextStyle(
                                                        color: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.color),
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
}

class _DynamicPageView extends StatefulWidget {
  final List<String> images;
  final List<String> videos;
  final PageController controller;

  const _DynamicPageView({
    super.key,
    required this.images,
    required this.videos,
    required this.controller,
  });

  @override
  State<_DynamicPageView> createState() => _DynamicPageViewState();
}

class _DynamicPageViewState extends State<_DynamicPageView> {
  double _currentHeight = 200;
  final Map<int, double> _heights = {};
  final Set<String> _loadedItems = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      int newIndex = widget.controller.page?.round() ?? 0;
      if (newIndex != _currentIndex) {
        _currentIndex = newIndex;
        double newHeight = _heights[_currentIndex] ?? 200;
        setState(() {
          _currentHeight = newHeight;
        });
      }
    });
  }

  void _updateHeightOnce(String key, int index, double newHeight) {
    final id = '$key-$index';
    if (_loadedItems.contains(id)) return;
    _loadedItems.add(id);
    _heights[index] = newHeight;

    if (_currentIndex == index && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentHeight = newHeight;
        });
      });
    }
  }

  // Allow external updates of the height (used by VideoWidget)
  void updateVideoHeight(int index, double newHeight) {
    if (_heights[index] != newHeight) {
      _heights[index] = newHeight;
      
      if (_currentIndex == index && mounted) {
        setState(() {
          _currentHeight = newHeight;
        });
      }
    }
  }

  bool _isValidUrl(String url) {
    return url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  @override
  Widget build(BuildContext context) {
    final validImages = widget.images.where((url) => _isValidUrl(url)).toList();
    final totalItems = validImages.length + widget.videos.length;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastEaseInToSlowEaseOut,
        height: _currentHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: PageView.builder(
          controller: widget.controller,
          itemCount: totalItems,
          itemBuilder: (context, index) {
            if (index < validImages.length) {
              final imageUrl = validImages[index];
              return LayoutBuilder(
                builder: (context, constraints) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          final image = NetworkImage(imageUrl);
                          image.resolve(const ImageConfiguration()).addListener(
                                ImageStreamListener((imageInfo, _) {
                                  double calculatedHeight =
                                      imageInfo.image.height *
                                          (constraints.maxWidth /
                                              imageInfo.image.width);
                                  _updateHeightOnce(
                                      imageUrl, index, calculatedHeight);
                                }, onError: (error, stackTrace) {
                                  debugPrint('Image load error: $error');
                                }),
                              );
                          return child;
                        } else {
                          return Center(child: ImageLoading(context));
                        }
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint("Failed to load image: $imageUrl");
                        return const Icon(Icons.broken_image, size: 48);
                      },
                    ),
                  );
                },
              );
            } else {
              final videoIndex = index - validImages.length;
              final videoUrl = widget.videos[videoIndex];
              if (!_isValidUrl(videoUrl)) return const SizedBox();

              return LayoutBuilder(
                builder: (context, constraints) {
                  // Initial height based on 16:9 aspect ratio - will be updated when video loads
                  double initialHeight = constraints.maxWidth * 9 / 16;
                  _updateHeightOnce(videoUrl, index, initialHeight);
                  
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _VideoWidgetWrapper(
                      videoUrl: videoUrl,
                      maxWidth: constraints.maxWidth,
                      index: index,
                      onAspectRatioUpdated: (aspectRatio) {
                        double calculatedHeight = constraints.maxWidth / aspectRatio;
                        updateVideoHeight(index, calculatedHeight);
                      },
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

// Wrapper widget to communicate between VideoWidget and _DynamicPageView
class _VideoWidgetWrapper extends StatefulWidget {
  final String videoUrl;
  final double maxWidth;
  final int index;
  final Function(double) onAspectRatioUpdated;

  const _VideoWidgetWrapper({
    required this.videoUrl,
    required this.maxWidth,
    required this.index,
    required this.onAspectRatioUpdated,
  });

  @override
  State<_VideoWidgetWrapper> createState() => _VideoWidgetWrapperState();
}

class _VideoWidgetWrapperState extends State<_VideoWidgetWrapper> {
  final GlobalKey _videoKey = GlobalKey();
  
  @override
  Widget build(BuildContext context) {
    return VideoWidget(
      key: _videoKey,
      videoUrl: widget.videoUrl,
      onAspectRatioUpdated: (aspectRatio) {
        // When aspect ratio changes, notify parent
        widget.onAspectRatioUpdated(aspectRatio);
      },
    );
  }
}
