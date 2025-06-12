import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/components/video/video_player_widget_post_screen.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/shared_preferences_helper_class.dart';
import 'package:action_slider/action_slider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:inzone/auth/auth_work.dart';
import 'package:go_router/go_router.dart';
import 'package:toasty_box/toast_service.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  List<String> characters = [
    'Splash',
    'Dora'
  ]; // List of characters, empty initially
  String? selectedCharacter;
  bool isImageSelected = false;
  bool doesNotWork = false;
  File? imageFile;
  bool submitted = false;
  bool isTyping = false;
  bool isEditingComplete = false;
  bool isPlaying = false;
  String postContent = "";
  double moveValue = 0.928;
  bool isUploading = false;
  bool isPosting = false;

  double high = 0.928;
  double medium = 0.8;
  double low = 0.4;
  late Timer _timer;
  List<String> imageUrls = [];
  List<String> videoUrls = [];
  List<String> thumbnailUrls = [];

  double maxWidth = 0.0;
  double maxMovable = 0.928;
  List<String> choices = [
    'News',
    'Entertainment',
    'Politics',
    'Automotive',
    'Sports',
  ];
  List<String> multipleSelected = [];
  final FocusNode _focusNode = FocusNode();

  late DateTime _startTime; // To store the start time
  int pageOpened = 0;
  void setMultipleSelected(List<String> value) {
    setState(() => multipleSelected = value);
  }

  _pickImagefromGallery() async {
    try {
      final pickedImage =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        setState(() {
          imageFile = File(pickedImage.path);
          isImageSelected = true;
        });
      } else {}
    } catch (e) {}
  }

  _pickImagefromCamera() async {
    try {
      final pickedImage =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedImage != null) {
        setState(() {
          imageFile = File(pickedImage.path);
          isImageSelected = true;
        });
      } else {}
    } catch (e) {}
  }

  Future<void> _loadPreferences() async {
    List<String>? list = await SharedPreferencesHelperClass.getStringList();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _loadPreferences();
    _startTime = DateTime.now();
    pageOpened += 1;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('post_screen',
        {"timeSpent": timeSpent.inSeconds, "pageOpenedCount": pageOpened});

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).dialogBackgroundColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 5.0, right: 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 5.0, right: 15.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        FeatherIcons.x,
                        color: Theme.of(context).iconTheme.color,
                        size: 35,
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
                      child: isPosting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : GestureDetector(
                              onTap: () async {
                                if (postContent.trim().isEmpty || isPosting) {
                                  print(
                                      "Post validation failed: Empty content or already posting");

                                  ToastService.showToast(
                                    context,
                                    backgroundColor:
                                        Theme.of(context).canvasColor,
                                    shadowColor: Colors.transparent,
                                    leading: const Icon(
                                      FeatherIcons.xCircle,
                                      color: Colors.redAccent,
                                    ),
                                    message: postContent.trim().isEmpty
                                        ? "Please enter some content before posting"
                                        : "Already processing your post",
                                  );

                                  return;
                                }

                                setState(() {
                                  isPosting = true;
                                });

                                // Add a timeout to ensure the UI doesn't get stuck
                                Timer postTimeout =
                                    Timer(const Duration(seconds: 15), () {
                                  if (mounted && isPosting) {
                                    setState(() {
                                      isPosting = false;
                                    });

                                    ToastService.showToast(
                                      context,
                                      backgroundColor:
                                          Theme.of(context).canvasColor,
                                      shadowColor: Colors.transparent,
                                      leading: const Icon(
                                        FeatherIcons.xCircle,
                                        color: Colors.redAccent,
                                      ),
                                      message:
                                          "Post timed out. Please try again.",
                                    );
                                  }
                                });

                                try {
                                  var analysis =
                                      await InZoneDatabase.analyzeSentiment(
                                          postContent);

                                  print("Sentiment analysis result: $analysis");

                                  int sentiment = analysis["sentiment"] as int;
                                  setState(() {
                                    if (sentiment == -1) {
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

                                  if (sentiment == -1) {
                                    setState(() {
                                      isPosting = false;
                                    });

                                    ToastService.showToast(
                                      context,
                                      backgroundColor:
                                          Theme.of(context).canvasColor,
                                      shadowColor: Colors.transparent,
                                      leading: const Icon(
                                        FeatherIcons.xCircle,
                                        color: Colors.redAccent,
                                      ),
                                      message:
                                          "Your post violates our guidelines. Please rephrase it.",
                                    );
                                    return;
                                  }

                                  print(
                                      "Starting to create post with content: $postContent");
                                  print(
                                      "Images: ${imageUrls.length}, Videos: ${videoUrls.length}");

                                  final result =
                                      await InZoneDatabase.createHumanPost(
                                    content: postContent,
                                    imageRefs: imageUrls,
                                    videoRefs: videoUrls,
                                  );

                                  print("Create post result: $result");

                                  if (result["success"] != true) {
                                    setState(() {
                                      isPosting = false;
                                    });

                                    String errorMessage =
                                        "Failed to create post. Please try again.";

                                    // Check for specific error messages from the backend
                                    if (result["error"] != null) {
                                      errorMessage = result["error"].toString();
                                    } else if (result["message"] != null) {
                                      errorMessage =
                                          result["message"].toString();
                                    }

                                    print(
                                        "Post failed with error: $errorMessage");

                                    ToastService.showToast(
                                      context,
                                      backgroundColor:
                                          Theme.of(context).canvasColor,
                                      shadowColor: Colors.transparent,
                                      leading: const Icon(
                                        FeatherIcons.xCircle,
                                        color: Colors.redAccent,
                                      ),
                                      message: errorMessage,
                                    );
                                    return;
                                  }

                                  context.pop();

                                  showDialog(
                                    context: context,
                                    builder: (_) {
                                      _timer =
                                          Timer(const Duration(seconds: 1), () {
                                        Navigator.of(_).pop();
                                      });
                                      return Dialog(
                                        backgroundColor: Colors.transparent,
                                        child: Stack(
                                          children: [
                                            RotatedBox(
                                              quarterTurns: 2,
                                              child: SizedBox(
                                                  height: MediaQuery.of(context)
                                                      .size
                                                      .height,
                                                  width: MediaQuery.of(context)
                                                      .size
                                                      .width,
                                                  child: Lottie.asset(
                                                      "assets/animations/confetti.json")),
                                            ),
                                            Align(
                                              alignment: Alignment.center,
                                              child: Text(
                                                "Post Successful",
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary,
                                                    fontSize: 25,
                                                    fontWeight:
                                                        FontWeight.w400),
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ).then((value) {
                                    if (_timer.isActive) {
                                      _timer.cancel();
                                    }
                                  });
                                } catch (e) {
                                  // Handle error
                                  print("Post error: $e");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Failed to post: ${e.toString().substring(0, math.min(e.toString().length, 100))}",
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onError),
                                        ),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } finally {
                                  postTimeout.cancel();
                                  if (mounted) {
                                    setState(() {
                                      isUploading = false;
                                      isPosting = false;
                                    });
                                  }
                                }
                              },
                              child: Text(
                                "Post",
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
              Padding(
                padding: const EdgeInsets.only(
                  left: 6.0,
                  right: 6.0,
                  top: 6.0,
                ),
                child: Center(
                  child: Text(
                    doesNotWork
                        ? "Please rephrase. Your message violates our guideline."
                        : "Your post works well with InZone guidelines",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: doesNotWork
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              SizedBox(
                width: MediaQuery.of(context).size.width,
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
                        // transform:  (Matrix4.identity() + Matrix4.rotationZ(math.pi / 4))
                      );
                    }),
                    AnimatedContainer(
                      height: 14,
                      width: 16,
                      margin: EdgeInsets.only(
                          left: maxWidth * maxMovable * moveValue),
                      decoration: BoxDecoration(
                          border:
                              Border.all(color: Theme.of(context).canvasColor),
                          borderRadius: BorderRadius.circular(30),
                          color: Theme.of(context).dialogBackgroundColor),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.fastEaseInToSlowEaseOut,
                      // transform:  (Matrix4.identity() + Matrix4.rotationZ(math.pi / 4))
                    ),
                  ],
                ),
              ),

              //  const Divider(),
              const SizedBox(height: 15),

              // Media Gallery Section
              SizedBox(
                height:
                    imageUrls.isNotEmpty || videoUrls.isNotEmpty || isUploading
                        ? 160
                        : 0,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Images
                      ...imageUrls.map((url) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20.0),
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
                                      try {
                                        // Delete from Firebase Storage
                                        await AuthWork.deletePostImage(url);
                                        setState(() {
                                          imageUrls.remove(url);
                                        });
                                      } catch (e) {}
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
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

                      // Videos
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
                                      CachedNetworkImage(
                                        height: 140,
                                        width: 140,
                                        fit: BoxFit.fill,
                                        imageUrl: thumbnailUrls[index],
                                        placeholder: (context, url) =>
                                            ImageLoading(context),
                                        errorWidget: (context, url, error) =>
                                            const SizedBox(),
                                      ),
                                      const Positioned.fill(
                                        child: Center(
                                          child: Icon(Icons.play_arrow,
                                              size: 50, color: Colors.white),
                                        ),
                                      ),
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: GestureDetector(
                                          onTap: () async {
                                            try {
                                              // Delete video and thumbnail from Firebase Storage
                                              await AuthWork.deletePostVideo(
                                                  videoUrls[index],
                                                  thumbnailUrls[index]);
                                              setState(() {
                                                videoUrls.removeAt(index);
                                                thumbnailUrls.removeAt(index);
                                              });
                                            } catch (e) {}
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Upload indicator
                      isUploading
                          ? Padding(
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
                            )
                          : const SizedBox(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  focusNode: _focusNode,
                  maxLines: 3, // Set maxLines to null for multiline
                  textInputAction: TextInputAction.send,

                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                      ),
                  decoration: InputDecoration(
                    hintText: 'What do you want to talk about ?',
                    hintStyle: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Theme.of(context).hintColor),
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    border: InputBorder.none, // Remove the border
                    filled: false,
                    contentPadding: const EdgeInsets.only(bottom: 8.0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      postContent = value;
                    });
                  },
                  onEditingComplete: () {
                    setState(() {
                      isTyping = false;
                    });
                  },
                  onSubmitted: (t) {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      submitted = true;
                    });
                  },
                  onTapOutside: (t) {
                    setState(() {
                      isTyping = true;
                    });
                  },
                  onTap: () {
                    setState(() {
                      isTyping = true;
                    });
                  },
                ),
              ),
              const SizedBox(
                height: 2,
              ),

              const SizedBox(
                height: 10,
              ),

              const SizedBox(
                height: 5,
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
        bottomSheet: Padding(
          padding: const EdgeInsets.only(
            bottom: 20,
            left: 10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      // Pick an image
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
                      // Pick a video
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
                      // Pick an image
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
            ],
          ),
        ),
      ),
    );
  }

  void _navigateBack() {
    context.pop();
  }
}
