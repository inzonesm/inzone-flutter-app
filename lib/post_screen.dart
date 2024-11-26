import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/components/video_player_widget_post_screen.dart';
import 'package:inzone/inzone_database.dart';
import 'package:inzone/shared_preferences_helper_class.dart';
import 'package:video_player/video_player.dart';
import 'package:action_slider/action_slider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'auth_work.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  List<String> characters = ['Splash', 'Dora']; // List of characters, empty initially
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
  List<String> _savedList = [];


  _pickImagefromGallery() async {
    try {
      final pickedImage =
      await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        setState(() {
          imageFile = File(pickedImage.path);
          isImageSelected = true;
        });
      } else {

      }
    } catch (e) {

    }
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
      } else {

      }
    } catch (e) {

    }
  }
  Future<void> _loadPreferences() async {
    List<String>? list = await SharedPreferencesHelperClass.getStringList();
    setState(() {
      _savedList = list ?? [];
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadPreferences();
    _startTime = DateTime.now();
    pageOpened+=1;

  }
  @override
  void dispose() {
    // TODO: implement dispose
    DateTime endTime = DateTime.now();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('post_screen', {"timeSpent" : timeSpent.inSeconds, "pageOpenedCount" : pageOpened});

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
        duration: const Duration(seconds: 1),
        padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration:  BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        child: Scaffold(
          backgroundColor:  Theme.of(context).canvasColor,

          body: Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6.0, right: 6.0, top: 6.0,),
                  child: Center(
                    child: Text(

                      doesNotWork ? "Please rephrase. Your message violates our guideline.":"Your post works well with InZone guidelines",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: doesNotWork ? Colors.red : Colors.blue,
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
                          (BuildContext context,
                          BoxConstraints constraints) {
                        maxWidth = constraints.maxWidth;
                        return Container(
                          height: 14,
                          width: double.infinity,
                          margin: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(30),
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
                            border: Border.all(
                                color:  Theme.of(context).canvasColor),
                            borderRadius:
                            BorderRadius.circular(30),
                            color: Colors.white),
                        duration: const Duration(seconds: 1),
                        // transform:  (Matrix4.identity() + Matrix4.rotationZ(math.pi / 4))
                      ),
                    ],
                  ),
                ),



                //  const Divider(),
                const SizedBox(height: 10,),
                TextField(
                  maxLines: 3, // Set maxLines to null for multiline
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    // labelText: 'What do you want you talk about?',
                    //
                    // labelStyle: TextStyle(color: Colors.grey.shade900),
                    hintText: 'What do you want to talk about ?',

                    hintStyle: TextStyle(color: Colors.grey.shade900),

                    border: InputBorder.none, // Remove the border
                    contentPadding: const EdgeInsets.only(
                        bottom: 8.0), // Adjust padding as needed
                  ),
                  onChanged: (value){
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
                const SizedBox(height: 2,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final ImagePicker _picker = ImagePicker();
                        // Pick an image
                        final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery, imageQuality: 90);
                        if (image != null) {
                          // setState(() {
                          //   _img = image.path;
                          // });
                          //upload image
                          setState(() {
                            isUploading = true;
                          });
                          await AuthWork.sendPostImage(FirebaseAuth.instance.currentUser!.uid , File(image.path)).then((value) {
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
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),

                    IconButton(
                      onPressed: () async {
                        final ImagePicker _picker = ImagePicker();
                        // Pick a video
                        final XFile? video = await _picker.pickVideo(
                            source: ImageSource.gallery, maxDuration: Duration(minutes: 5));
                        if (video != null) {
                          setState(() {
                            isUploading = true;
                          });
                          await AuthWork.sendPostVideo(FirebaseAuth.instance.currentUser!.uid , File(video.path)).then((value){
                            videoUrl = value["videoUrl"]!;
                            thumbnailUrl = value["thumbnailUrl"]!;
                          });
                          print("The video url is"  + videoUrl);
                          setState(() {
                            isUploading = false;
                          });
                        }
                      },
                      icon: Icon(
                        Icons.switch_video_outlined,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),


                    IconButton(
                      onPressed: () async {
                        final ImagePicker _picker = ImagePicker();
                        // Pick an image
                        final XFile? image = await _picker.pickImage(
                            source: ImageSource.camera, imageQuality: 90);
                        if (image != null) {
                          // setState(() {
                          //   _img = image.path;
                          // });
                          //upload image
                          setState(() {
                            isUploading = true;
                          });
                          await AuthWork.sendPostImage(FirebaseAuth.instance.currentUser!.uid , File(image.path)).then((value) {
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
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    imageUrl == ""
                        ? const SizedBox(
                      height: 5,
                    )
                        : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: Image(
                          height: 140,
                          width: 140,
                          fit: BoxFit.cover,
                          image: NetworkImage(imageUrl),
                        ),
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
                                    // Navigate to video player screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VideoPlayerWidgetPostScreen(videoUrl),
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
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) => const SizedBox(),
                                      ),
                                      const Positioned.fill(
                                        child: Center(
                                          child: Icon(Icons.play_arrow, size: 50, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isUploading)
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Images

                const SizedBox(height: 5,),
                const Spacer(flex: 3),


                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: double.infinity,

                    child: ActionSlider.standard(
                      rolling: false,
                      backgroundColor: Colors.blue,
                      toggleColor: Colors.white,
                      sliderBehavior: SliderBehavior.stretch,
                      child: const Text(
                        'Post to InZone',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                            fontSize: 23),
                      ),
                      action: (controller)  async {

                        controller.loading(); //starts loading animation
                        //     await Future.delayed(const Duration(seconds: 2));
                        await InZoneDatabase.postContent(postMessage: postContent, imageRef: [imageUrl], videoRef: [videoUrl]).then((value) {
                          setState(() {

                            if (value == -1){
                              moveValue = low;
                              doesNotWork = true;
                              controller.reset();
                            } else if (value == 0){
                              moveValue = medium;
                              doesNotWork = false;
                            } else if (value == 1){
                              moveValue = high;
                              doesNotWork = false;

                            } else {
                              moveValue = low;
                              doesNotWork = true;
                              controller.reset();
                            }
                          });
                        });

                        if (doesNotWork == false){
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
                                  child:  Stack(
                                    children: [
                                      RotatedBox(quarterTurns: 2, child: SizedBox(height:MediaQuery.of(context).size.height, width:MediaQuery.of(context).size.width, child: Lottie.asset("assets/animations/confetti.json")),),
                                      const Align(
                                          alignment: Alignment.center,
                                          child: Text("Post Sucessful", style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w400),))
                                    ],
                                  ),
                                );
                              }
                          ).then((value) {
                            if (_timer.isActive) {
                              _timer.cancel();
                            }
                          });

                          //starts success animation
                        }



                      },
                    ),
                  ),
                ),
                const Spacer(flex: 1,),
              ],
            ),
          ),
        ));
  }
}

//
//
//
// class PostScreen extends StatefulWidget {
//   const PostScreen({super.key});
//
//   @override
//   State<PostScreen> createState() => _PostScreenState();
// }
//
// class _PostScreenState extends State<PostScreen> {
//   bool isImageSelected = false;
//   File? imageFile;
//   _pickImagefromGallery() async {
//     try {
//       final pickedImage =
//           await ImagePicker().pickImage(source: ImageSource.gallery);
//       if (pickedImage != null) {
//         setState(() {
//           imageFile = File(pickedImage.path);
//           isImageSelected = true;
//         });
//       } else {
//
//       }
//     } catch (e) {
//
//     }
//   }
//
//   _pickImagefromCamera() async {
//     try {
//       final pickedImage =
//           await ImagePicker().pickImage(source: ImageSource.camera);
//       if (pickedImage != null) {
//         setState(() {
//           imageFile = File(pickedImage.path);
//           isImageSelected = true;
//         });
//       } else {
//
//       }
//     } catch (e) {
//
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,
//       // appBar: AppBar(
//       //   elevation: 0,
//       //   backgroundColor: backgroundColor,
//       //   leading: IconButton(
//       //       onPressed: () {},
//       //       icon: const Icon(
//       //         Icons.highlight_remove_outlined,
//       //         color: Colors.grey,
//       //       )),
//       // ),
//       body: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: SingleChildScrollView(
//           child: Column(
//             children: [
//               TextField(
//                 maxLines: null, // Set maxLines to null for multiline
//                 decoration: InputDecoration(
//                   labelText: 'What do you want you talk about?',
//                   labelStyle: TextStyle(color: Colors.grey.shade900),
//                   border: InputBorder.none, // Remove the border
//                   contentPadding:
//                       EdgeInsets.only(bottom: 8.0), // Adjust padding as needed
//                 ),
//                 onEditingComplete: () {
//                   setState(() {
//                     isTyping = false;
//                   });
//                 },
//                 onSubmitted: (t) {
//                   setState(() {
//                     isTyping = false;
//                   });
//                 },
//                 onTapOutside: (t) {
//                   setState(() {
//                     isTyping = false;
//                   });
//                 },
//                 onTap: () {
//                   setState(() {
//                     isTyping = true;
//                   });
//                 },
//               ),
//               SizedBox(
//                 height: 40,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//                   imageFile == null
//                       ? const SizedBox(
//                           height: 100,
//                         )
//                       : ClipRRect(
//                           borderRadius: BorderRadius.circular(20.0),
//                           child: Image(
//                             height: 150,
//                             width: 150,
//                             fit: BoxFit.cover,
//                             image: FileImage(imageFile!),
//                           ),
//                         ),
//                 ],
//               ),
//               isTyping
//                   ? Container()
//                   : SizedBox(
//                       height: MediaQuery.of(context).size.height / 2.8,
//                     ),
//               Container(
//                 margin: const EdgeInsets.only(top: 0),
//                 padding: const EdgeInsets.only(top: 0, left: 10, right: 10),
//                 width: MediaQuery.of(context).size.width,
//                 height: MediaQuery.of(context).size.height - 200,
//                 decoration: BoxDecoration(
//                   borderRadius: const BorderRadius.only(
//                     topLeft:
//                         Radius.circular(40.0), // Adjust the radius as needed
//                     topRight: Radius.circular(40.0),
//                   ),
//                   color: isTyping ? Colors.white : backgroundColor,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   children: [
//                     isTyping
//                         ? Container()
//                         : Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: [
//                               GestureDetector(
//                                   onTap: () {
//                                     _pickImagefromGallery();
//                                   },
//                                   child: Image.asset("icons/post_icons/0.png")),
//                               // Image.asset("icons/post_icons/1.png"),
//                               GestureDetector(
//                                   onTap: () {
//                                     _pickImagefromCamera();
//                                   },
//                                   child: Image.asset("icons/post_icons/2.png")),
//                             ],
//                           ),
//                     SizedBox(
//                       height: 10,
//                     ),
//                     !isTyping
//                         ? Container()
//                         : const Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Text("Suggestions based on your InZone post"),
//                             ],
//                           ),
//                     Row(
//                       children: [
//                         !isTyping
//                             ? Container()
//                             : Container(
//                                 width: 80,
//                                 padding: const EdgeInsets.all(5),
//                                 margin:
//                                     const EdgeInsets.only(top: 10, bottom: 30),
//                                 decoration: BoxDecoration(
//                                   borderRadius: BorderRadius.circular(5),
//                                   color: backgroundColor,
//                                   boxShadow: [
//                                     const BoxShadow(
//                                       color: Colors.blue,
//                                       spreadRadius: 1,
//                                       blurRadius: 1,
//                                       offset: Offset(0,
//                                           2), // Changes the position of the shadow
//                                     ),
//                                   ],
//                                 ),
//                                 child: const Center(child: Text("sport")),
//                               ),
//                         SizedBox(
//                           width: 20,
//                         ),
//                         !isTyping
//                             ? Container()
//                             : Container(
//                                 width: 120,
//                                 padding: const EdgeInsets.all(5),
//                                 margin:
//                                     const EdgeInsets.only(top: 10, bottom: 30),
//                                 decoration: BoxDecoration(
//                                   borderRadius: BorderRadius.circular(5),
//                                   color: backgroundColor,
//                                   boxShadow: [
//                                     const BoxShadow(
//                                       color: Colors.blue,
//                                       spreadRadius: 1,
//                                       blurRadius: 1,
//                                       offset: Offset(0,
//                                           2), // Changes the position of the shadow
//                                     ),
//                                   ],
//                                 ),
//                                 child:
//                                     const Center(child: Text("entertainment")),
//                               ),
//                       ],
//                     ),
//                     SlideAction(
//                       sliderButtonIconPadding: 12,
//                       sliderRotate: false,
//                       outerColor: Colors.blue,
//                       text: "Drag to post",
//                       height: 80,
//                       elevation: 0,
//                       onSubmit: () {
//                         setState(() {
//                           submitted = true;
//                         });
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
// }


// class PostScreen extends StatefulWidget {
//   const PostScreen({super.key});
//
//   @override
//   State<PostScreen> createState() => _PostScreenState();
// }
//
// class _PostScreenState extends State<PostScreen> {
//   bool isImageSelected = false;
//   File? imageFile;
//   bool submitted = false;
//   bool isTyping = false;
//   bool isEditingComplete = false;
//   bool isPlaying = false;
//   late Timer _timer;
//
//
//   double maxWidth = 0.0;
//   double maxMovable = 0.928;
//   List<String> choices = [
//     'News',
//     'Entertainment',
//     'Politics',
//     'Automotive',
//     'Sports',
//   ];
//   List<String> multipleSelected = [];
//
//   void setMultipleSelected(List<String> value) {
//     setState(() => multipleSelected = value);
//   }
//
//   _pickImagefromGallery() async {
//     try {
//       final pickedImage =
//           await ImagePicker().pickImage(source: ImageSource.gallery);
//       if (pickedImage != null) {
//         setState(() {
//           imageFile = File(pickedImage.path);
//           isImageSelected = true;
//         });
//       } else {
//
//       }
//     } catch (e) {
//
//     }
//   }
//
//   _pickImagefromCamera() async {
//     try {
//       final pickedImage =
//           await ImagePicker().pickImage(source: ImageSource.camera);
//       if (pickedImage != null) {
//         setState(() {
//           imageFile = File(pickedImage.path);
//           isImageSelected = true;
//         });
//       } else {
//
//       }
//     } catch (e) {
//
//     }
//   }
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//
//   }
//   @override
//   void dispose() {
//     // TODO: implement dispose
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedContainer(
//         duration: const Duration(seconds: 1),
//         padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
//         height: MediaQuery.of(context).size.height * 0.75,
//         width: MediaQuery.of(context).size.width,
//         decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(20), topRight: Radius.circular(20))),
//         child: Scaffold(
//           backgroundColor: Colors.white,
//           body: Padding(
//             padding: EdgeInsets.only(bottom: 20.0, left: 40.0, right: 30.0),
//             child: Column(
//               children: [
//                 SizedBox(
//                     height: 300,
//                     width: 300,
//                   child: LottieBuilder.asset('assets/waiting.json'),
//
//                    ),
//                 SizedBox(height: 30,),
//                 Text(
//                     "You have been signed up for the waitlist for the full version.\n\nSit back and relax ;)", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500),),
//               Spacer(),
//
//                 GestureDetector(
//                     onTap: ()async {
//
//                         await FirebaseAuth.instance.signOut();
//                         Navigator.pushReplacement(
//                             context, MaterialPageRoute(builder: (context) => IntroductionPage()));
//
//                     },
//                     child: Text("Sign Out", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w500)))
//               ],
//             )
//           ),
//         ));
//   }
// }

//
//
//
// class PostScreen extends StatefulWidget {
//   const PostScreen({super.key});
//
//   @override
//   State<PostScreen> createState() => _PostScreenState();
// }
//
// class _PostScreenState extends State<PostScreen> {
//   bool isImageSelected = false;
//   File? imageFile;
//   _pickImagefromGallery() async {
//     try {
//       final pickedImage =
//           await ImagePicker().pickImage(source: ImageSource.gallery);
//       if (pickedImage != null) {
//         setState(() {
//           imageFile = File(pickedImage.path);
//           isImageSelected = true;
//         });
//       } else {
//
//       }
//     } catch (e) {
//
//     }
//   }
//
//   _pickImagefromCamera() async {
//     try {
//       final pickedImage =
//           await ImagePicker().pickImage(source: ImageSource.camera);
//       if (pickedImage != null) {
//         setState(() {
//           imageFile = File(pickedImage.path);
//           isImageSelected = true;
//         });
//       } else {
//
//       }
//     } catch (e) {
//
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,
//       // appBar: AppBar(
//       //   elevation: 0,
//       //   backgroundColor: backgroundColor,
//       //   leading: IconButton(
//       //       onPressed: () {},
//       //       icon: const Icon(
//       //         Icons.highlight_remove_outlined,
//       //         color: Colors.grey,
//       //       )),
//       // ),
//       body: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: SingleChildScrollView(
//           child: Column(
//             children: [
//               TextField(
//                 maxLines: null, // Set maxLines to null for multiline
//                 decoration: InputDecoration(
//                   labelText: 'What do you want you talk about?',
//                   labelStyle: TextStyle(color: Colors.grey.shade900),
//                   border: InputBorder.none, // Remove the border
//                   contentPadding:
//                       EdgeInsets.only(bottom: 8.0), // Adjust padding as needed
//                 ),
//                 onEditingComplete: () {
//                   setState(() {
//                     isTyping = false;
//                   });
//                 },
//                 onSubmitted: (t) {
//                   setState(() {
//                     isTyping = false;
//                   });
//                 },
//                 onTapOutside: (t) {
//                   setState(() {
//                     isTyping = false;
//                   });
//                 },
//                 onTap: () {
//                   setState(() {
//                     isTyping = true;
//                   });
//                 },
//               ),
//               SizedBox(
//                 height: 40,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//                   imageFile == null
//                       ? const SizedBox(
//                           height: 100,
//                         )
//                       : ClipRRect(
//                           borderRadius: BorderRadius.circular(20.0),
//                           child: Image(
//                             height: 150,
//                             width: 150,
//                             fit: BoxFit.cover,
//                             image: FileImage(imageFile!),
//                           ),
//                         ),
//                 ],
//               ),
//               isTyping
//                   ? Container()
//                   : SizedBox(
//                       height: MediaQuery.of(context).size.height / 2.8,
//                     ),
//               Container(
//                 margin: const EdgeInsets.only(top: 0),
//                 padding: const EdgeInsets.only(top: 0, left: 10, right: 10),
//                 width: MediaQuery.of(context).size.width,
//                 height: MediaQuery.of(context).size.height - 200,
//                 decoration: BoxDecoration(
//                   borderRadius: const BorderRadius.only(
//                     topLeft:
//                         Radius.circular(40.0), // Adjust the radius as needed
//                     topRight: Radius.circular(40.0),
//                   ),
//                   color: isTyping ? Colors.white : backgroundColor,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   children: [
//                     isTyping
//                         ? Container()
//                         : Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: [
//                               GestureDetector(
//                                   onTap: () {
//                                     _pickImagefromGallery();
//                                   },
//                                   child: Image.asset("icons/post_icons/0.png")),
//                               // Image.asset("icons/post_icons/1.png"),
//                               GestureDetector(
//                                   onTap: () {
//                                     _pickImagefromCamera();
//                                   },
//                                   child: Image.asset("icons/post_icons/2.png")),
//                             ],
//                           ),
//                     SizedBox(
//                       height: 10,
//                     ),
//                     !isTyping
//                         ? Container()
//                         : const Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Text("Suggestions based on your InZone post"),
//                             ],
//                           ),
//                     Row(
//                       children: [
//                         !isTyping
//                             ? Container()
//                             : Container(
//                                 width: 80,
//                                 padding: const EdgeInsets.all(5),
//                                 margin:
//                                     const EdgeInsets.only(top: 10, bottom: 30),
//                                 decoration: BoxDecoration(
//                                   borderRadius: BorderRadius.circular(5),
//                                   color: backgroundColor,
//                                   boxShadow: [
//                                     const BoxShadow(
//                                       color: Colors.blue,
//                                       spreadRadius: 1,
//                                       blurRadius: 1,
//                                       offset: Offset(0,
//                                           2), // Changes the position of the shadow
//                                     ),
//                                   ],
//                                 ),
//                                 child: const Center(child: Text("sport")),
//                               ),
//                         SizedBox(
//                           width: 20,
//                         ),
//                         !isTyping
//                             ? Container()
//                             : Container(
//                                 width: 120,
//                                 padding: const EdgeInsets.all(5),
//                                 margin:
//                                     const EdgeInsets.only(top: 10, bottom: 30),
//                                 decoration: BoxDecoration(
//                                   borderRadius: BorderRadius.circular(5),
//                                   color: backgroundColor,
//                                   boxShadow: [
//                                     const BoxShadow(
//                                       color: Colors.blue,
//                                       spreadRadius: 1,
//                                       blurRadius: 1,
//                                       offset: Offset(0,
//                                           2), // Changes the position of the shadow
//                                     ),
//                                   ],
//                                 ),
//                                 child:
//                                     const Center(child: Text("entertainment")),
//                               ),
//                       ],
//                     ),
//                     SlideAction(
//                       sliderButtonIconPadding: 12,
//                       sliderRotate: false,
//                       outerColor: Colors.blue,
//                       text: "Drag to post",
//                       height: 80,
//                       elevation: 0,
//                       onSubmit: () {
//                         setState(() {
//                           submitted = true;
//                         });
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
// }
class VideoWidget extends StatefulWidget {
  final String videoUrl;

  const VideoWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlayable = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _checkHeadersAndInitialize();
  }

  Future<void> _checkHeadersAndInitialize() async {
    try {
      final response = await http.head(Uri.parse(widget.videoUrl));
      var headers = response.headers;
if (Platform.isIOS){
  // Check if Content-Disposition header is missing
  if (!headers.containsKey('content-disposition')) {
    print('Content-Disposition header is missing');
    // Handle missing header (e.g., show error or avoid playback)

    setState(() {
      _isPlayable = false;
    });
    return;
  }
}


      // Proceed to initialize the video player
      await _initializeVideoPlayer();
    } catch (e) {
      print('Error checking headers: $e');
      setState(() {
        _isPlayable = false;
      });
    }
  }

  Future<void> _initializeVideoPlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));


    try {
      await _videoPlayerController.initialize();
      setState(() {
        _isInitialized = true;

        // Check if the video has valid dimensions and is in a playable state
        if (_videoPlayerController.value.size != null &&
            _videoPlayerController.value.size.width > 0 &&
            _videoPlayerController.value.size.height > 0 &&
            _videoPlayerController.value.isInitialized &&
            !_videoPlayerController.value.hasError) {
          _isPlayable = true;
        } else {
          _isPlayable = false;
        }
      });
    } catch (e) {
      print('Error initializing video: $e');
      setState(() {
        _isPlayable = false;
      });
    }
  }

  void _togglePlayback() {
    setState(() {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.pause();
      } else {
        _videoPlayerController.play();
        _startHideControlsTimer(); // Start the timer to hide controls
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel(); // Cancel any existing timer
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _showControls = false;
      });
    });
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer(); // Restart the timer
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || !_isPlayable) {
      return const SizedBox.shrink(); // Hide the widget if video is not playable
    }

    return GestureDetector(
      onTap: _showControlsTemporarily, // Show controls temporarily on tap
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: VideoPlayer(_videoPlayerController),
          ),
          if (_showControls)
            IconButton(
              icon: Icon(
                _videoPlayerController.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 48.0,
              ),
              onPressed: _togglePlayback,
            ),
        ],
      ),
    );
  }
}