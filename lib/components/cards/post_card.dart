import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/components/video/video_widget.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/data/comment_class.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'dart:io' show Platform;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:inzone/components/cards/comments_tile.dart';
import 'package:inzone/components/cards/tip_screen.dart';
import 'package:inzone/components/translation/translatable_text.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:inzone/services/notification_event_service.dart';

class PostCard extends StatefulWidget {
  InZonePost post;
  final Function(String)? onTap;
  final String? profileImageUrl;
  final bool showHue;
  final bool isAd;
  final bool inProfile;
  final Function()? onAdLoaded;
  final bool autoOpenComments; // New field to auto-open comments
  final String? targetCommentId; // ID of comment to navigate to
  final String? targetReplyId; // ID of reply to navigate to
  final bool autoExpandReplies; // Auto-expand replies section
  final Function(String)? onDeleted; // Callback for when post is deleted
  final Function(InZonePost)? onUpdated; // Callback for when post is updated

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
    this.onAdLoaded,
    this.autoOpenComments = false, // New parameter to auto-open comments
    this.targetCommentId, // ID of comment to navigate to
    this.targetReplyId, // ID of reply to navigate to
    this.autoExpandReplies = false, // Auto-expand replies section
    this.onDeleted, // Callback for when post is deleted
    this.onUpdated, // Callback for when post is updated
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with AutomaticKeepAliveClientMixin {
  bool imageSuccess = false;

  String username = '';
  String profileImageUrl = '';
  String _actualUsername = ''; // Add state for actual username
  CommentClass? comment;
  final PageController _mediaPageController = PageController(
    viewportFraction: 1,
  );

  // Native Ad variables
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  // Add this variable to track influencer status
  bool _isInfluencer = false;

  // Target comment highlighting for navigation
  String? _highlightedCommentId;

  // Map to store GlobalKeys for each comment for precise scrolling
  final Map<String, GlobalKey> _commentKeys = {};

  // Ad Unit IDs
  final String _androidAdUnitId = 'ca-app-pub-4474122990542651~2720978162';
  final String _iosAdUnitId = 'ca-app-pub-4474122990542651~2508616366';

  bool isLiked = false;

  // Local override for post text content during editing
  String? _editedTextContent;

  // Get current text content (edited version if available, otherwise original)
  String get _currentTextContent =>
      _editedTextContent ?? widget.post.textContent;

  // Check if current user owns this post
  bool _isPostOwner() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    // Direct approach: Extract user ID from post ID pattern
    // Post IDs follow pattern: post_USERID_timestamp
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

  Future<String?> _resolveBackendPostId() async {
    final rawId = widget.post.id.trim();
    if (rawId.isNotEmpty && !rawId.startsWith('generated_')) {
      return rawId;
    }

    return InZoneDatabase.resolveOwnedPostIdByText(
      textContent: _currentTextContent,
    );
  }

  // Delete post functionality
  Future<void> _deletePost() async {
    try {
      print('Attempting to delete post: ${widget.post.id}');
      const String deletedContent = "[This post has been deleted by the user]";

      final postId = await _resolveBackendPostId();
      if (postId == null) {
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message:
              'Could not resolve this post ID. Please refresh and try again.',
          leading: const Icon(Icons.error, color: Colors.white),
        );
        return;
      }

      bool deleteSuccess = await InZoneDatabase.updatePost(
        postId: postId,
        content: deletedContent,
      );

      if (deleteSuccess) {
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message: 'Post deleted successfully',
          leading: const Icon(Icons.delete, color: Colors.white),
        );

        // Call onDeleted callback if provided
        if (widget.onDeleted != null) {
          widget.onDeleted!(widget.post.id);
        }

        print('Post deletion completed successfully');
      } else {
        // Backend deletion failed
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message: 'Failed to delete post from server',
          leading: const Icon(Icons.error, color: Colors.white),
        );
        print('❌ Backend deletion failed for post: ${widget.post.id}');
      }
    } catch (e) {
      print('❌ Error deleting post: $e');
      ToastService.showToast(
        context,
        backgroundColor: Colors.red,
        message: 'Error: Could not delete post',
        leading: const Icon(Icons.error, color: Colors.white),
      );
    }
  }

  // Navigate to full edit post screen
  void _navigateToEditPost() async {
    final result = await context.push<InZonePost>(
      Routes.editPost,
      extra: widget.post,
    );

    if (result != null && mounted) {
      // Update local state with the edited post
      setState(() {
        _editedTextContent = result.textContent;
        widget.post = result;
      });

      // Notify parent widgets
      if (widget.onUpdated != null) {
        widget.onUpdated!(result);
      }
    }
  }

  // Show edit post dialog
  void _showEditDialog() {
    final TextEditingController editController =
        TextEditingController(text: _currentTextContent);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: editController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Edit your post content...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updatePost(editController.text.trim());
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  // Update post content
  Future<void> _updatePost(String newText) async {
    if (newText.isEmpty) {
      ToastService.showToast(
        context,
        backgroundColor: Colors.red,
        message: 'Post content cannot be empty',
        leading: const Icon(Icons.error, color: Colors.white),
      );
      return;
    }

    if (newText == _currentTextContent) {
      ToastService.showToast(
        context,
        backgroundColor: Colors.grey,
        message: 'No changes made',
        leading: const Icon(Icons.info, color: Colors.white),
      );
      return;
    }

    try {
      print('Updating post: ${widget.post.id}');
      print('Old text: "$_currentTextContent"');
      print('New text: "$newText"');

      // Show loading toast
      ToastService.showToast(
        context,
        backgroundColor: Colors.blue,
        message: 'Saving changes...',
        leading: const Icon(Icons.sync, color: Colors.white),
      );

      final postId = await _resolveBackendPostId();
      if (postId == null) {
        if (!mounted) return;
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message:
              'Could not resolve this post ID. Please refresh and try again.',
          leading: const Icon(Icons.error, color: Colors.white),
        );
        return;
      }

      // Call the backend API to update the post
      bool updateSuccess = await InZoneDatabase.updatePost(
        postId: postId,
        content: newText,
      );

      if (updateSuccess) {
        // Update local state to override the original text content
        setState(() {
          _editedTextContent = newText;
        });

        // Create a new post object with updated content for parent widgets
        if (widget.onUpdated != null) {
          final updatedPost = InZonePost(
            category: widget.post.category,
            userName: widget.post.userName,
            comments: widget.post.comments,
            datePosted: widget.post.datePosted,
            likes: widget.post.likes,
            id: widget.post.id,
            imageContent: widget.post.imageContent,
            videoContent: widget.post.videoContent,
            textContent: newText, // Updated text content
            userReference: widget.post.userReference,
            mainCategory: widget.post.mainCategory,
            isAi: widget.post.isAi,
            characterInfo: widget.post.characterInfo,
          );
          widget.onUpdated!(updatedPost);
        }

        // Show success message
        ToastService.showToast(
          context,
          backgroundColor: Colors.green,
          message: 'Post updated successfully!',
          leading: const Icon(Icons.check_circle, color: Colors.white),
        );

        print('Post update completed successfully');
      } else {
        // Backend update failed
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message: 'Failed to save changes to server',
          leading: const Icon(Icons.error, color: Colors.white),
        );
        print('❌ Backend update failed for post: ${widget.post.id}');
      }
    } catch (e) {
      print('❌ Error updating post: $e');
      ToastService.showToast(
        context,
        backgroundColor: Colors.red,
        message: 'Error: Could not update post',
        leading: const Icon(Icons.error, color: Colors.white),
      );
    }
  }

  // Override wantKeepAlive to keep this widget in memory when scrolled out of view
  @override
  bool get wantKeepAlive => true;

  // Get or create a GlobalKey for a specific comment
  GlobalKey _getCommentKey(String commentId) {
    if (!_commentKeys.containsKey(commentId)) {
      _commentKeys[commentId] = GlobalKey();
    }
    return _commentKeys[commentId]!;
  }

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

        if (userData != null) {
          if (mounted) {
            setState(() {
              if (userData['profilePicture'] != null &&
                  userData['profilePicture'].toString().isNotEmpty) {
                profileImageUrl = userData['profilePicture'];
              }
              if (userData['username'] != null &&
                  userData['username'].toString().isNotEmpty) {
                _actualUsername = userData['username'];
              }
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
            final username = userDocData['username'] ?? "";

            if (mounted) {
              setState(() {
                if (profilePic.toString().isNotEmpty) {
                  profileImageUrl = profilePic.toString();
                }
                if (username.toString().isNotEmpty) {
                  _actualUsername = username.toString();
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile image: $e');
    }
  }

  // Build a likedBy entry for the current user using the same logic as profile/follow
  Future<Map<String, dynamic>> _buildLikeEntryForCurrentUser(String uid) async {
    String username = '';
    String type = 'human';

    try {
      // Try to get normalized profile for current user
      final profile = await InZoneDatabase.getCurrentUserProfile();
      if (profile != null) {
        username = profile['username'] ?? profile['name'] ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching current user profile for like entry: $e');
    }

    // Fallback to Firebase Auth displayName
    if (username.isEmpty) {
      username = FirebaseAuth.instance.currentUser?.displayName ?? '';
    }

    // Default type is human for logged-in users; keep as 'human' unless other logic needed
    return {
      'id': uid,
      'username': username,
      'type': type,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadLikedState(); // Load the liked state when the widget is initialized
    if (widget.post.characterInfo == null) {
      _loadUserProfileImage();
    }
    _checkIfInfluencer();

    // Load native ad if isAd is true
    if (widget.isAd) {
      _loadNativeAd();
    }

    // Start tracking post view time (only for real posts, not ads)
    if (!widget.isAd &&
        widget.post.id != "unknown" &&
        widget.post.id.isNotEmpty) {
      PostViewTracker.startViewingPost(widget.post.id);

      // Track view for Gorse recommendation engine (non-blocking)
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          InZoneDatabase.trackPostView(userId, widget.post.id).catchError((e) {
            print('View tracking failed: $e');
          });
        });
      }
    }

    // Auto-open comments if requested
    if (widget.autoOpenComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        filterSheetModel();

        // Handle auto-expanding replies and navigating to specific comments/replies
        if (widget.autoExpandReplies && widget.targetCommentId != null) {
          // Auto-expand replies for the target comment
          setState(() {
            _expandedReplies.add(widget.targetCommentId!);
          });
          _expandedRepliesNotifier.value = Set.from(_expandedReplies);
        }

        // If there's a target reply, just expand and navigate (don't start replying)
        if (widget.targetReplyId != null && widget.targetCommentId != null) {
          // Longer delay to ensure comments are fully loaded
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              // Ensure we're NOT in reply mode when navigating
              setState(() {
                selectedCommentId = null;
                selectedCommentAuthor = null;
                showReplyComposer = false;
                type = '';
              });

              // Clear reactive notifiers to prevent reply interface
              _replyComposerNotifier.value = false;
              _selectedCommentNotifier.value = null;

              // Scroll to the target comment with multiple attempts
              _scrollToCommentWithRetry(widget.targetCommentId!, 3);
            }
          });
        }
      });
    }
  }

  Future<void> _checkIfInfluencer() async {
    if (widget.post.isAi) {
      return;
    }

    final userUid = widget.post.userReference;
    if (userUid.isEmpty) {
      return;
    }

    try {
      final influencerDoc = await FirebaseFirestore.instance
          .collection('influencers')
          .doc(userUid)
          .get();

      if (influencerDoc.exists) {
        setState(() {
          _isInfluencer = true;
        });
      } else {
        setState(() {
          _isInfluencer = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking for influencer status: $e');
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
          if (mounted) {
            setState(() {
              _nativeAdIsLoaded = true;
            });
            widget.onAdLoaded?.call();
          }
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
    if (!widget.isAd &&
        widget.post.id != "unknown" &&
        widget.post.id.isNotEmpty) {
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

    _textFieldFocusNode.dispose(); // Dispose focus node
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
    // Optimistic UI: toggle immediately so animation is instant
    final bool newLikeState = !isLiked;
    setState(() {
      isLiked = newLikeState;
    });

    // Update SharedPreferences immediately (fire-and-forget inside background task)
    Future<void>(() async {
      try {
        if (newLikeState) {
          await LikedPostsPreferences.addLikedPost(widget.post);
        } else {
          await LikedPostsPreferences.removeLikedPost(widget.post.id);
        }
      } catch (e) {
        debugPrint('Error updating local liked prefs: $e');
      }
    });

    // Do backend updates in background. If they fail, rollback the optimistic UI and prefs.
    Future<void>(() async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid.isEmpty) return;

      final String currentUid = currentUser.uid;
      final String postId = widget.post.id;
      final bool isRepost = postId.startsWith('repost_');
      final collectionName =
          isRepost ? 'reposts' : (widget.post.isAi ? 'aiPosts' : 'humanPosts');
      final docRef =
          FirebaseFirestore.instance.collection(collectionName).doc(postId);

      try {
        final likeEntry = await _buildLikeEntryForCurrentUser(currentUid);

        if (newLikeState) {
          // Use a transaction to ensure we only add the like entry when an entry
          // for this user doesn't already exist (avoid duplicates due to map inequality)
          bool didAddLike = false;
          try {
            didAddLike = await FirebaseFirestore.instance
                .runTransaction<bool>((tx) async {
              final snap = await tx.get(docRef);
              final likeEntryLocal = likeEntry; // capture

              if (!snap.exists) {
                // Create doc with likedBy array
                tx.set(
                    docRef,
                    {
                      'likedBy': [likeEntryLocal]
                    },
                    SetOptions(merge: true));
                return true;
              }

              final data = snap.data() as Map<String, dynamic>;
              final List<dynamic> likedBy =
                  List<dynamic>.from(data['likedBy'] ?? []);

              final alreadyExists = likedBy.any((entry) {
                try {
                  if (entry is Map) {
                    return entry['id'] == currentUid;
                  }
                } catch (e) {}
                return false;
              });

              if (!alreadyExists) {
                likedBy.add(likeEntryLocal);
                tx.update(docRef, {'likedBy': likedBy});
                return true;
              }

              return false;
            });
          } catch (e) {
            debugPrint('Error adding like in transaction: $e');
            rethrow;
          }

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
              isLiked: true,
              category: category.isNotEmpty ? category : null,
              authorId: widget.post.userReference.isNotEmpty
                  ? widget.post.userReference
                  : null,
            );

            // Track like for Gorse recommendation engine
            InZoneDatabase.trackPostLike(userId, widget.post.id);

            if (didAddLike) {
              try {
                // Avoid notifying if there's no author to notify or if the
                // liker is the author.
                final String? authorId = widget.post.userReference.isNotEmpty
                    ? widget.post.userReference
                    : null;
                if (authorId != null && authorId != userId) {
                  // FIRST: Resolve the author ID to a proper Firebase UID
                  // The post's author reference can be in multiple forms
                  // (doc id, username, or stored uid), so try several lookups.
                  String? resolvedAuthorUid;
                  String resolvedAuthorUsername = authorId; // default fallback

                  try {
                    final humanUsersRef =
                        FirebaseFirestore.instance.collection('humanUsers');
                    DocumentSnapshot? authorDoc;

                    // 1) Try doc(id)
                    final byId = await humanUsersRef.doc(authorId).get();
                    if (byId.exists) {
                      authorDoc = byId;
                    } else {
                      // 2) Try username == authorId
                      final q1 = await humanUsersRef
                          .where('username', isEqualTo: authorId)
                          .limit(1)
                          .get();
                      if (q1.docs.isNotEmpty) {
                        authorDoc = q1.docs.first;
                      } else {
                        // 3) Try uid == authorId
                        final q2 = await humanUsersRef
                            .where('uid', isEqualTo: authorId)
                            .limit(1)
                            .get();
                        if (q2.docs.isNotEmpty) {
                          authorDoc = q2.docs.first;
                        } else {
                          // 4) Try legacy user_document_id field
                          final q3 = await humanUsersRef
                              .where('user_document_id', isEqualTo: authorId)
                              .limit(1)
                              .get();
                          if (q3.docs.isNotEmpty) {
                            authorDoc = q3.docs.first;
                          }
                        }
                      }
                    }

                    if (authorDoc != null && authorDoc.exists) {
                      final data = authorDoc.data() as Map<String, dynamic>;
                      resolvedAuthorUid = data['uid'] ?? authorDoc.id;
                      resolvedAuthorUsername = data['username'] ??
                          data['name'] ??
                          resolvedAuthorUsername;
                      debugPrint(
                          'Resolved author "$authorId" -> uid: $resolvedAuthorUid username: $resolvedAuthorUsername');
                    } else {
                      debugPrint(
                          'Could not resolve authorId "$authorId" to humanUsers doc - skipping notification');
                    }
                  } catch (e) {
                    debugPrint('Error resolving author for notification: $e');
                  }

                  // Only send notification if we successfully resolved to a UID
                  if (resolvedAuthorUid != null &&
                      resolvedAuthorUid != userId) {
                    // Fire the server-side notification pipeline (best-effort)
                    try {
                      await NotificationEventService.onPostEngagement(
                        postId: widget.post.id,
                        type: 'like',
                        userId: userId,
                        postAuthorId: resolvedAuthorUid, // Use resolved UID
                      );
                    } catch (e) {
                      debugPrint('NotificationEventService failed: $e');
                    }
                  }

                  try {
                    final notifRef =
                        FirebaseFirestore.instance.collection('notifications');

                    // Try to resolve the canonical human user document for the
                    // author. The post's author reference can be in multiple forms
                    // (doc id, username, or stored uid), so try several lookups.
                    final humanUsersRef =
                        FirebaseFirestore.instance.collection('humanUsers');
                    DocumentSnapshot? authorDoc;
                    String? resolvedAuthorUid;
                    String resolvedAuthorUsername =
                        authorId; // default fallback

                    try {
                      // 1) Try doc(id)
                      final byId = await humanUsersRef.doc(authorId).get();
                      if (byId.exists) {
                        authorDoc = byId;
                      } else {
                        // 2) Try username == authorId
                        final q1 = await humanUsersRef
                            .where('username', isEqualTo: authorId)
                            .limit(1)
                            .get();
                        if (q1.docs.isNotEmpty) {
                          authorDoc = q1.docs.first;
                        } else {
                          // 3) Try uid == authorId
                          final q2 = await humanUsersRef
                              .where('uid', isEqualTo: authorId)
                              .limit(1)
                              .get();
                          if (q2.docs.isNotEmpty) {
                            authorDoc = q2.docs.first;
                          } else {
                            // 4) Try legacy user_document_id field
                            final q3 = await humanUsersRef
                                .where('user_document_id', isEqualTo: authorId)
                                .limit(1)
                                .get();
                            if (q3.docs.isNotEmpty) {
                              authorDoc = q3.docs.first;
                            }
                          }
                        }
                      }

                      if (authorDoc != null && authorDoc.exists) {
                        final data = authorDoc.data() as Map<String, dynamic>;
                        resolvedAuthorUid = data['uid'] ?? authorDoc.id;
                        resolvedAuthorUsername = data['username'] ??
                            data['name'] ??
                            resolvedAuthorUsername;
                        debugPrint(
                            'Resolved author "$authorId" -> uid: $resolvedAuthorUid username: $resolvedAuthorUsername');
                      } else {
                        debugPrint(
                            'Skipping fallback notification: could not resolve authorId "$authorId" to humanUsers doc');
                      }
                    } catch (e) {
                      debugPrint(
                          'Error resolving humanUsers author for fallback notification: $e');
                    }

                    if (resolvedAuthorUid != null) {
                      final query = await notifRef
                          .where('userId', isEqualTo: resolvedAuthorUid)
                          .where('data.engagerUserId', isEqualTo: currentUid)
                          .where('data.postId', isEqualTo: widget.post.id)
                          .where('data.engagementType', isEqualTo: 'like')
                          .limit(1)
                          .get();

                      if (query.docs.isEmpty) {
                        // Get the liker's username properly from likeEntry or fetch from Firestore
                        String likerName =
                            likeEntry['username'] as String? ?? '';

                        if (likerName.isEmpty) {
                          // Fetch from humanUsers collection
                          try {
                            final likerDoc = await FirebaseFirestore.instance
                                .collection('humanUsers')
                                .doc(currentUid)
                                .get();

                            if (likerDoc.exists) {
                              final likerData = likerDoc.data()!;
                              likerName = likerData['username'] ??
                                  likerData['name'] ??
                                  likerData['displayName'] ??
                                  'Someone';
                            } else {
                              // Try querying by uid field
                              final likerQuery = await FirebaseFirestore
                                  .instance
                                  .collection('humanUsers')
                                  .where('uid', isEqualTo: currentUid)
                                  .limit(1)
                                  .get();

                              if (likerQuery.docs.isNotEmpty) {
                                final likerData = likerQuery.docs.first.data();
                                likerName = likerData['username'] ??
                                    likerData['name'] ??
                                    likerData['displayName'] ??
                                    'Someone';
                              } else {
                                likerName = 'Someone';
                              }
                            }
                          } catch (e) {
                            debugPrint('Error fetching liker username: $e');
                            likerName = 'Someone';
                          }
                        }

                        final added = await notifRef.add({
                          'userId': resolvedAuthorUid,
                          'type': 'post_like',
                          'title': '$likerName liked your post',
                          'body': '$likerName liked your post',
                          'isRead': false,
                          'createdAt': FieldValue.serverTimestamp(),
                          'data': {
                            'postId': widget.post.id,
                            'engagementType': 'like',
                            'engagerUserId': currentUid,
                            'content': ''
                          },
                          // 'deeplink': 'inzone://post/${widget.post.id}', // deeplink disabled
                        });

                        debugPrint(
                            'Fallback like notification written to notifications doc: ${added.id} for user $resolvedAuthorUid (username: $resolvedAuthorUsername)');
                      }
                    }
                  } catch (e) {
                    debugPrint(
                        'Failed to write fallback notification to Firestore: $e');
                  }
                }
              } catch (e) {
                debugPrint(
                    'Error handling post-like notification fallback: $e');
              }
            }
          }
        } else {
          // Unlike: read-modify-write remove by id
          final snap = await docRef.get();
          if (snap.exists) {
            final data = snap.data() as Map<String, dynamic>;
            final List<dynamic> likedBy =
                List<dynamic>.from(data['likedBy'] ?? []);
            final updated = likedBy.where((entry) {
              try {
                if (entry is Map) {
                  return entry['id'] != currentUid;
                }
              } catch (e) {}
              return true;
            }).toList();
            await docRef.update({'likedBy': updated});
          }

          // Analytics for unlike
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
              isLiked: false,
              category: category.isNotEmpty ? category : null,
              authorId: widget.post.userReference.isNotEmpty
                  ? widget.post.userReference
                  : null,
            );
          }
        }
      } catch (e) {
        debugPrint('Error performing backend like/unlike: $e');

        // Rollback optimistic UI and local prefs on failure
        if (mounted) {
          setState(() {
            isLiked = !newLikeState;
          });
        }

        try {
          if (newLikeState) {
            await LikedPostsPreferences.removeLikedPost(widget.post.id);
          } else {
            await LikedPostsPreferences.addLikedPost(widget.post);
          }
        } catch (e2) {
          debugPrint(
              'Error rolling back local prefs after backend failure: $e2');
        }
      }
    });
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final bool isCharacterPost = widget.post.characterInfo != null;
    final String mainName = isCharacterPost
        ? widget.post.characterInfo!['name']!
        : widget.post.userName;
    final String? imageUrl = isCharacterPost
        ? widget.post.characterInfo!['image']!
        : (profileImageUrl.isNotEmpty
            ? profileImageUrl
            : widget.profileImageUrl);

    if (widget.isAd) {
      if (_nativeAdIsLoaded) {
        // If this is an ad and it's loaded, show the ad view with similar styling to regular posts
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
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
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
      } else {
        // Show a placeholder while the ad is loading.
        const SizedBox(
          height: 350, // Increased height for better visibility
          width: double.infinity,
          child: Center(child: Text('Ad is loading...')),
        );
      }
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
            minHeight: imageSuccess ? 350 : 130,
          ),
          width: MediaQuery.of(context).size.width - 8,
          // padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (widget.inProfile == true) {
                                return;
                              } else {
                                if (widget.post.isAi || isCharacterPost) {
                                  print(widget.post.userName);
                                  context.push(Routes.aiProfilePath(
                                      widget.post.userName));
                                } else {
                                  context.push(Routes.regularProfilePath(
                                      widget.post.userReference));
                                }
                              }
                            },
                            child: SizedBox(
                              width: 230,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mainName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // const Spacer(),
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
              ),
              _currentTextContent.isEmpty
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TranslatableText(
                          text: _currentTextContent,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                              height: 1,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color),
                        ),
                      ),
                    ),
              const SizedBox(height: 10),
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
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                      left: 10,
                      right: 10,
                    ),
                    child: Row(
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
                            behavior: HitTestBehavior.opaque,
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
                        const Spacer(),
                        if (!widget.post.isAi &&
                            widget.showHue &&
                            !isCharacterPost)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),

                        if (isCharacterPost)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2196F3).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "made by ${widget.post.userName}",
                                  style: TextStyle(
                                    color: const Color(0xFF2196F3)
                                        .withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

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
                      ],
                    ),
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

            // OWNER EDIT/DELETE OPTIONS
            if (isOwner) ...[
              ListTile(
                leading: Icon(
                  FeatherIcons.edit,
                  color: Theme.of(context).iconTheme.color,
                  size: 28,
                ),
                title: Text(
                  'Edit Post',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  print('Edit tapped for post: ${widget.post.id}');

                  // Navigate to the full edit post screen
                  _navigateToEditPost();
                  // Inline edit popup disabled to avoid duplicate Edit Post prompt.
                  // _showEditDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  FeatherIcons.trash2,
                  color: Colors.red,
                  size: 28,
                ),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  print('Delete tapped for post: ${widget.post.id}');

                  // Show confirmation dialog for delete
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete Post'),
                        content: const Text(
                            'Are you sure you want to delete this post? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
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
              const Divider(),
            ],

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
            // Only show tipping option if the user is an influencer
            if (_isInfluencer)
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
            postId: widget.post.id != "unknown" && widget.post.id.isNotEmpty
                ? widget.post.id
                : null,
            category: widget.post.category.isNotEmpty
                ? widget.post.category
                : (widget.post.mainCategory.isNotEmpty
                    ? widget.post.mainCategory
                    : null),
            authorId: widget.post.userReference.isNotEmpty
                ? widget.post.userReference
                : null,
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
      child: ListTile(
        leading: Icon(
          icon,
          size: 28,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
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
                'username': _actualUsername,
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
  final FocusNode _textFieldFocusNode =
      FocusNode(); // Add focus node for auto-focus
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String type = '';

  // Reply state that persists through rebuilds
  String? selectedCommentId;
  String? selectedCommentAuthor;
  bool showReplyComposer = false;
  bool _isSubmittingCommentAction = false;

  // More persistent reply state
  final Map<String, dynamic> _replyState = {
    'commentId': null,
    'author': null,
    'isReplying': false,
  };

  // Track which comments have their replies expanded
  final Set<String> _expandedReplies = <String>{};

  // Use ValueNotifiers for reactive state
  final ValueNotifier<bool> _replyComposerNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _selectedCommentNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<Set<String>> _expandedRepliesNotifier =
      ValueNotifier<Set<String>>({});

  Widget chatInput(String? commentId, String? name) {
    // Use ValueListenableBuilder to ensure reactive updates
    return ValueListenableBuilder<String?>(
      valueListenable: _selectedCommentNotifier,
      builder: (context, selectedComment, child) {
        final isInReplyMode = type == 'Reply' && selectedCommentAuthor != null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply indicator chip
            if (isInReplyMode)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.reply,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Replying to @$selectedCommentAuthor',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        print('Cancel button tapped');
                        _cancelReply();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Input field
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15.0, vertical: 30),
              child: Row(
                children: [
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 100),
                        child: TextFormField(
                          scrollController: _scrollController,
                          focusNode: _textFieldFocusNode,
                          cursorColor: Theme.of(context).colorScheme.primary,
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          controller: type == 'Reply'
                              ? _replyController
                              : mySearchController,
                          onTap: () {
                            print('TextFormField tapped - current type: $type');
                            // Always ensure focus when tapped
                            if (!_textFieldFocusNode.hasFocus) {
                              _textFieldFocusNode.requestFocus();
                              print('Focus requested on tap');
                            }
                          },
                          onChanged: (value) {
                            // Optional: handle text changes if needed
                          },
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          // cursorHeight: 17,
                          decoration: InputDecoration(
                            suffixIconColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                            contentPadding: const EdgeInsets.only(
                                top: 10, left: 16, right: 16),
                            border: InputBorder.none,
                            hintText:
                                type == 'Reply' ? 'Add Reply' : 'Add Comment',
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
                  const SizedBox(width: 10),
                  MaterialButton(
                    minWidth: 43,
                    height: 43,
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    onPressed: () async {
                      if (_isSubmittingCommentAction) return;

                      print('Send button pressed - type: $type');

                      // If the text field currently has focus and the user is
                      // in the middle of an IME composition, the first tap
                      // may only commit the composition instead of firing
                      // the send logic. Unfocus first to ensure composition
                      // is committed, then proceed to add the comment/reply.
                      if (_textFieldFocusNode.hasFocus) {
                        _textFieldFocusNode.unfocus();
                        // Small delay to allow the framework/IME to commit
                        // the composing text into the controller.
                        await Future.delayed(const Duration(milliseconds: 50));
                      }

                      setState(() {
                        _isSubmittingCommentAction = true;
                      });

                      try {
                        if (type == 'Reply') {
                          await _addReply();
                        } else {
                          await _addComment();
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSubmittingCommentAction = false;
                          });
                        }
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
          ],
        );
      },
    );
  }

  // Add comment to Firestore
  Future<void> _addComment() async {
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
        authorId: widget.post.userReference.isNotEmpty
            ? widget.post.userReference
            : null,
      );

      // Track comment for Gorse recommendation engine
      InZoneDatabase.trackPostComment(userId, widget.post.id);
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
    final commentId = DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + (999 * (DateTime.now().microsecond / 1000000)).round())
            .toString();

    Map<String, dynamic> newComment = {
      'id': commentId,
      'author': FirebaseAuth.instance.currentUser!.displayName,
      'text': commentText,
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'likedBy': [], // Initialize likedBy as an empty list
      'dislikedBy': [],
      'replyCount': 0,
      'parentCommentId': null,
      'isReply': false,
    };

    // Add the new comment to the existing comments list
    currentComments.add(newComment);

    // Update the document with the new comments list
    await postDocumentReference.update({'comments': currentComments});

    // Trigger notification for post engagement (comment)
    await NotificationEventService.onPostEngagement(
      // await NotificationService.sendPostEngagementNotification(
      postId: widget.post.id,
      type: 'comment',
      userId: FirebaseAuth.instance.currentUser!.uid,
      content: commentText,
      postAuthorId: widget.post.userReference.isNotEmpty
          ? widget.post.userReference
          : null,
    );

    setState(() {
      mySearchController.clear();
    });
  }

  // Toggle replies visibility for a comment
  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplies.contains(commentId)) {
        _expandedReplies.remove(commentId);
      } else {
        _expandedReplies.add(commentId);
      }
    });

    // Update the notifier to trigger reactive rebuilds
    _expandedRepliesNotifier.value = Set.from(_expandedReplies);

    print(
        'Toggled replies for $commentId, expanded: ${_expandedReplies.contains(commentId)}');
  }

  // Start reply to a comment - robust and consistent reply switching
  void _startReply(String commentId, String commentAuthor) {
    print('=== START REPLY ===');
    print('commentId: $commentId, commentAuthor: $commentAuthor');
    print('Current selectedCommentId: $selectedCommentId');

    // Clear any existing reply text when switching targets
    if (selectedCommentId != null && selectedCommentId != commentId) {
      _replyController.clear();
      print('Cleared reply text due to target switch');
    }

    // Update all state variables consistently
    setState(() {
      selectedCommentId = commentId;
      selectedCommentAuthor = commentAuthor;
      showReplyComposer = true;
      type = 'Reply';
    });

    // Update reactive notifiers
    _selectedCommentNotifier.value = commentId;
    _replyComposerNotifier.value = true;

    // Update persistent state
    _replyState['commentId'] = commentId;
    _replyState['author'] = commentAuthor;
    _replyState['isReplying'] = true;

    // Force focus on the text field - more aggressive approach
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // First try immediate focus
        _textFieldFocusNode.requestFocus();

        // Then try with delay as backup
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && !_textFieldFocusNode.hasFocus) {
            _textFieldFocusNode.requestFocus();
          }
        });

        // Final attempt with longer delay
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_textFieldFocusNode.hasFocus) {
            _textFieldFocusNode.requestFocus();
          }
        });
      }
    });

    print(
        'Reply target switched successfully - selectedCommentId: $selectedCommentId, type: $type');
  }

  // Cancel reply - comprehensive cleanup
  void _cancelReply() {
    print('=== CANCEL REPLY ===');

    // Force unfocus immediately
    if (_textFieldFocusNode.hasFocus) {
      _textFieldFocusNode.unfocus();
    }

    // Clear the reply text
    _replyController.clear();

    // Reset all state variables consistently
    setState(() {
      selectedCommentId = null;
      selectedCommentAuthor = null;
      showReplyComposer = false;
      type = '';
    });

    // Update reactive notifiers
    _replyComposerNotifier.value = false;
    _selectedCommentNotifier.value = null;

    // Clear persistent state
    _replyState['commentId'] = null;
    _replyState['author'] = null;
    _replyState['isReplying'] = false;

    print('Reply cancelled - all state cleared');
  }

  // Scroll to a specific comment by ID with retry logic
  void _scrollToCommentWithRetry(String commentId, int attemptsLeft) {
    print('=== _scrollToCommentWithRetry called ===');
    print('Target commentId: $commentId, attempts left: $attemptsLeft');

    if (attemptsLeft <= 0 || !mounted) {
      print('Max attempts reached or widget unmounted');
      return;
    }

    // Set highlighting for the target comment
    setState(() {
      _highlightedCommentId = commentId;
    });

    // First, try to find the comment using its GlobalKey
    final commentKey = _getCommentKey(commentId);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _scrollToCommentByKey(commentKey, commentId, attemptsLeft);
      }
    });

    // Clear highlighting after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedCommentId = null;
        });
      }
    });
  }

  // Try to scroll to comment using its GlobalKey
  void _scrollToCommentByKey(
      GlobalKey commentKey, String commentId, int attemptsLeft) {
    print('=== _scrollToCommentByKey called ===');
    print('Looking for comment: $commentId');

    if (!mounted || !_scrollController.hasClients) {
      print('Controller not available');
      return;
    }

    // Try to get the RenderBox for the comment
    final RenderBox? renderBox =
        commentKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null) {
      // Found the comment! Calculate its position
      final position = renderBox.localToGlobal(Offset.zero);
      final commentPosition = position.dy;

      // Get the current scroll position and calculate target
      final currentScroll = _scrollController.offset;
      final screenHeight = MediaQuery.of(context).size.height;

      // Calculate target scroll position to center the comment
      final targetScroll = currentScroll + commentPosition - (screenHeight / 3);

      print('Found comment at position: $commentPosition');
      print('Scrolling to: $targetScroll');

      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    } else {
      print('Comment not found in UI, using fallback method');
      // Fallback to the previous method if we can't find the specific comment
      _fallbackScrollMethod(commentId, attemptsLeft);
    }
  }

  // Fallback method when we can't find the comment by key
  void _fallbackScrollMethod(String commentId, int attemptsLeft) {
    print('=== Using fallback scroll method ===');

    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    // Scroll to comments section first
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double targetPosition = maxScroll * 0.85;

    _scrollController
        .animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    )
        .then((_) {
      // Try again after a delay if we have attempts left
      if (attemptsLeft > 1 && mounted) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _scrollToCommentWithRetry(commentId, attemptsLeft - 1);
          }
        });
      }
    });
  }

  // Add reply to a comment
  Future<void> _addReply() async {
    print('=== _addReply called ===');
    print('selectedCommentId: $selectedCommentId');
    print('selectedCommentAuthor: $selectedCommentAuthor');
    print('_replyState: $_replyState');

    String replyText = _replyController.text.trim();
    print('replyText: "$replyText"');

    // Try to get comment ID from either source
    String? commentIdToUse = selectedCommentId ?? _replyState['commentId'];

    if (commentIdToUse == null || commentIdToUse.isEmpty) {
      print('ERROR: No valid commentId found');
      return;
    }

    if (replyText.isEmpty) {
      print('ERROR: Reply text is empty');
      return;
    }

    print('Proceeding with commentId: $commentIdToUse');

    try {
      // Reference to the document where comments are stored
      DocumentReference postDocumentReference =
          _firestore.collection('postComments').doc(widget.post.id.toString());

      // Get the document snapshot
      DocumentSnapshot postSnapshot = await postDocumentReference.get();

      if (!postSnapshot.exists) return;

      List<dynamic> currentComments = postSnapshot['comments'] ?? [];

      // Create new reply with proper ID
      final replyId = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic> newReply = {
        'id': replyId,
        'author': FirebaseAuth.instance.currentUser!.displayName ?? 'Anonymous',
        'text': replyText,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'postId': widget.post.id.toString(),
        'parentCommentId': commentIdToUse, // Use the validated comment ID
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'likedBy': [],
        'dislikedBy': [],
        'replyCount': 0,
        'isReply': true,
      };

      // Add the reply to comments list
      currentComments.add(newReply);

      // Update the document
      await postDocumentReference.update({'comments': currentComments});

      // Trigger notification for comment reply
      try {
        final response = await http.post(
          Uri.parse(
              'https://inzoneapi-912424781531.us-central1.run.app/api/notifications/events/comment-reply'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'postId': widget.post.id.toString(),
            'replierId': FirebaseAuth.instance.currentUser!.uid,
            'parentCommentId': commentIdToUse, // Use the validated comment ID
            'replyContent': replyText,
            'replyId': replyId,
          }),
        );

        if (response.statusCode == 200) {
          print('✅ Comment reply notification sent successfully');
        } else {
          print(
              '❌ Failed to send comment reply notification: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error sending comment reply notification: $e');
        // Continue even if notification fails
      }

      // Clear and hide reply composer
      _cancelReply();

      print('Reply added successfully');
    } catch (e) {
      print('Error adding reply: $e');
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

  Future<CommentClass> getComment(String commentId) async {
    DocumentSnapshot snapshot =
        await _firestore.collection('comments').doc(commentId).get();
    return CommentClass.fromJson(snapshot.data() as Map<String, dynamic>);
  }

  Map<String, bool> likedComments = {};
  Map<String, bool> dislikedComments = {};
  bool showReplies = false; // Flag to track whether to show replies or not

  filterSheetModel() {
    debugPrint('filterSheetModel called - resetting all reply state');

    // Clear all reply state when opening comment section
    _cancelReply();

    // Also clear the comment text field
    mySearchController.clear();

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
                            final allComments =
                                commentsList.map<CommentClass>((comment) {
                              final commentIndex =
                                  commentsList.indexOf(comment);
                              return CommentClass(
                                author:
                                    comment['author'] ?? comment['name'] ?? '',
                                text: comment['text'] ?? '',
                                replies: [], // Will be populated from separate reply processing
                                timestamp: comment['timestamp'] ?? "",
                                id: comment['id'] ??
                                    comment['timestamp'] ??
                                    commentIndex.toString(),
                                postId: widget.post.id.toString(),
                                userId: comment['userId'] ?? '',
                                parentCommentId: comment['parentCommentId'],
                                replyCount: comment['replyCount'] ?? 0,
                                isReply: comment['isReply'] ??
                                    (comment['parentCommentId'] != null),
                                likedBy: comment['likedBy'] != null
                                    ? List<String>.from(comment['likedBy'])
                                    : [],
                                dislikedBy: comment['dislikedBy'] != null
                                    ? List<String>.from(comment['dislikedBy'])
                                    : [],
                                profilePictureUrl: '',
                              );
                            }).toList();

                            // Separate parent comments and replies
                            final parentComments = allComments
                                .where((CommentClass c) => !c.isReply)
                                .toList();
                            final repliesMap = <String, List<CommentClass>>{};

                            // Group replies by parent comment ID
                            for (final reply in allComments
                                .where((CommentClass c) => c.isReply)) {
                              final parentId = reply.parentCommentId;
                              if (parentId != null) {
                                if (!repliesMap.containsKey(parentId)) {
                                  repliesMap[parentId] = [];
                                }
                                repliesMap[parentId]!.add(reply);
                              }
                            }

                            // Sort parent comments by timestamp (newest first)
                            parentComments.sort((a, b) {
                              try {
                                final aTime = int.parse(a.timestamp);
                                final bTime = int.parse(b.timestamp);
                                return bTime.compareTo(aTime);
                              } catch (e) {
                                return 0;
                              }
                            });

                            if (parentComments.isEmpty) {
                              return Center(
                                child: Text(
                                  'No Comments Available',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                              );
                            }

                            // Wrap ListView in ValueListenableBuilder to make it reactive to expanded replies
                            return ValueListenableBuilder<Set<String>>(
                              valueListenable: _expandedRepliesNotifier,
                              builder: (context, expandedSet, child) {
                                // Rebuild comments list based on current expanded state
                                final List<CommentClass> reactiveComments = [];
                                final Map<String, String> parentCommentAuthors =
                                    {}; // Map comment ID to author

                                // First pass: collect parent comment authors
                                for (final parent in parentComments) {
                                  parentCommentAuthors[parent.id] =
                                      parent.author;
                                }

                                for (final parent in parentComments) {
                                  reactiveComments.add(parent);

                                  // Only add replies if this parent comment is expanded
                                  if (expandedSet.contains(parent.id)) {
                                    final replies = repliesMap[parent.id] ?? [];
                                    replies.sort((a, b) {
                                      try {
                                        final aTime = int.parse(a.timestamp);
                                        final bTime = int.parse(b.timestamp);
                                        return aTime.compareTo(
                                            bTime); // Oldest first for replies (chronological)
                                      } catch (e) {
                                        return 0;
                                      }
                                    });
                                    reactiveComments.addAll(replies);
                                  }
                                }

                                return ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 5, 20, 100),
                                  itemCount: reactiveComments.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final comment = reactiveComments[index];
                                    final replyCount =
                                        repliesMap[comment.id]?.length ??
                                            0; // Calculate reply count outside
                                    return AnimatedContainer(
                                      duration: const Duration(seconds: 1),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 0.0,
                                            vertical: comment.isReply
                                                ? 0.0 // No padding for replies
                                                : (replyCount > 0 &&
                                                        expandedSet.contains(
                                                            comment.id))
                                                    ? 2.0 // Reduced padding for parent comments with expanded replies
                                                    : 10.0), // Normal padding for parent comments without replies
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
                                              final userData =
                                                  snapshot.data!.data()
                                                      as Map<String, dynamic>;
                                              username = userData['username'] ??
                                                  userData['name'] ??
                                                  comment.author;
                                              profilePicUrl = userData[
                                                      'profilePicture'] ??
                                                  userData['profileImage'] ??
                                                  '';
                                            }

                                            // Get actual reply count from repliesMap
                                            final actualReplyCount =
                                                repliesMap[comment.id]
                                                        ?.length ??
                                                    0;

                                            return ValueListenableBuilder<
                                                Set<String>>(
                                              valueListenable:
                                                  _expandedRepliesNotifier,
                                              builder: (context, expandedSet,
                                                  child) {
                                                final isCurrentlyExpanded =
                                                    expandedSet
                                                        .contains(comment.id);
                                                return Container(
                                                  child: CommentsTile(
                                                    key: ValueKey(
                                                        'comment-${comment.id}-$isCurrentlyExpanded-$actualReplyCount'),
                                                    commentText: comment.text,
                                                    profilePictureUrl:
                                                        profilePicUrl,
                                                    author: username,
                                                    timestamp:
                                                        comment.timestamp,
                                                    commentId:
                                                        comment.id.isNotEmpty
                                                            ? comment.id
                                                            : index.toString(),
                                                    parentCommentId:
                                                        comment.parentCommentId,
                                                    parentCommentAuthor: comment
                                                                .isReply &&
                                                            comment.parentCommentId !=
                                                                null
                                                        ? parentCommentAuthors[
                                                            comment
                                                                .parentCommentId]
                                                        : null,
                                                    postCreatorId: widget
                                                            .post.isAi
                                                        ? widget.post
                                                            .userName // For AI posts, use userName
                                                        : widget.post
                                                            .userReference, // For human posts, use userReference
                                                    commentAuthorId: comment
                                                        .userId, // Pass the comment author's user ID
                                                    replyCount:
                                                        actualReplyCount,
                                                    isReply: comment.isReply,
                                                    showReplies:
                                                        isCurrentlyExpanded,
                                                    likedBy:
                                                        comment.likedBy ?? [],
                                                    dislikedBy:
                                                        comment.dislikedBy ??
                                                            [],
                                                    currentUserId: FirebaseAuth
                                                            .instance
                                                            .currentUser
                                                            ?.uid ??
                                                        '',
                                                    onLike: () {
                                                      // Implement database update for likes
                                                      _updateCommentLikes(
                                                          comment,
                                                          index,
                                                          reactiveComments);
                                                    },
                                                    onDislike: () {
                                                      // Implement database update for dislikes
                                                      _updateCommentDislikes(
                                                          comment,
                                                          index,
                                                          reactiveComments);
                                                    },
                                                    onReply: () {
                                                      print(
                                                          'Reply button tapped for comment: ${comment.id}, author: $username');
                                                      _startReply(
                                                          comment.id.isNotEmpty
                                                              ? comment.id
                                                              : index
                                                                  .toString(),
                                                          username);
                                                    },
                                                    onToggleReplies:
                                                        actualReplyCount > 0
                                                            ? () {
                                                                _toggleReplies(
                                                                    comment.id);
                                                              }
                                                            : null,
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
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

                    // Debug state indicator - Reactive with ValueListenableBuilder
                    /*ValueListenableBuilder<bool>(
                      valueListenable: _replyComposerNotifier,
                      builder: (context, isReplying, child) {
                        return Container(
                          padding: const EdgeInsets.all(4),
                          color: isReplying ? Colors.green : Colors.red,
                          child: Text(
                            'showReplyComposer: $isReplying | selectedCommentId: $selectedCommentId',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        );
                      },
                    ),*/

                    // Reply Input - Reactive with ValueListenableBuilder
                    // ValueListenableBuilder<bool>(
                    //   valueListenable: _replyComposerNotifier,
                    //   builder: (context, isReplying, child) {
                    //     return isReplying
                    //         ? Container(
                    //             padding: const EdgeInsets.all(12),
                    //             color: Colors.grey[50],
                    //             child: Column(
                    //               crossAxisAlignment: CrossAxisAlignment.start,
                    //               children: [
                    //                 Text('Replying to ${selectedCommentAuthor ?? "comment"}',
                    //                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    //                 const SizedBox(height: 8),
                    //                 Row(
                    //                   children: [
                    //                     Expanded(
                    //                       child: TextField(
                    //                         controller: _replyController,
                    //                         autofocus: true,
                    //                         decoration: const InputDecoration(
                    //                           hintText: 'Write reply...',
                    //                           border: OutlineInputBorder(),
                    //                           contentPadding: EdgeInsets.all(8),
                    //                           isDense: true,
                    //                         ),
                    //                       ),
                    //                     ),
                    //                     const SizedBox(width: 8),
                    //                     ElevatedButton(
                    //                       onPressed: _addReply,
                    //                       child: const Text('Send'),
                    //                     ),
                    //                     const SizedBox(width: 4),
                    //                     TextButton(
                    //                       onPressed: _cancelReply,
                    //                       child: const Text('Cancel'),
                    //                     ),
                    //                   ],
                    //                 ),
                    //               ],
                    //             ),
                    //           )
                    //         : const SizedBox.shrink();
                    //   },
                    // ),

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
  bool _isCardVisible = false;

  static final Map<String, ImageProvider> _cachedImages = {};
  static final Map<String, double> _cachedImageHeights = {};
  static final List<String> _cacheQueue = [];
  static const int _maxImageCacheSize = 30;

  static final Map<String, double> _cachedVideoAspectRatios = {};
  static final List<String> _videoCacheQueue = [];
  static const int _maxVideoCacheSize = 20;

  static void _cleanupImageCache() {
    while (_cacheQueue.length > _maxImageCacheSize) {
      String oldestUrl = _cacheQueue.removeAt(0);
      _cachedImages.remove(oldestUrl);
      _cachedImageHeights.remove(oldestUrl);
    }
  }

  static void _cleanupVideoCache() {
    while (_videoCacheQueue.length > _maxVideoCacheSize) {
      String oldestUrl = _videoCacheQueue.removeAt(0);
      _cachedVideoAspectRatios.remove(oldestUrl);
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

    _cachedImageHeights[key] = newHeight;

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

    return VisibilityDetector(
      key: Key(
          'dynamic-page-view-${widget.videos.join('-')}-${widget.images.join('-')}'),
      onVisibilityChanged: (info) {
        if (mounted) {
          final isVisible = info.visibleFraction > 0;
          if (_isCardVisible != isVisible) {
            if (isVisible) {
              setState(() {
                _isCardVisible = true;
              });
            }
          }
        }
      },
      child: Center(
        child: Container(
          // Remove animation, use fixed height instead of AnimatedContainer
          height: _currentHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).hoverColor,
            // borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.none,
          child: PageView.builder(
            controller: widget.controller,
            itemCount: totalItems,
            itemBuilder: (context, index) {
              if (index < validImages.length) {
                final imageUrl = validImages[index];
                return LayoutBuilder(
                  builder: (context, constraints) {
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

                      _cacheQueue.remove(imageUrl);
                      _cacheQueue.add(imageUrl);
                    }

                    ImageProvider? cachedImage;
                    if (_cachedImages.containsKey(imageUrl)) {
                      cachedImage = _cachedImages[imageUrl];
                      _cacheQueue.remove(imageUrl);
                      _cacheQueue.add(imageUrl);
                    } else {
                      String optimizedUrl = imageUrl;
                      if (imageUrl.contains('?')) {
                        optimizedUrl = '$imageUrl&quality=70&width=800';
                      } else {
                        optimizedUrl = '$imageUrl?quality=70&width=800';
                      }

                      cachedImage = CachedNetworkImageProvider(
                        optimizedUrl,
                        cacheKey: imageUrl,
                        maxWidth: 800,
                      );

                      _cachedImages[imageUrl] = cachedImage;
                      _cacheQueue.add(imageUrl);
                      _cleanupImageCache();
                    }

                    return VisibilityDetector(
                      key: Key('image-$imageUrl'),
                      onVisibilityChanged: (info) {
                        if (info.visibleFraction < 0.1 &&
                            _cacheQueue.contains(imageUrl)) {
                          _cacheQueue.remove(imageUrl);
                          _cacheQueue.insert(0, imageUrl);
                        }
                      },
                      child: ClipRRect(
                        // borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    _FullScreenImageViewer(imageUrl: imageUrl),
                              ),
                            );
                          },
                          onDoubleTap: () {
                            final _PostCardState? postCardState = context
                                .findAncestorStateOfType<_PostCardState>();
                            if (postCardState != null) {
                              postCardState.handleLike();
                              HapticFeedback.mediumImpact();
                            }
                          },
                          child: Image(
                            image: cachedImage!,
                            fit: BoxFit.fill,
                            color: null,
                            colorBlendMode: BlendMode.srcOver,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                            isAntiAlias: true,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                if (!_cachedImageHeights
                                    .containsKey(imageUrl)) {
                                  cachedImage!
                                      .resolve(const ImageConfiguration())
                                      .addListener(
                                        ImageStreamListener((imageInfo, _) {
                                          double calculatedHeight =
                                              imageInfo.image.height *
                                                  (constraints.maxWidth /
                                                      imageInfo.image.width);
                                          _updateHeightOnce(imageUrl, index,
                                              calculatedHeight);
                                        }, onError: (error, stackTrace) {
                                          debugPrint(
                                              'Image load error: $error');
                                        }),
                                      );
                                }
                                return child;
                              } else if (_cachedImageHeights
                                  .containsKey(imageUrl)) {
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
                    double width = constraints.maxWidth;

                    double aspectRatio =
                        _cachedVideoAspectRatios[videoUrl] ?? 9 / 16;
                    double calculatedHeight = width / aspectRatio;

                    // Set the height for the current page in the PageView.
                    _heights[index] = calculatedHeight;
                    if (_currentIndex == index) {
                      // Use WidgetsBinding to avoid calling setState during a build.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _currentHeight != calculatedHeight) {
                          setState(() {
                            _currentHeight = calculatedHeight;
                          });
                        }
                      });
                    }

                    // If the card is not yet visible on screen, show a placeholder.
                    // The placeholder has the correct size to prevent layout shifts.
                    if (!_isCardVisible) {
                      return Container(
                        color: Colors.black,
                        height: calculatedHeight,
                        child: const Center(
                          child: Icon(Icons.play_arrow_rounded,
                              color: Colors.white38, size: 60),
                        ),
                      );
                    }

                    // Once visible, build the actual video widget.
                    return ClipRRect(
                      // borderRadius: BorderRadius.circular(12),
                      child: _VideoWidgetWrapper(
                        videoUrl: videoUrl,
                        maxWidth: width,
                        index: index,
                        postId: context
                                        .findAncestorWidgetOfExactType<
                                            PostCard>()
                                        ?.post
                                        .id !=
                                    "unknown" &&
                                context
                                        .findAncestorWidgetOfExactType<
                                            PostCard>()
                                        ?.post
                                        .id
                                        .isNotEmpty ==
                                    true
                            ? context
                                .findAncestorWidgetOfExactType<PostCard>()
                                ?.post
                                .id
                            : null,
                        category: context
                                    .findAncestorWidgetOfExactType<PostCard>()
                                    ?.post
                                    .category
                                    .isNotEmpty ==
                                true
                            ? context
                                .findAncestorWidgetOfExactType<PostCard>()
                                ?.post
                                .category
                            : (context
                                        .findAncestorWidgetOfExactType<
                                            PostCard>()
                                        ?.post
                                        .mainCategory
                                        .isNotEmpty ==
                                    true
                                ? context
                                    .findAncestorWidgetOfExactType<PostCard>()
                                    ?.post
                                    .mainCategory
                                : null),
                        authorId: context
                                    .findAncestorWidgetOfExactType<PostCard>()
                                    ?.post
                                    .userReference
                                    .isNotEmpty ==
                                true
                            ? context
                                .findAncestorWidgetOfExactType<PostCard>()
                                ?.post
                                .userReference
                            : null,
                        onAspectRatioUpdated: (newAspectRatio) {
                          // When the video's aspect ratio is determined, cache it for future use.
                          if (_cachedVideoAspectRatios[videoUrl] !=
                              newAspectRatio) {
                            _cachedVideoAspectRatios[videoUrl] = newAspectRatio;
                            _videoCacheQueue.remove(videoUrl);
                            _videoCacheQueue.add(videoUrl);
                            _cleanupVideoCache();
                          }

                          // Recalculate height with the correct aspect ratio and update the UI.
                          double newCalculatedHeight = width / newAspectRatio;
                          updateVideoHeight(index, newCalculatedHeight);
                        },
                        onDoubleTap: () {
                          // Find parent PostCard state and trigger like
                          final _PostCardState? postCardState =
                              context.findAncestorStateOfType<_PostCardState>();
                          if (postCardState != null) {
                            postCardState.handleLike();
                            HapticFeedback
                                .mediumImpact(); // Add haptic feedback
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
