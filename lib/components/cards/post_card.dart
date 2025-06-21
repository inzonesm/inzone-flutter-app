import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bounce/bounce.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
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
import 'package:visibility_detector/visibility_detector.dart';

import 'package:toasty_box/toast_service.dart';
import 'package:inzone/components/cards/tip_screen.dart';
import 'package:inzone/components/cards/comments_tile.dart';
import 'package:inzone/services/appsflyer_service.dart';

class PostCard extends StatefulWidget {
  InZonePost post;
  final Function(String)? onTap;
  final String? profileImageUrl;
  final bool showHue;
  final bool isAd;
  final bool inProfile;

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
    this.inProfile = false,
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
      // Check if this is an AI post
      if (widget.post.isAi) {
        // For AI posts, try to get the AI user profile using the userName
        final aiUserData =
            await InZoneDatabase.getAIUserProfile(widget.post.userName);

        if (aiUserData != null &&
            aiUserData['profilePicture'] != null &&
            aiUserData['profilePicture'].toString().isNotEmpty) {
          if (mounted) {
            setState(() {
              profileImageUrl = aiUserData['profilePicture'];
            });
          }
          return;
        }

        // If API doesn't return a profile image, try Firestore directly for AI users
        if (widget.post.userName.isNotEmpty) {
          final aiUserDoc = await FirebaseFirestore.instance
              .collection('aiUsers')
              .doc(widget.post.userName)
              .get();

          if (aiUserDoc.exists && aiUserDoc.data() != null) {
            final aiUserDocData = aiUserDoc.data()!;
            final profilePic = aiUserDocData['profilePicture'] ??
                aiUserDocData['profile_picture_url'] ??
                "";

            if (mounted && profilePic.toString().isNotEmpty) {
              setState(() {
                profileImageUrl = profilePic.toString();
              });
            }
          }
        }
      } else {
        // For human posts, use the existing logic
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

    // Start tracking post view time (only for real posts, not ads)
    if (!widget.isAd && widget.post.id != "unknown" && widget.post.id.isNotEmpty) {
      PostViewTracker.startViewingPost(widget.post.id);
    }
  }

  void _loadNativeAd() {
    // Test ad unit IDs for development
    final testAdUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/2247696110' // Test Android native ad unit
        : 'ca-app-pub-3940256099942544/3986624511'; // Test iOS native ad unit

    // Production ad unit IDs
    final prodAdUnitId = Platform.isAndroid
        ? 'ca-app-pub-4474122990542651/3780044430' // Production Android native ad unit
        : 'ca-app-pub-4474122990542651/5132045741'; // Production iOS native ad unit

    // Use test ads in debug mode, production ads in release mode
    final adUnitId = kDebugMode ? testAdUnitId : prodAdUnitId;

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'listTileMedium',
      request: const AdRequest(),
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
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    
    // Stop tracking post view time when widget is disposed
    if (!widget.isAd && widget.post.id != "unknown" && widget.post.id.isNotEmpty) {
      String category = '';
      if (widget.post.category.isNotEmpty) {
        category = widget.post.category;
      } else if (widget.post.mainCategory.isNotEmpty) {
        category = widget.post.mainCategory;
      }
      
      PostViewTracker.stopViewingPost(
        widget.post.id,
        category: category,
        postType: widget.post.isAi ? 'ai_post' : 'human_post',
        authorId: widget.post.userReference,
      );
    }
    
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

    // Track like/unlike event in AppsFlyer
    final userId = AppsFlyerService().getCurrentUserId();
    if (userId != null) {
      String category = '';
      if (widget.post.category.isNotEmpty) {
        category = widget.post.category;
      } else if (widget.post.mainCategory.isNotEmpty) {
        category = widget.post.mainCategory;
      }

      AppsFlyerService().trackPostLike(
        postId: widget.post.id,
        userId: userId,
        isLiked: !currentLikeStatus, // New state after toggle
        category: category.isNotEmpty ? category : null,
        authorId: widget.post.userReference.isNotEmpty ? widget.post.userReference : null,
      );
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
    // If this is an ad and it's loaded, show the ad view with similar styling to regular posts
    if (widget.isAd && _nativeAdIsLoaded) {
      return GestureDetector(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Container(
            width: MediaQuery.of(context).size.width - 30,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fake profile section to match regular posts
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.business,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Sponsored',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'Ad',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 15),
                // Native Ad Content - taking full width and height
                SizedBox(
                  height: 350, // Increased height for better visibility
                  width: double.infinity,
                  child: AdWidget(ad: _nativeAd!),
                ),
                const SizedBox(height: 10),
              ],
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
                        ? CachedNetworkImage(
                            imageUrl: widget.profileImageUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            color: null, // Remove any color overlay
                            colorBlendMode:
                                BlendMode.srcOver, // Use default blend mode
                            placeholder: (context, url) => const SizedBox(),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.account_circle, size: 40),
                          )
                        : profileImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: profileImageUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                color: null, // Remove any color overlay
                                colorBlendMode:
                                    BlendMode.srcOver, // Use default blend mode
                                placeholder: (context, url) => const SizedBox(),
                                errorWidget: (context, url, error) =>
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
                          if (widget.inProfile == true) {
                            return;
                          } else {
                            if (widget.post.isAi) {
                              print(widget.post.userName);
                              context.push(
                                  Routes.aiProfilePath(widget.post.userName));
                            } else {
                              context.push(Routes.regularProfilePath(
                                  widget.post.userReference));
                            }
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
                      _showOptionsBottomSheet(context);
                      HapticFeedback.lightImpact();
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
              FeatherIcons.alertCircle,
              "Report this post",
              "not_interested",
            ),
            _optionItem(
              FeatherIcons.userX,
              "Report ${widget.post.userName}",
              "dont_show",
            ),
            _optionItem(
              FeatherIcons.gift,
              "Tip ${widget.post.userName}",
              "tip",
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
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
          child: VideoWidget(
            videoUrl: videoUrl,
            postId: widget.post.id != "unknown" ? widget.post.id : null,
            category: widget.post.category.isNotEmpty ? widget.post.category : 
                     (widget.post.mainCategory.isNotEmpty ? widget.post.mainCategory : null),
            authorId: widget.post.userReference.isNotEmpty ? widget.post.userReference : null,
          ),
        ),
      ),
    );
  }

  Widget _optionItem(IconData icon, String title, String value) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context); // Close the bottom sheet
        if (value == "not_interested") {
          // Show reason input dialog for post
          _showReportReasonDialog(context);
        } else if (value == "dont_show") {
          // Show reason input dialog for user
          _showReportUserDialog(context);
        } else if (value == "tip") {
          // Show tip dialog
          _showTipDialog(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            if (!title.contains("Report")) const SizedBox(width: 4),
            if (title.contains("Report") && title != "Report this post")
              const SizedBox(width: 5),
            Icon(
              icon,
              size: 28,
            ),
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTipDialog(BuildContext context) {
    // Show TipScreen as a bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: TipScreen(
              recipient: {
                'id': widget.post.userReference,
                'name': widget.post.userName,
                'username':
                    widget.post.userName.toLowerCase().replaceAll(' ', '_'),
                'profilePicture': profileImageUrl,
              },
            ),
          ),
        );
      },
    );
  }

  // Show dialog to get report reason from user for post reporting
  void _showReportReasonDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.report_problem_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Report Post',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    'Please tell us why you\'re reporting this post. This will help us take appropriate action.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Enter reason',
                    hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontSize: 16,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Get the reason text
                        final reason = reasonController.text.trim();
                        if (reason.isNotEmpty) {
                          // Submit report with user's reason
                          _submitPostReport(reason);
                          Navigator.of(context).pop(); // Close dialog
                        } else {
                          // Show error if reason is empty
                          ToastService.showToast(
                            context,
                            backgroundColor: Theme.of(context).canvasColor,
                            shadowColor: Colors.transparent,
                            leading: const Icon(
                              FeatherIcons.xCircle,
                              color: Colors.redAccent,
                            ),
                            message: 'Please enter a reason for reporting',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show dialog to get report reason for user reporting
  void _showReportUserDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_off_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Report ${widget.post.userName}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    'Please tell us why you\'re reporting this user. This will help us maintain a safe environment.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Enter reason',
                    hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontSize: 16,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Get the reason text
                        final reason = reasonController.text.trim();
                        if (reason.isNotEmpty) {
                          // Submit report with user's reason
                          _submitUserReport(reason);
                          Navigator.of(context).pop(); // Close dialog
                        } else {
                          // Show error if reason is empty
                          ToastService.showToast(
                            context,
                            backgroundColor: Theme.of(context).canvasColor,
                            shadowColor: Colors.transparent,
                            leading: const Icon(
                              FeatherIcons.xCircle,
                              color: Colors.redAccent,
                            ),
                            message: 'Please enter a reason for reporting',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Submit post report to Firebase
  void _submitPostReport(String reason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid.isNotEmpty) {
        // Check if a report for this post already exists
        final querySnapshot = await FirebaseFirestore.instance
            .collection('reportPost')
            .where('post_id', isEqualTo: widget.post.id)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Report exists, increment count
          final existingReport = querySnapshot.docs.first;
          final int currentCount = existingReport['count'] ?? 0;

          // Get existing reasons array or create a new one
          List<dynamic> existingReasons = existingReport['reason'] ?? [];
          if (existingReasons is String) {
            // Convert single string to array if needed
            existingReasons = [existingReasons];
          }

          // Get existing reporters array or create a new one
          List<dynamic> existingReporters = existingReport['reporter'] ?? [];
          if (existingReporters is String) {
            // Convert single string to array if needed
            existingReporters = [existingReporters];
          }

          // Get existing dates array or create a new one
          List<dynamic> existingDates = existingReport['date'] ?? [];

          // Add new entries to arrays
          existingReasons.add(reason);
          existingReporters.add(currentUser.uid);

          // Add current timestamp to existing dates
          existingDates.add(Timestamp.now());

          await existingReport.reference.update({
            'count': currentCount + 1,
            'reason': existingReasons, // Update with the array of reasons
            'reporter': existingReporters, // Update with the array of reporters
            'date': existingDates, // Use regular list with Timestamp.now()
          });
        } else {
          // Create new report
          final reportDocRef =
              FirebaseFirestore.instance.collection('reportPost').doc();

          // Get author from post (default to user reference if author is empty)
          String author = widget.post.userReference.isNotEmpty
              ? widget.post.userReference
              : 'unknown';

          await reportDocRef.set({
            'author': author,
            'count': 1, // Initial count
            'date': [
              Timestamp.now()
            ], // Use Timestamp.now() instead of FieldValue.serverTimestamp()
            'post_id': widget.post.id,
            'reason': [reason], // Store reason as array
            'reporter': [currentUser.uid], // Store reporter as array
          });
        }

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
      }
    } catch (e) {
      debugPrint('Error reporting post: $e');
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: "Failed to report post. Please try again.",
      );
    }
  }

  // Submit user report to Firebase
  void _submitUserReport(String reason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid.isNotEmpty) {
        // Check if a report for this user already exists
        final querySnapshot = await FirebaseFirestore.instance
            .collection('reportUser')
            .where('author', isEqualTo: widget.post.userReference)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Report exists, increment count
          final existingReport = querySnapshot.docs.first;
          final int currentCount = existingReport['count'] ?? 0;

          // Get existing reasons array or create a new one
          List<dynamic> existingReasons = existingReport['reason'] ?? [];
          if (existingReasons is String) {
            // Convert single string to array if needed
            existingReasons = [existingReasons];
          }

          // Get existing reporters array or create a new one
          List<dynamic> existingReporters = existingReport['reporter'] ?? [];
          if (existingReporters is String) {
            // Convert single string to array if needed
            existingReporters = [existingReporters];
          }

          // Get existing dates array or create a new one
          List<dynamic> existingDates = existingReport['date'] ?? [];

          // Add new entries to arrays
          existingReasons.add(reason);
          existingReporters.add(currentUser.uid);

          // Add current timestamp to existing dates
          existingDates.add(Timestamp.now());

          await existingReport.reference.update({
            'count': currentCount + 1,
            'reason': existingReasons, // Update with the array of reasons
            'reporter': existingReporters, // Update with the array of reporters
            'date': existingDates, // Use regular list with Timestamp.now()
          });
        } else {
          // Create new report
          final reportDocRef =
              FirebaseFirestore.instance.collection('reportUser').doc();

          // Get author from post (default to user reference if author is empty)
          String author = widget.post.userReference.isNotEmpty
              ? widget.post.userReference
              : 'unknown';

          await reportDocRef.set({
            'author': author, // User being reported
            'count': 1, // Initial count
            'date': [
              Timestamp.now()
            ], // Use Timestamp.now() instead of FieldValue.serverTimestamp()
            'reason': [reason], // Store reason as array
            'reporter': [currentUser.uid], // Store reporter as array
          });
        }

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
    } catch (e) {
      debugPrint('Error reporting user: $e');
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: "Failed to report user. Please try again.",
      );
    }
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
    
    if (commentText.isEmpty) return;
    
    // Track comment event in AppsFlyer
    final userId = AppsFlyerService().getCurrentUserId();
    if (userId != null) {
      String category = '';
      if (widget.post.category.isNotEmpty) {
        category = widget.post.category;
      } else if (widget.post.mainCategory.isNotEmpty) {
        category = widget.post.mainCategory;
      }

      AppsFlyerService().trackPostComment(
        postId: widget.post.id,
        userId: userId,
        commentText: commentText,
        category: category.isNotEmpty ? category : null,
        authorId: widget.post.userReference.isNotEmpty ? widget.post.userReference : null,
      );
    }
    
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
      'author': FirebaseAuth.instance.currentUser!.displayName,
      'text': commentText,
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
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
                              print("FULL COMMENT DATA: $comment");
                              print(
                                  "COMMENT AUTHOR DATA: ${comment['author']}");
                              return CommentClass(
                                author:
                                    comment['author'] ?? comment['name'] ?? '',
                                text: comment['text'] ?? '',
                                replies: [], // Assuming you will handle replies separately
                                timestamp: comment['timestamp'] ?? "",
                                id: '', // Make sure each comment has a unique ID
                                postId: widget.post.id.toString(),
                                userId: comment['userId'] ?? '',
                                likedBy: comment['likedBy'] != null
                                    ? List<String>.from(comment['likedBy'])
                                    : [],
                                dislikedBy: comment['dislikedBy'] != null
                                    ? List<String>.from(comment['dislikedBy'])
                                    : [],
                                profilePictureUrl: '',
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
                                final comment = comments[index];
                                return AnimatedContainer(
                                  duration: const Duration(seconds: 1),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 0.0, vertical: 10),
                                    child: FutureBuilder<DocumentSnapshot>(
                                      future: comment.userId.isNotEmpty
                                          ? FirebaseFirestore.instance
                                              .collection('humanUsers')
                                              .doc(comment.userId)
                                              .get()
                                          : null,
                                      builder: (BuildContext context,
                                          AsyncSnapshot<DocumentSnapshot>
                                              snapshot) {
                                        String username = comment.author;
                                        String profilePicUrl = '';

                                        if (snapshot.hasData &&
                                            snapshot.data != null &&
                                            snapshot.data!.exists) {
                                          final userData = snapshot.data!.data()
                                              as Map<String, dynamic>;
                                          username = userData['username'] ??
                                              userData['name'] ??
                                              comment.author;
                                          profilePicUrl =
                                              userData['profilePicture'] ??
                                                  userData['profileImage'] ??
                                                  '';
                                        }

                                        return CommentsTile(
                                          commentText: comment.text,
                                          profilePictureUrl: profilePicUrl,
                                          author: username,
                                          timestamp: comment.timestamp,
                                          likedBy: comment.likedBy ?? [],
                                          dislikedBy: comment.dislikedBy ?? [],
                                          currentUserId: FirebaseAuth
                                                  .instance.currentUser?.uid ??
                                              '',
                                          onLike: () {
                                            // Implement database update for likes
                                            _updateCommentLikes(
                                                comment, index, comments);
                                          },
                                          onDislike: () {
                                            // Implement database update for dislikes
                                            _updateCommentDislikes(
                                                comment, index, comments);
                                          },
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

  // Add new methods for updating comment likes and dislikes
  void _updateCommentLikes(
      CommentClass comment, int index, List<CommentClass> comments) async {
    try {
      DocumentReference postDocumentReference =
          _firestore.collection('postComments').doc(widget.post.id.toString());

      // Get the document
      DocumentSnapshot postSnapshot = await postDocumentReference.get();
      if (postSnapshot.exists) {
        // Get the comments array
        List<dynamic> commentsList = postSnapshot['comments'] ?? [];

        // Make sure we have the correct index
        if (index < commentsList.length) {
          // Update the likedBy field for the specific comment
          commentsList[index]['likedBy'] = comment.likedBy;

          // If this was previously disliked, update dislikedBy as well
          if (comment.dislikedBy != null) {
            commentsList[index]['dislikedBy'] = comment.dislikedBy;
          }

          // Update the document
          await postDocumentReference.update({'comments': commentsList});
        }
      }
    } catch (e) {
      debugPrint('Error updating comment like: $e');
    }
  }

  void _updateCommentDislikes(
      CommentClass comment, int index, List<CommentClass> comments) async {
    try {
      DocumentReference postDocumentReference =
          _firestore.collection('postComments').doc(widget.post.id.toString());

      // Get the document
      DocumentSnapshot postSnapshot = await postDocumentReference.get();
      if (postSnapshot.exists) {
        // Get the comments array
        List<dynamic> commentsList = postSnapshot['comments'] ?? [];

        // Make sure we have the correct index
        if (index < commentsList.length) {
          // Update the dislikedBy field for the specific comment
          commentsList[index]['dislikedBy'] = comment.dislikedBy;

          // If this was previously liked, update likedBy as well
          if (comment.likedBy != null) {
            commentsList[index]['likedBy'] = comment.likedBy;
          }

          // Update the document
          await postDocumentReference.update({'comments': commentsList});
        }
      }
    } catch (e) {
      debugPrint('Error updating comment dislike: $e');
    }
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

  // 이미지 캐싱을 위한 맵 - 크기 제한 추가
  static final Map<String, ImageProvider> _cachedImages = {};
  static final Map<String, double> _cachedImageHeights = {};
  static final List<String> _cacheQueue = []; // LRU 캐시 관리를 위한 큐
  static const int _maxImageCacheSize = 30; // 최대 30개 이미지만 캐싱

  // 이미지 캐시 정리 함수
  static void _cleanupImageCache() {
    while (_cacheQueue.length > _maxImageCacheSize) {
      String oldestUrl = _cacheQueue.removeAt(0);
      _cachedImages.remove(oldestUrl);
      _cachedImageHeights.remove(oldestUrl);
    }
  }

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

    // 이미지 높이 캐싱
    _cachedImageHeights[key] = newHeight;

    // 캐시 큐 업데이트
    _cacheQueue.remove(key);
    _cacheQueue.add(key);
    _cleanupImageCache();

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
      child: Container(
        // Remove animation, use fixed height instead of AnimatedContainer
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
                  // 캐시된 이미지 높이가 있으면 바로 사용
                  if (_cachedImageHeights.containsKey(imageUrl)) {
                    _heights[index] = _cachedImageHeights[imageUrl]!;
                    if (_currentIndex == index) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _currentHeight = _cachedImageHeights[imageUrl]!;
                          });
                        }
                      });
                    }

                    // 캐시 큐 업데이트 (LRU)
                    _cacheQueue.remove(imageUrl);
                    _cacheQueue.add(imageUrl);
                  }

                  // 캐시된 이미지 있는지 확인
                  ImageProvider? cachedImage;
                  if (_cachedImages.containsKey(imageUrl)) {
                    cachedImage = _cachedImages[imageUrl];
                    // 캐시 큐 업데이트 (LRU)
                    _cacheQueue.remove(imageUrl);
                    _cacheQueue.add(imageUrl);
                  } else {
                    // 저해상도 미리보기 이미지 URL 생성 (가능한 경우)
                    String optimizedUrl = imageUrl;
                    // 고화질 이미지를 중간 해상도로 최적화
                    if (imageUrl.contains('?')) {
                      optimizedUrl = '$imageUrl&quality=70&width=800';
                    } else {
                      optimizedUrl = '$imageUrl?quality=70&width=800';
                    }

                    cachedImage = CachedNetworkImageProvider(
                      optimizedUrl,
                      cacheKey: imageUrl,
                      maxWidth: 800, // 최대 너비 제한
                    );

                    _cachedImages[imageUrl] = cachedImage;
                    _cacheQueue.add(imageUrl);
                    _cleanupImageCache();
                  }

                  return VisibilityDetector(
                    key: Key('image-$imageUrl'),
                    onVisibilityChanged: (info) {
                      // 화면에 보이지 않는 이미지는 캐시에서 우선순위를 낮춤
                      if (info.visibleFraction < 0.1 &&
                          _cacheQueue.contains(imageUrl)) {
                        _cacheQueue.remove(imageUrl);
                        _cacheQueue.insert(
                            0, imageUrl); // 가장 앞으로 이동 (가장 먼저 제거될 수 있도록)
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () {
                          // Open the image in fullscreen
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  _FullScreenImageViewer(imageUrl: imageUrl),
                            ),
                          );
                        },
                        onDoubleTap: () {
                          // Find parent PostCard state and trigger like
                          final PostCard postCard = context
                              .findAncestorWidgetOfExactType<PostCard>()!;
                          final _PostCardState? postCardState =
                              context.findAncestorStateOfType<_PostCardState>();
                          if (postCardState != null) {
                            postCardState.handleLike();
                            HapticFeedback
                                .mediumImpact(); // Add haptic feedback for better UX
                          }
                        },
                        child: Image(
                          image: cachedImage!,
                          fit: BoxFit.contain,
                          color: null, // Remove any color overlay
                          colorBlendMode:
                              BlendMode.srcOver, // Use default blend mode
                          filterQuality: FilterQuality
                              .high, // Ensure high quality rendering
                          gaplessPlayback:
                              true, // Smooth transitions between images
                          isAntiAlias: true, // Enable anti-aliasing
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              // 로딩이 완료된 경우 캐시된 높이가 없으면 높이 계산
                              if (!_cachedImageHeights.containsKey(imageUrl)) {
                                cachedImage!
                                    .resolve(const ImageConfiguration())
                                    .addListener(
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
                              }
                              return child;
                            } else if (_cachedImageHeights
                                .containsKey(imageUrl)) {
                              // 이미지 로딩 중이지만 이미 높이 알고 있는 경우 이전 이미지 표시
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
                      ),
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
                  // 비디오 컨테이너의 기본 크기 설정
                  double width = constraints.maxWidth;
                  // 기본값으로 정사각형(1:1) 비율 사용
                  double aspectRatio = 1;
                  double initialHeight = width / aspectRatio;

                  // 초기 높이 설정
                  _heights[index] = initialHeight;
                  if (_currentIndex == index) {
                    _currentHeight = initialHeight;
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _VideoWidgetWrapper(
                      videoUrl: videoUrl,
                      maxWidth: width,
                      index: index,
                      onAspectRatioUpdated: (aspectRatio) {
                        // 실제 비디오 크기를 받으면 높이 업데이트
                        double calculatedHeight = width / aspectRatio;
                        updateVideoHeight(index, calculatedHeight);
                      },
                      onDoubleTap: () {
                        // Find parent PostCard state and trigger like
                        final _PostCardState? postCardState =
                            context.findAncestorStateOfType<_PostCardState>();
                        if (postCardState != null) {
                          postCardState.handleLike();
                          HapticFeedback.mediumImpact(); // Add haptic feedback
                        }
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
  final Function() onDoubleTap;
  final String? postId; // Add postId for tracking
  final String? category; // Add category for tracking
  final String? authorId; // Add authorId for tracking

  const _VideoWidgetWrapper({
    required this.videoUrl,
    required this.maxWidth,
    required this.index,
    required this.onAspectRatioUpdated,
    required this.onDoubleTap,
    this.postId,
    this.category,
    this.authorId,
  });

  @override
  State<_VideoWidgetWrapper> createState() => _VideoWidgetWrapperState();
}

class _VideoWidgetWrapperState extends State<_VideoWidgetWrapper> {
  final GlobalKey _videoKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Open fullscreen video viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                _FullScreenVideoViewer(videoUrl: widget.videoUrl),
            fullscreenDialog: true,
          ),
        );
      },
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        children: [
          VideoWidget(
            key: _videoKey,
            videoUrl: widget.videoUrl,
            postId: widget.postId,
            category: widget.category,
            authorId: widget.authorId,
            onAspectRatioUpdated: (aspectRatio) {
              // When aspect ratio changes, notify parent
              widget.onAspectRatioUpdated(aspectRatio);
            },
          ),
          // Add fullscreen button overlay
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  // Open fullscreen video viewer
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          _FullScreenVideoViewer(videoUrl: widget.videoUrl),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Fullscreen video viewer with proper orientation handling
class _FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;

  const _FullScreenVideoViewer({required this.videoUrl});

  @override
  _FullScreenVideoViewerState createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<_FullScreenVideoViewer> {
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    // Start in fullscreen mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enterFullscreen();
    });
  }

  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
    });

    // Set landscape orientation for better video viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
    ]);

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
    });

    // Reset to portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Show system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Close the viewer
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    // Make sure to reset orientation and UI when viewer is closed
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        onTap: () {
          // Toggle system UI visibility on tap
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );

          // Hide system UI again after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _isFullscreen) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            }
          });
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Center(
            child: VideoWidget(
              videoUrl: widget.videoUrl,
              onAspectRatioUpdated: (aspectRatio) {
                // Handle aspect ratio updates if needed
              },
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 50.0),
        child: FloatingActionButton(
          onPressed: _exitFullscreen,
          backgroundColor: Colors.black.withOpacity(0.7),
          mini: true,
          child: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}

// Fullscreen image viewer with proper orientation handling
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  _FullScreenImageViewerState createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  bool _isLoading = true;
  double? _imageWidth;
  double? _imageHeight;
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
      final imageInfo = await completer.future;
      setState(() {
        _imageWidth = imageInfo.image.width.toDouble();
        _imageHeight = imageInfo.image.height.toDouble();
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

    Widget imageWidget = Image.network(
      widget.imageUrl,
      fit: BoxFit.contain,
      color: null, // Remove any color overlay
      colorBlendMode: BlendMode.srcOver, // Use default blend mode
      filterQuality: FilterQuality.high, // Ensure high quality rendering
      gaplessPlayback: true, // Smooth transitions between images
      isAntiAlias: true, // Enable anti-aliasing
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, size: 64, color: Colors.white),
        );
      },
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
