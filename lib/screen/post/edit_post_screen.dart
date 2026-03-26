import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/components/video/video_player_widget_post_screen.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inzone/auth/auth_work.dart';
import 'package:go_router/go_router.dart';
import 'package:toasty_box/toast_service.dart';

class EditPostScreen extends StatefulWidget {
  final InZonePost post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController postController;
  late String postContent;
  late List<String> imageUrls;
  late List<String> videoUrls;
  List<String> thumbnailUrls = [];

  // Track original values for comparison
  late String _originalContent;
  late List<String> _originalImageUrls;
  late List<String> _originalVideoUrls;

  bool isUploading = false;
  bool isSaving = false;

  // Real-time sentiment analysis state
  bool isAnalyzingRealTime = false;
  String? currentBlockReason;
  bool doesNotWork = false;
  double moveValue = 0.928;

  double high = 0.928;
  double medium = 0.8;
  double low = 0.4;
  double maxWidth = 0.0;
  double maxMovable = 0.928;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _originalContent = widget.post.textContent;
    _originalImageUrls = List.from(widget.post.imageContent);
    _originalVideoUrls = List.from(widget.post.videoContent);

    postContent = widget.post.textContent;
    postController = TextEditingController(text: postContent);
    imageUrls = List.from(widget.post.imageContent);
    videoUrls = List.from(widget.post.videoContent);

    // Generate placeholder thumbnail URLs for existing videos
    // (Videos from the server don't have separate thumbnail URLs tracked here,
    // but we use the video URL as a reference)
    thumbnailUrls = List.generate(videoUrls.length, (_) => '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    // Run initial sentiment analysis
    if (postContent.trim().isNotEmpty) {
      _analyzeContentRealTime();
    }
  }

  @override
  void dispose() {
    postController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (postContent != _originalContent) return true;
    if (imageUrls.length != _originalImageUrls.length) return true;
    if (videoUrls.length != _originalVideoUrls.length) return true;
    for (int i = 0; i < imageUrls.length; i++) {
      if (imageUrls[i] != _originalImageUrls[i]) return true;
    }
    for (int i = 0; i < videoUrls.length; i++) {
      if (videoUrls[i] != _originalVideoUrls[i]) return true;
    }
    return false;
  }

  Future<String?> _resolveBackendPostId() async {
    final currentId = widget.post.id.trim();
    if (currentId.isNotEmpty && !currentId.startsWith('generated_')) {
      return currentId;
    }

    final resolved = await InZoneDatabase.resolveOwnedPostIdByText(
      textContent: widget.post.textContent,
    );

    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved.trim();
    }

    return null;
  }

  // Real-time sentiment analysis
  void _analyzeContentRealTime() {
    if (postContent.trim().isEmpty) {
      setState(() {
        moveValue = medium;
        doesNotWork = false;
        currentBlockReason = null;
        isAnalyzingRealTime = false;
      });
      return;
    }

    setState(() {
      isAnalyzingRealTime = true;
    });

    InZoneDatabase.analyzeSentimentRealTime(
      postContent,
      imageUrls: imageUrls,
      videoUrls: videoUrls,
      onResult: (result) {
        if (mounted) {
          setState(() {
            isAnalyzingRealTime = false;
            int sentiment = result["sentiment"] as int;
            bool isBlocked = result["blocked"] ?? false;
            bool isFallback = result["fallback"] ?? false;
            currentBlockReason = result["block_reason"];

            if ((sentiment == -2 || isBlocked) && !isFallback) {
              moveValue = low;
              doesNotWork = true;
            } else if (sentiment == -1 && !isFallback) {
              moveValue = low;
              doesNotWork = true;
            } else if (sentiment == 0 || isFallback) {
              moveValue = medium;
              doesNotWork = false;
            } else if (sentiment == 1) {
              moveValue = high;
              doesNotWork = false;
            }
          });
        }
      },
      debounceDelay: const Duration(milliseconds: 500),
    ).catchError((error) {
      if (mounted) {
        setState(() {
          isAnalyzingRealTime = false;
          moveValue = medium;
          doesNotWork = false;
          currentBlockReason = "Analysis service unavailable - editing allowed";
        });
      }
      return <String, dynamic>{};
    });
  }

  void _onTextChanged(String text) {
    setState(() {
      postContent = text;
    });
    _analyzeContentRealTime();
  }

  String _getContentStatusMessage() {
    if (postContent.trim().isEmpty) {
      return "Start typing to analyze your content...";
    }

    if (isAnalyzingRealTime) {
      return "Analyzing content...";
    }

    if (doesNotWork) {
      if (currentBlockReason != null && currentBlockReason!.isNotEmpty) {
        if (currentBlockReason!.contains("unavailable")) {
          return "Content moderation offline - editing allowed";
        }
        return "Content blocked: $currentBlockReason";
      }
      return "Content violates guidelines - please rephrase";
    }

    return "Your post meets InZone community standards";
  }

  Color _getContentStatusColor() {
    if (postContent.trim().isEmpty || isAnalyzingRealTime) {
      return Theme.of(context).hintColor;
    }

    if (doesNotWork) {
      return Theme.of(context).colorScheme.error;
    }

    return Theme.of(context).primaryColor;
  }

  Future<void> _saveChanges() async {
    if (postContent.trim().isEmpty || isSaving) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: postContent.trim().isEmpty
            ? "Please enter some content"
            : "Already saving your changes",
      );
      return;
    }

    if (!_hasChanges) {
      ToastService.showToast(
        context,
        backgroundColor: Colors.grey,
        message: 'No changes made',
        leading: const Icon(Icons.info, color: Colors.white),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    // Add a timeout to ensure the UI doesn't get stuck
    Timer saveTimeout = Timer(const Duration(seconds: 15), () {
      if (mounted && isSaving) {
        setState(() {
          isSaving = false;
        });
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: "Save timed out. Please try again.",
        );
      }
    });

    try {
      // Run sentiment analysis before saving
      var analysis = await InZoneDatabase.analyzeSentiment(
        postContent,
        imageUrls: imageUrls,
        videoUrls: videoUrls,
      );

      int sentiment = analysis["sentiment"] as int;
      bool isBlocked = analysis["blocked"] ?? false;

      if (sentiment == -2 || isBlocked) {
        setState(() {
          isSaving = false;
          moveValue = low;
          doesNotWork = true;
        });
        String blockReason =
            analysis["block_reason"] ?? "Content violates our guidelines";
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: "Post blocked: $blockReason",
        );
        return;
      }

      if (sentiment == -1) {
        setState(() {
          isSaving = false;
          moveValue = low;
          doesNotWork = true;
        });
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: "Your post violates our guidelines. Please rephrase it.",
        );
        return;
      }

      final resolvedPostId = await _resolveBackendPostId();
      if (resolvedPostId == null) {
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message: 'Could not identify this post for editing',
          leading: const Icon(Icons.error, color: Colors.white),
        );
        return;
      }

      // Call the backend to update the post
      bool updateSuccess = await InZoneDatabase.updatePost(
        postId: resolvedPostId,
        content: postContent,
        imageUrls: imageUrls,
        videoUrls: videoUrls,
      );

      if (updateSuccess) {
        // Create updated post object to pass back
        final updatedPost = InZonePost(
          category: widget.post.category,
          userName: widget.post.userName,
          comments: widget.post.comments,
          datePosted: widget.post.datePosted,
          likes: widget.post.likes,
          id: resolvedPostId,
          imageContent: imageUrls,
          videoContent: videoUrls,
          textContent: postContent,
          userReference: widget.post.userReference,
          mainCategory: widget.post.mainCategory,
          isAi: widget.post.isAi,
          characterInfo: widget.post.characterInfo,
        );

        if (mounted) {
          context.pop(updatedPost);
        }

        ToastService.showToast(
          context,
          backgroundColor: Colors.green,
          message: 'Post updated successfully!',
          leading: const Icon(Icons.check_circle, color: Colors.white),
        );
      } else {
        ToastService.showToast(
          context,
          backgroundColor: Colors.red,
          message: 'Failed to save changes to server',
          leading: const Icon(Icons.error, color: Colors.white),
        );
      }
    } catch (e) {
      print('Error updating post: $e');
      ToastService.showToast(
        context,
        backgroundColor: Colors.red,
        message: 'Error: Could not update post',
        leading: const Icon(Icons.error, color: Colors.white),
      );
    } finally {
      saveTimeout.cancel();
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          context.pop();
        }
      },
      child: ColorfulSafeArea(
        color: Theme.of(context).dialogBackgroundColor,
        child: Scaffold(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          body: Stack(
            children: [
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 8.0, left: 5.0, right: 5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.only(left: 5.0, right: 15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: GestureDetector(
                              onTap: () async {
                                if (_hasChanges) {
                                  final shouldDiscard = await _onWillPop();
                                  if (shouldDiscard && mounted) {
                                    context.pop();
                                  }
                                } else {
                                  context.pop();
                                }
                              },
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade800
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.2),
                                child: Center(
                                  child: Icon(
                                    FeatherIcons.x,
                                    size: 22,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade400
                                        : Colors.blue.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Edit Post',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: isSaving
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _saveChanges,
                                    child: Text(
                                      "Save",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            fontSize: 14,
                                          ),
                                    ),
                                  ),
                          )
                        ],
                      ),
                    ),

                    // Content status
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 6.0,
                        right: 6.0,
                        top: 6.0,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isAnalyzingRealTime)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Text(
                                _getContentStatusMessage(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _getContentStatusColor(),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sentiment bar
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 30,
                      child: Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [
                          LayoutBuilder(builder: (BuildContext context,
                              BoxConstraints constraints) {
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
                                border: Border.all(
                                    color: Theme.of(context).canvasColor),
                                borderRadius: BorderRadius.circular(30),
                                color: Theme.of(context).dialogBackgroundColor),
                            duration: Duration(
                                milliseconds: isAnalyzingRealTime ? 200 : 600),
                            curve: Curves.easeInOut,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Text Input Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade900.withOpacity(0.3)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                          child: TextField(
                            controller: postController,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 16,
                            textInputAction: TextInputAction.newline,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                            decoration: InputDecoration(
                              hintText: 'Edit your post content...',
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      color: Theme.of(context).hintColor),
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: _onTextChanged,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Media Gallery Section
                    SizedBox(
                      height: imageUrls.isNotEmpty ||
                              videoUrls.isNotEmpty ||
                              isUploading
                          ? 160
                          : 0,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Existing & newly added images
                            ...imageUrls.map((url) => Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                        child: Image(
                                          height: 140,
                                          width: 140,
                                          fit: BoxFit.cover,
                                          image: NetworkImage(url),
                                        ),
                                      ),
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: GestureDetector(
                                          onTap: () async {
                                            setState(() {
                                              imageUrls.remove(url);
                                            });
                                            _analyzeContentRealTime();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            // Existing & newly added videos
                            ...List.generate(
                              videoUrls.length,
                              (index) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20.0),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  VideoPlayerWidgetPostScreen(
                                                      videoUrls[index]),
                                            ),
                                          );
                                        },
                                        child: Stack(
                                          children: [
                                            // For existing videos, show a placeholder with play icon
                                            // For newly added videos with thumbnails, show thumbnail
                                            if (thumbnailUrls[index].isNotEmpty)
                                              CachedNetworkImage(
                                                height: 140,
                                                width: 140,
                                                fit: BoxFit.fill,
                                                imageUrl: thumbnailUrls[index],
                                                placeholder: (context, url) =>
                                                    ImageLoading(context),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        _videoPlaceholder(),
                                              )
                                            else
                                              _videoPlaceholder(),
                                            const Positioned.fill(
                                              child: Center(
                                                child: Icon(Icons.play_arrow,
                                                    size: 50,
                                                    color: Colors.white),
                                              ),
                                            ),
                                            Positioned(
                                              top: 5,
                                              right: 5,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    videoUrls.removeAt(index);
                                                    thumbnailUrls
                                                        .removeAt(index);
                                                  });
                                                  _analyzeContentRealTime();
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Upload indicator
                            if (isUploading)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  height: 140,
                                  width: 140,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: ImageLoading(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ],
          ),
          bottomSheet: Padding(
            padding: const EdgeInsets.only(
              bottom: 20,
              left: 10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 90);
                    if (image != null) {
                      setState(() {
                        isUploading = true;
                      });
                      await AuthWork.sendPostImage(
                              FirebaseAuth.instance.currentUser!.uid,
                              File(image.path))
                          .then((value) {
                        setState(() {
                          imageUrls.add(value);
                          isUploading = false;
                        });
                        _analyzeContentRealTime();
                      });
                    }
                  },
                  icon: Icon(
                    FeatherIcons.image,
                    color: Theme.of(context).iconTheme.color,
                    size: 25,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? video = await picker.pickVideo(
                        source: ImageSource.gallery,
                        maxDuration: const Duration(minutes: 5));
                    if (video != null) {
                      setState(() {
                        isUploading = true;
                      });
                      await AuthWork.sendPostVideo(
                              FirebaseAuth.instance.currentUser!.uid,
                              File(video.path))
                          .then((value) {
                        setState(() {
                          videoUrls.add(value["videoUrl"]!);
                          thumbnailUrls.add(value["thumbnailUrl"]!);
                          isUploading = false;
                        });
                        _analyzeContentRealTime();
                      });
                    }
                  },
                  icon: Icon(
                    FeatherIcons.video,
                    color: Theme.of(context).iconTheme.color,
                    size: 25,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                        source: ImageSource.camera, imageQuality: 90);
                    if (image != null) {
                      setState(() {
                        isUploading = true;
                      });
                      await AuthWork.sendPostImage(
                              FirebaseAuth.instance.currentUser!.uid,
                              File(image.path))
                          .then((value) {
                        setState(() {
                          imageUrls.add(value);
                          isUploading = false;
                        });
                        _analyzeContentRealTime();
                      });
                    }
                  },
                  icon: Icon(
                    FeatherIcons.camera,
                    color: Theme.of(context).iconTheme.color,
                    size: 25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      height: 140,
      width: 140,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          FeatherIcons.film,
          color: Colors.white54,
          size: 40,
        ),
      ),
    );
  }
}
