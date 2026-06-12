import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:inzone/components/video/video_player_widget_post_screen.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/shared_preferences_helper_class.dart';
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
  List<Map<String, String>> characters =
      []; // List of characters with name and image
  bool _areCharactersLoading = true;
  Map<String, String>? selectedCharacter;

  // AI Generation state
  bool isGenerating = false;
  String generationStep = 'idle'; // idle, asking, generating, complete
  List<Map<String, String>> clarifyingQuestions = [];
  List<String> userAnswers = [];
  String generatedPost = '';
  TextEditingController questionController = TextEditingController();
  TextEditingController postController = TextEditingController();
  int currentQuestionIndex = 0;

  // Sample clarifying questions for AI generation
  final List<Map<String, String>> sampleQuestions = [
    {
      'question': 'What tone would you like your character to use?',
      'placeholder': 'E.g., casual, formal, humorous, inspiring...'
    },
    {
      'question': 'What specific aspect of your topic should be emphasized?',
      'placeholder': 'E.g., personal experience, facts, opinion...'
    },
    {
      'question': 'Who is your target audience?',
      'placeholder': 'E.g., friends, professionals, general public...'
    }
  ];
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
  UploadTask? _activeVideoUploadTask;

  double high = 0.928;
  double medium = 0.8;
  double low = 0.4;
  late Timer _timer;
  List<String> imageUrls = [];
  List<String> videoUrls = [];
  List<String> thumbnailUrls = [];

  // Real-time sentiment analysis state
  bool isAnalyzingRealTime = false;
  String? currentBlockReason;

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

  Future<void> _loadPreferences() async {
    await SharedPreferencesHelperClass.getStringList();
    setState(() {});
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
          // REAL-TIME DEBUG LOGGING
          print("=== REAL-TIME MODERATION DEBUG ===");
          print("Real-time content: '$postContent'");
          print("Real-time result: ${result.toString()}");
          if (result.containsKey('block_reason') && result['block_reason'] != null) {
            print("Real-time block reason: ${result['block_reason']}");
          }
          print("=====================================\n");
          
          setState(() {
            isAnalyzingRealTime = false;
            int sentiment = result["sentiment"] as int;
            bool isBlocked = result["blocked"] ?? false;
            bool isFallback = result["fallback"] ?? false;
            currentBlockReason = result["block_reason"];

            if ((sentiment == -2 || isBlocked) && !isFallback) {
              // Content is blocked (only if not using fallback)
              moveValue = low;
              doesNotWork = true;
            } else if (sentiment == -1 && !isFallback) {
              moveValue = low;
              doesNotWork = true;
            } else if (sentiment == 0 || isFallback) {
              // Neutral sentiment OR fallback mode (allow posting)
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
          // Default to neutral on error (allow posting)
          moveValue = medium;
          doesNotWork = false;
          currentBlockReason = "Analysis service unavailable - posting allowed";
        });
      }
      return <String, dynamic>{}; // Return empty map for error case
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
          return "Content moderation offline - posting allowed";
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

  // AI Generation methods
  void _startAIGeneration() {
    setState(() {
      isGenerating = true;
      generationStep = 'asking';
      clarifyingQuestions = List.from(sampleQuestions);
      userAnswers = [];
      currentQuestionIndex = 0;
      questionController.clear();
    });
  }

  void _submitAnswer() {
    if (questionController.text.trim().isEmpty) return;

    setState(() {
      userAnswers.add(questionController.text.trim());
      questionController.clear();

      if (currentQuestionIndex < clarifyingQuestions.length - 1) {
        currentQuestionIndex++;
      } else {
        generationStep = 'generating';
      }
    });

    // If all questions are answered, generate the post
    if (generationStep == 'generating') {
      _generatePost();
    }
  }

  void _generatePost() async {
    // Simulate AI generation with a delay
    await Future.delayed(const Duration(seconds: 2));

    // Sample generated post based on character and user input
    String samplePost = _createSamplePost();

    setState(() {
      generatedPost = samplePost;
      generationStep = 'complete';
    });
  }

  Future<void> _addInCashAfterPosting(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(amount),
      });
    } catch (e) {
      debugPrint('Error adding InCash to user: $e');
      throw Exception('Failed to add InCash to balance');
    }
  }

  String _createSamplePost() {
    String characterName = selectedCharacter!['name']!;
    String originalPrompt = postContent;
    String tone = userAnswers.isNotEmpty ? userAnswers[0] : 'casual';
    String aspect =
        userAnswers.length > 1 ? userAnswers[1] : 'personal experience';
    String audience = userAnswers.length > 2 ? userAnswers[2] : 'friends';

    // Sample generated content
    return "Hey everyone! 👋 $characterName here with some thoughts on '$originalPrompt'.\n\n"
        "Speaking from ${aspect.toLowerCase()}, I've been thinking about this topic a lot lately. "
        "The ${tone.toLowerCase()} way I see it is that we all have unique perspectives to share.\n\n"
        "For those of you who are ${audience.toLowerCase()}, what's your take on this? "
        "I'd love to hear your thoughts! 💭\n\n"
        "#thoughts #${characterName.toLowerCase()} #community";
  }

  void _useGeneratedPost() {
    setState(() {
      postContent = generatedPost;
      postController.text = generatedPost;
      _resetAIGeneration();
    });
  }

  void _repromptGeneration() {
    setState(() {
      generationStep = 'asking';
      currentQuestionIndex = 0;
      userAnswers = [];
      questionController.clear();
    });
  }

  void _resetAIGeneration() {
    setState(() {
      isGenerating = false;
      generationStep = 'idle';
      clarifyingQuestions = [];
      userAnswers = [];
      generatedPost = '';
      currentQuestionIndex = 0;
      questionController.clear();
    });
  }

  bool get _hasRunningVideoUpload =>
      _activeVideoUploadTask != null &&
      _activeVideoUploadTask!.snapshot.state == TaskState.running;

  Future<void> _cancelActiveVideoUpload({bool showToast = true}) async {
    try {
      await _activeVideoUploadTask?.cancel();
      _activeVideoUploadTask = null;
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
      if (showToast && mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.alertCircle,
            color: Colors.orangeAccent,
          ),
          message: "Video upload cancelled",
        );
      }
    } catch (_) {}
  }

  Future<void> _handleClosePressed() async {
    if (_hasRunningVideoUpload || isUploading) {
      final shouldLeave = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Cancel upload?'),
                content: const Text(
                    'A media upload is in progress. Leaving now will cancel it.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Stay'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Leave'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldLeave) return;
      await _cancelActiveVideoUpload(showToast: false);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _fetchSavedCharacters() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _areCharactersLoading = false;
        });
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(user.uid)
          .get();

      if (mounted &&
          userDoc.exists &&
          userDoc.data()!.containsKey('savedCharacters')) {
        final savedCharactersData =
            userDoc.get('savedCharacters') as List<dynamic>;

        final fetchedCharacters = savedCharactersData
            .map((charData) {
              final name = charData['name'] as String?;
              final imageUrl = charData['profilePictureUrl'] as String?;

              if (name != null && imageUrl != null) {
                return {'name': name, 'image': imageUrl};
              }
              return null;
            })
            .where((char) => char != null)
            .cast<Map<String, String>>()
            .toList();

        setState(() {
          characters = fetchedCharacters;
        });
      }
    } catch (e) {
      debugPrint('Error fetching saved characters: $e');
      // Optionally show an error message to the user via a toast or snackbar
    } finally {
      if (mounted) {
        setState(() {
          _areCharactersLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _loadPreferences();
    _fetchSavedCharacters();
    _startTime = DateTime.now().toUtc();
    pageOpened += 1;
  }

  @override
  void dispose() {
    _activeVideoUploadTask?.cancel();
    questionController.dispose();
    postController.dispose();
    _focusNode.dispose();

    DateTime endTime = DateTime.now().toUtc();
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
                  Padding(
                    padding: const EdgeInsets.only(left: 5.0, right: 15.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              _handleClosePressed();
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

                        // Character indicator in header
                        if (selectedCharacter != null)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context).primaryColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: selectedCharacter!['image']!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: Colors.grey.withOpacity(0.2),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          color: Colors.grey.withOpacity(0.2),
                                          child: const Icon(
                                            FeatherIcons.user,
                                            size: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'As ${selectedCharacter!['name']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color:
                                                Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (selectedCharacter == null) const Spacer(),
                        const SizedBox(width: 10),
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
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () async {
                                    if (postContent.trim().isEmpty ||
                                        isPosting) {
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
                                      // Enhanced sentiment analysis with media
                                      var analysis =
                                          await InZoneDatabase.analyzeSentiment(
                                        postContent,
                                        imageUrls: imageUrls,
                                        videoUrls: videoUrls,
                                      );

                                      print(
                                          "Sentiment analysis result: $analysis");
                                      
                                      // DETAILED DEBUG LOGGING
                                      print("=== CONTENT MODERATION DEBUG ===");
                                      print("Content being analyzed: '$postContent'");
                                      print("Image URLs: $imageUrls");
                                      print("Video URLs: $videoUrls");
                                      print("Full analysis response: ${analysis.toString()}");
                                      if (analysis.containsKey('detailed_analysis')) {
                                        print("Detailed analysis: ${analysis['detailed_analysis']}");
                                      }
                                      if (analysis.containsKey('block_reason')) {
                                        print("Block reason: ${analysis['block_reason']}");
                                      }
                                      print("================================");

                                      int sentiment =
                                          analysis["sentiment"] as int;
                                      bool isBlocked = analysis["blocked"] ?? false;

                                      if (!mounted || !context.mounted) {
                                        return;
                                      }
                                      setState(() {
                                        if (sentiment == -2 || isBlocked) {
                                          // Content is blocked
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

                                      if (sentiment == -2 || isBlocked) {
                                        setState(() {
                                          isPosting = false;
                                        });

                                        String blockReason = analysis["block_reason"] ?? "Content violates our guidelines";
                                        ToastService.showToast(
                                          context,
                                          backgroundColor:
                                              Theme.of(context).canvasColor,
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
                                      if (selectedCharacter != null) {
                                        print(
                                            "Posting as character. Name: ${selectedCharacter!['name']}, Image: ${selectedCharacter!['image']}");
                                      } else {
                                        print("Posting as regular user.");
                                      }

                                      final result =
                                          await InZoneDatabase.createHumanPost(
                                        content: postContent,
                                        imageRefs: imageUrls,
                                        videoRefs: videoUrls,
                                        characterName: selectedCharacter != null
                                            ? selectedCharacter!['name']
                                            : null,
                                        characterImage:
                                            selectedCharacter != null
                                                ? selectedCharacter!['image']
                                                : null,
                                      );

                                      print("Create post result: $result");

                                      if (!mounted || !context.mounted) {
                                        return;
                                      }
                                      if (result["success"] != true) {
                                        setState(() {
                                          isPosting = false;
                                        });

                                        String errorMessage =
                                            "Failed to create post. Please try again.";

                                        // Check if content was blocked
                                        if (result["blocked"] == true) {
                                          errorMessage = result["error"] ?? "Content was blocked due to policy violations.";
                                        } else if (result["error"] != null) {
                                          errorMessage = result["error"].toString();
                                        } else if (result["message"] != null) {
                                          errorMessage = result["message"].toString();
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

                                      // Add InCash reward after successful post creation
                                      try {
                                        await _addInCashAfterPosting(5);
                                        print(
                                            "Successfully added 5 InCash to user's balance");
                                      } catch (e) {
                                        print("Error adding InCash reward: $e");
                                        // Don't prevent the success flow even if InCash addition fails
                                      }

                                      if (!context.mounted) return;
                                      context.pop();

                                      showDialog(
                                        context: context,
                                        builder: (_) {
                                          _timer = Timer(
                                              const Duration(seconds: 1), () {
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
                                                          MediaQuery.of(context)
                                                              .size
                                                              .height,
                                                      width:
                                                          MediaQuery.of(context)
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
                                      if (mounted && context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Failed to post: ${e.toString().substring(0, math.min(e.toString().length, 100))}",
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onError),
                                            ),
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            duration:
                                                const Duration(seconds: 2),
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
                              border: Border.all(
                                  color: Theme.of(context).canvasColor),
                              borderRadius: BorderRadius.circular(30),
                              color: Theme.of(context).dialogBackgroundColor),
                          duration: Duration(milliseconds: isAnalyzingRealTime ? 200 : 600),
                          curve: Curves.easeInOut,
                          // transform:  (Matrix4.identity() + Matrix4.rotationZ(math.pi / 4))
                        ),
                      ],
                    ),
                  ),

                  //  const Divider(),
                  const SizedBox(height: 15),

                  // Text Input Section with integrated character selection
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade900.withOpacity(0.3)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Character Selection at top of container
                          _areCharactersLoading
                              ? const Center(
                                  child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: CircularProgressIndicator(),
                                ))
                              : (characters.isNotEmpty
                                  ? Container(
                                      padding: const EdgeInsets.only(
                                          top: 12, left: 12, right: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                FeatherIcons.users,
                                                size: 16,
                                                color:
                                                    Theme.of(context).hintColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Post as',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Theme.of(context)
                                                          .hintColor,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                              const Spacer(),
                                              if (selectedCharacter != null &&
                                                  postContent.trim().isNotEmpty)
                                                GestureDetector(
                                                  onTap: () {
                                                    _startAIGeneration();
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.grey.shade800
                                                              .withOpacity(0.5)
                                                          : Colors
                                                              .grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Colors
                                                                .grey.shade700
                                                            : Colors
                                                                .grey.shade300,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          FeatherIcons.zap,
                                                          size: 14,
                                                          color:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.color,
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                          'Generate',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 60,
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: characters.length + 1,
                                              itemBuilder: (context, index) {
                                                if (index == 0) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        selectedCharacter =
                                                            null;
                                                      });
                                                    },
                                                    child: Container(
                                                      width: 60,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              right: 8),
                                                      child: Column(
                                                        children: [
                                                          Container(
                                                            width: 40,
                                                            height: 40,
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border:
                                                                  Border.all(
                                                                color: selectedCharacter ==
                                                                        null
                                                                    ? Theme.of(
                                                                            context)
                                                                        .primaryColor
                                                                    : Colors
                                                                        .grey
                                                                        .withOpacity(
                                                                            0.4),
                                                                width: 2,
                                                              ),
                                                              color: selectedCharacter ==
                                                                      null
                                                                  ? Theme.of(
                                                                          context)
                                                                      .primaryColor
                                                                      .withOpacity(
                                                                          0.1)
                                                                  : Colors
                                                                      .transparent,
                                                            ),
                                                            child: Icon(
                                                              FeatherIcons.user,
                                                              size: 18,
                                                              color: selectedCharacter ==
                                                                      null
                                                                  ? Theme.of(
                                                                          context)
                                                                      .primaryColor
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            'You',
                                                            style:
                                                                Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      fontSize:
                                                                          9,
                                                                      fontWeight: selectedCharacter ==
                                                                              null
                                                                          ? FontWeight
                                                                              .w600
                                                                          : FontWeight
                                                                              .w400,
                                                                      color: selectedCharacter ==
                                                                              null
                                                                          ? Theme.of(context)
                                                                              .primaryColor
                                                                          : Theme.of(context)
                                                                              .hintColor,
                                                                    ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }

                                                final character =
                                                    characters[index - 1];
                                                final isSelected =
                                                    selectedCharacter ==
                                                        character;

                                                return GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      selectedCharacter =
                                                          character;
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 60,
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 8),
                                                    child: Column(
                                                      children: [
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration:
                                                              BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color: isSelected
                                                                  ? Theme.of(
                                                                          context)
                                                                      .primaryColor
                                                                  : Colors.grey
                                                                      .withOpacity(
                                                                          0.4),
                                                              width: 2,
                                                            ),
                                                          ),
                                                          child: ClipOval(
                                                            child:
                                                                CachedNetworkImage(
                                                              imageUrl:
                                                                  character[
                                                                      'image']!,
                                                              fit: BoxFit.cover,
                                                              placeholder:
                                                                  (context,
                                                                          url) =>
                                                                      Container(
                                                                color: Colors
                                                                    .grey
                                                                    .withOpacity(
                                                                        0.2),
                                                                child:
                                                                    const Center(
                                                                  child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2),
                                                                ),
                                                              ),
                                                              errorWidget:
                                                                  (context, url,
                                                                          error) =>
                                                                      Container(
                                                                color: Colors
                                                                    .grey
                                                                    .withOpacity(
                                                                        0.2),
                                                                child:
                                                                    const Icon(
                                                                  FeatherIcons
                                                                      .user,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          character['name']!,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    fontSize: 9,
                                                                    fontWeight: isSelected
                                                                        ? FontWeight
                                                                            .w600
                                                                        : FontWeight
                                                                            .w400,
                                                                    color: isSelected
                                                                        ? Theme.of(context)
                                                                            .primaryColor
                                                                        : Theme.of(context)
                                                                            .hintColor,
                                                                  ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink()),

                          // Divider between character selection and text input
                          if (characters.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              height: 1,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                            ),

                          // Text Input
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                            child: TextField(
                              controller: postController,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 16,
                              textInputAction: TextInputAction.send,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                              decoration: InputDecoration(
                                hintText: selectedCharacter == null
                                    ? 'What do you want to talk about?'
                                    : 'Give ${selectedCharacter!['name']} a prompt to generate a post...',
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
                              onChanged: (value) {
                                _onTextChanged(value);
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
                        ],
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
                          // ...existing code...
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
                                        image: CachedNetworkImageProvider(url),
                                      ),
                                    ),
                                    Positioned(
                                      top: 5,
                                      right: 5,
                                      child: GestureDetector(
                                        onTap: () async {
                                          try {
                                            await AuthWork.deletePostImage(url);
                                            setState(() {
                                              imageUrls.remove(url);
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
                              )),
                          // ...existing video code...
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
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                                      height: 140,
                                                      width: 140,
                                                      color: Colors.black54,
                                                      child: const Center(
                                                        child: Icon(
                                                          FeatherIcons.film,
                                                          color: Colors.white54,
                                                          size: 36,
                                                        ),
                                                      ),
                                                    ),
                                          ),
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
                                              onTap: () async {
                                                try {
                                                  await AuthWork
                                                      .deletePostVideo(
                                                          videoUrls[index],
                                                          thumbnailUrls[index]);
                                                  setState(() {
                                                    videoUrls.removeAt(index);
                                                    thumbnailUrls
                                                        .removeAt(index);
                                                  });
                                                } catch (e) {}
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
                  const SizedBox(
                    height: 15,
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
            // AI Generation Modal Overlay
            if (isGenerating) _buildAIGenerationModal(),
          ],
        ),
        bottomSheet: isGenerating
            ? null
            : Padding(
                padding: const EdgeInsets.only(
                  bottom: 20,
                  left: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Incash reward note at bottom center
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Center(
                        child: Text(
                          'Note: You earn 5 InCash for each post you make!',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).hintColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                        ),
                      ),
                    ),
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
                              if (mounted) {
                                setState(() {
                                  isUploading = true;
                                });
                              }
                              try {
                                final value = await AuthWork.sendPostImage(
                                  FirebaseAuth.instance.currentUser!.uid,
                                  File(image.path),
                                );
                                if (!mounted) return;
                                setState(() {
                                  imageUrls.add(value);
                                });
                                _analyzeContentRealTime();
                              } catch (e) {
                                if (!mounted || !context.mounted) return;
                                ToastService.showToast(
                                  context,
                                  backgroundColor:
                                      Theme.of(context).canvasColor,
                                  shadowColor: Colors.transparent,
                                  leading: const Icon(
                                    FeatherIcons.xCircle,
                                    color: Colors.redAccent,
                                  ),
                                  message: "Failed to upload image",
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    isUploading = false;
                                  });
                                }
                              }
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
                              if (mounted) {
                                setState(() {
                                  isUploading = true;
                                });
                              }

                              try {
                                final value = await AuthWork.sendPostVideo(
                                  FirebaseAuth.instance.currentUser!.uid,
                                  File(video.path),
                                  onVideoUploadTask: (task) {
                                    _activeVideoUploadTask = task;
                                  },
                                );

                                if (!mounted) return;
                                setState(() {
                                  videoUrls.add(value["videoUrl"]!);
                                  thumbnailUrls.add(value["thumbnailUrl"]!);
                                });
                                _analyzeContentRealTime();
                              } on UploadCancelledException {
                              } catch (e) {
                                if (!mounted || !context.mounted) return;
                                ToastService.showToast(
                                  context,
                                  backgroundColor:
                                      Theme.of(context).canvasColor,
                                  shadowColor: Colors.transparent,
                                  leading: const Icon(
                                    FeatherIcons.xCircle,
                                    color: Colors.redAccent,
                                  ),
                                  message: "Failed to upload video",
                                );
                              } finally {
                                _activeVideoUploadTask = null;
                                if (mounted) {
                                  setState(() {
                                    isUploading = false;
                                  });
                                }
                              }
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
                              if (mounted) {
                                setState(() {
                                  isUploading = true;
                                });
                              }
                              try {
                                final value = await AuthWork.sendPostImage(
                                  FirebaseAuth.instance.currentUser!.uid,
                                  File(image.path),
                                );
                                if (!mounted) return;
                                setState(() {
                                  imageUrls.add(value);
                                });
                                _analyzeContentRealTime();
                              } catch (e) {
                                if (!mounted || !context.mounted) return;
                                ToastService.showToast(
                                  context,
                                  backgroundColor:
                                      Theme.of(context).canvasColor,
                                  shadowColor: Colors.transparent,
                                  leading: const Icon(
                                    FeatherIcons.xCircle,
                                    color: Colors.redAccent,
                                  ),
                                  message: "Failed to upload image",
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    isUploading = false;
                                  });
                                }
                              }
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

  Widget _buildAIGenerationModal() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        FeatherIcons.cpu,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Post Generator',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          FeatherIcons.x,
                          size: 20,
                          color: Theme.of(context).hintColor,
                        ),
                        onPressed: _resetAIGeneration,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Content based on generation step
                  if (generationStep == 'asking') ...[
                    _buildQuestionStep(),
                  ] else if (generationStep == 'generating') ...[
                    _buildGeneratingStep(),
                  ] else if (generationStep == 'complete') ...[
                    _buildCompleteStep(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionStep() {
    final currentQuestion = clarifyingQuestions[currentQuestionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress indicator
        Row(
          children: [
            Text(
              'Question ${currentQuestionIndex + 1} of ${clarifyingQuestions.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const Spacer(),
            Container(
              width: 80,
              height: 2,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor:
                    (currentQuestionIndex + 1) / clarifyingQuestions.length,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Question
        Text(
          currentQuestion['question']!,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 16),

        // Answer input
        TextField(
          controller: questionController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: currentQuestion['placeholder'],
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _submitAnswer(),
        ),
        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            if (currentQuestionIndex > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      currentQuestionIndex--;
                      if (userAnswers.isNotEmpty) {
                        questionController.text = userAnswers.removeLast();
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (currentQuestionIndex > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  currentQuestionIndex < clarifyingQuestions.length - 1
                      ? 'Next'
                      : 'Generate',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneratingStep() {
    return Column(
      children: [
        const SizedBox(height: 20),
        CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          strokeWidth: 2,
        ),
        const SizedBox(height: 20),
        Text(
          'Generating your post as ${selectedCharacter!['name']}...',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'This may take a few moments',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
      ],
    );
  }

  Widget _buildCompleteStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Generated post preview
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: CachedNetworkImageProvider(selectedCharacter!['image']!),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedCharacter!['name']!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                generatedPost,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _repromptGeneration,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                child: const Text('Regenerate'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _useGeneratedPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text('Use This Post'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
