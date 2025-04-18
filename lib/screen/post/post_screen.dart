import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/components/video/video_player_widget_post_screen.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/shared_preferences_helper_class.dart';
import 'package:action_slider/action_slider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:inzone/auth/auth_work.dart';

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

  double high = 0.928;
  double medium = 0.8;
  double low = 0.4;
  late Timer _timer;
  String imageUrl = "";
  String videoUrl = "";
  String thumbnailUrl = "";

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
    // TODO: implement initState
    super.initState();
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
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30), topRight: Radius.circular(30))),
      child: Scaffold(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisSize: MainAxisSize.max,
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
              const SizedBox(
                height: 10,
              ),
              TextField(
                maxLines: 3, // Set maxLines to null for multiline
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  // labelText: 'What do you want you talk about?',
                  //
                  // labelStyle: TextStyle(color: Colors.grey.shade900),
                  hintText: 'What do you want to talk about ?',

                  hintStyle: TextStyle(color: Theme.of(context).hintColor),

                  border: InputBorder.none, // Remove the border
                  contentPadding: const EdgeInsets.only(
                      bottom: 8.0), // Adjust padding as needed
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
              const SizedBox(
                height: 2,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      // Pick an image
                      final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery, imageQuality: 90);
                      if (image != null) {
                        // setState(() {
                        //   _img = image.path;
                        // });
                        //upload image
                        setState(() {
                          isUploading = true;
                        });
                        await AuthWork.sendPostImage(
                                FirebaseAuth.instance.currentUser!.uid,
                                File(image.path))
                            .then((value) {
                          imageUrl = value;
                        });
                        // Navigator.pop(context);
                        setState(() {
                          isUploading = false;
                        });
                      }
                    },
                    icon: Icon(
                      Icons.image,
                      color: Theme.of(context).primaryColor,
                      size: 28,
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
                          videoUrl = value["videoUrl"]!;
                          thumbnailUrl = value["thumbnailUrl"]!;
                        });
                        setState(() {
                          isUploading = false;
                        });
                      }
                    },
                    icon: Icon(
                      Icons.switch_video_outlined,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      // Pick an image
                      final XFile? image = await picker.pickImage(
                          source: ImageSource.camera, imageQuality: 90);
                      if (image != null) {
                        // setState(() {
                        //   _img = image.path;
                        // });
                        //upload image
                        setState(() {
                          isUploading = true;
                        });
                        await AuthWork.sendPostImage(
                                FirebaseAuth.instance.currentUser!.uid,
                                File(image.path))
                            .then((value) {
                          imageUrl = value;
                        });
                        // Navigator.pop(context);
                        setState(() {
                          isUploading = false;
                        });
                      }
                    },
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  imageUrl == ""
                      ? const SizedBox(
                          height: 5,
                        )
                      : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20.0),
                                child: Image(
                                  height: 140,
                                  width: 140,
                                  fit: BoxFit.cover,
                                  image: NetworkImage(imageUrl),
                                ),
                              ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: GestureDetector(
                                  onTap: () async {
                                    try {
                                      // Delete from Firebase Storage
                                      await AuthWork.deletePostImage(imageUrl);
                                      setState(() {
                                        imageUrl = "";
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
                        ),
                  if (videoUrl.isNotEmpty || isUploading)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (videoUrl.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          VideoPlayerWidgetPostScreen(videoUrl),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    CachedNetworkImage(
                                      height: 140,
                                      width: 140,
                                      fit: BoxFit.fill,
                                      imageUrl: thumbnailUrl,
                                      placeholder: (context, url) =>
                                          const Center(
                                        child: CircularProgressIndicator(),
                                      ),
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
                                                videoUrl, thumbnailUrl);
                                            setState(() {
                                              videoUrl = "";
                                              thumbnailUrl = "";
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
                            if (isUploading)
                              Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Images

              const SizedBox(
                height: 5,
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
        bottomSheet: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: SizedBox(
            width: double.infinity,
            child: ActionSlider.standard(
              rolling: false,
              backgroundColor: Theme.of(context).primaryColor,
              toggleColor: Theme.of(context).dialogBackgroundColor,
              sliderBehavior: SliderBehavior.stretch,
              child: Text(
                'Post to InZone',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w400,
                    fontSize: 23),
              ),
              action: (controller) async {
                if (postContent.trim().isEmpty) {
                  controller.reset();
                  return;
                }

                controller.loading();

                try {
                  // First analyze sentiment
                  var analysis =
                      await InZoneDatabase.analyzeSentiment(postContent);
                  // Debug print

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

                  // If content is inappropriate, reset and return immediately
                  if (sentiment == -1) {
                    controller.reset();
                    return;
                  }

                  // Only proceed with post creation if sentiment is 0 or 1
                  if (sentiment >= 0) {
                    // Create a human post
                    final result = await InZoneDatabase.createHumanPost(
                      content: postContent,
                      imageRefs: [imageUrl],
                      videoRefs: [videoUrl],
                    );

                    // Debug print

                    if (!result["success"]) {
                      controller.reset();
                      return;
                    }

                    // Only show success dialog if the post was successful
                    controller.success();
                    Navigator.pop(context);

                    showDialog(
                        context: context,
                        builder: (_) {
                          _timer = Timer(const Duration(seconds: 1), () {
                            Navigator.of(_).pop();
                          });
                          return Dialog(
                            backgroundColor: Colors.transparent,
                            child: Stack(
                              children: [
                                RotatedBox(
                                  quarterTurns: 2,
                                  child: SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height,
                                      width: MediaQuery.of(context).size.width,
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
                                          fontWeight: FontWeight.w400),
                                    ))
                              ],
                            ),
                          );
                        }).then((value) {
                      if (_timer.isActive) {
                        _timer.cancel();
                      }
                    });
                  } else {
                    controller.reset();
                  }
                } catch (e) {
                  controller.reset();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
