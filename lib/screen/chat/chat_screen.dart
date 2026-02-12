import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inzone/components/chat/chat_app_bar.dart';
import 'package:inzone/components/chat/chat_input.dart';
import 'package:inzone/components/chat/message_bubble.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/chat/post_chat_screen.dart';
import 'package:inzone/theme/light_theme.dart'; // Import for ChatTheme extension
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// AI Chat Session Tracker
class AIChatSessionTracker {
  static final Map<String, DateTime> _sessionStartTimes = {};
  static final Map<String, int> _sessionMessageCounts = {};
  static final Map<String, List<String>> _sessionInteractionTypes = {};

  static void startSession(String characterId) {
    _sessionStartTimes[characterId] = DateTime.now();
    _sessionMessageCounts[characterId] = 0;
    _sessionInteractionTypes[characterId] = [];
  }

  static void incrementMessageCount(
      String characterId, String interactionType) {
    _sessionMessageCounts[characterId] =
        (_sessionMessageCounts[characterId] ?? 0) + 1;
    _sessionInteractionTypes[characterId]?.add(interactionType);
  }

  static void endSession(String characterId) {
    final startTime = _sessionStartTimes[characterId];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inSeconds;
      final messageCount = _sessionMessageCounts[characterId] ?? 0;
      final interactions = _sessionInteractionTypes[characterId] ?? [];
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId != null && duration > 5) {
        // Only track sessions longer than 5 seconds
        AppsFlyerService().trackAICharacterInteraction(
          characterId: characterId,
          userId: userId,
          durationSeconds: duration,
          messageCount: messageCount,
          interactionType: interactions.isNotEmpty ? interactions.last : 'chat',
        );

        // Track character popularity
        AppsFlyerService().logEvent('ai_character_popular', {
          'character_id': characterId,
          'user_id': userId,
          'session_duration': duration,
          'messages_exchanged': messageCount,
          'interaction_types': interactions.join(','),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      _sessionStartTimes.remove(characterId);
      _sessionMessageCounts.remove(characterId);
      _sessionInteractionTypes.remove(characterId);
    }
  }

  static void clearSession(String characterId) {
    _sessionStartTimes.remove(characterId);
    _sessionMessageCounts.remove(characterId);
    _sessionInteractionTypes.remove(characterId);
  }
}

class ChatScreen extends StatefulWidget {
  ChatUser userData;

  ChatScreen({super.key, required this.userData});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController msg = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // Create a ScrollController
  final ScrollController _mainScrollController = ScrollController();

  bool _isSending = false;

  // AI Character Interaction Tracking
  late DateTime _chatStartTime;
  late String _characterId;
  int _userMessageCount = 0;
  int _aiResponseCount = 0;
  final List<String> _interactionTypes = [];

  // Function to scroll to the end of the column
  void scrollToEnd() {
    setState(() {
      _mainScrollController.animateTo(
        _mainScrollController.position.maxScrollExtent + 100,
        duration:
            const Duration(milliseconds: 300), // You can adjust the duration
        curve: Curves.easeOut, // You can adjust the curve
      );
    });
  }

  bool isUploading = false;
  List<Widget> messageCards = [];
  List<Set> chatHistory = [];

  @override
  void initState() {
    super.initState();
    _chatStartTime = DateTime.now();
    _characterId = widget.userData.email ?? 'unknown';

    // Start AI character session tracking
    AIChatSessionTracker.startSession(_characterId);

    // Track AI character interaction start
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      AppsFlyerService().logEvent('ai_character_session_start', {
        'character_id': _characterId,
        'character_name': widget.userData.name ?? 'Unknown',
        'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  @override
  void dispose() {
    // End AI character session tracking
    AIChatSessionTracker.endSession(_characterId);

    // Track final session analytics
    final sessionDuration = DateTime.now().difference(_chatStartTime).inSeconds;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null && sessionDuration > 5) {
      AppsFlyerService().logEvent('ai_character_session_end', {
        'character_id': _characterId,
        'character_name': widget.userData.name ?? 'Unknown',
        'user_id': userId,
        'session_duration_sec': sessionDuration,
        'user_messages_sent': _userMessageCount,
        'ai_responses_received': _aiResponseCount,
        'interaction_quality': _calculateInteractionQuality(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    _mainScrollController.dispose();
    msg.dispose();
    _scrollController
        .dispose(); // Dispose the controller when the widget is destroyed
    super.dispose();
  }

  String _calculateInteractionQuality() {
    if (_userMessageCount == 0) return 'no_interaction';
    if (sessionDuration < 30) return 'brief';
    if (_userMessageCount < 3) return 'low';
    if (_userMessageCount < 10) return 'medium';
    return 'high';
  }

  int get sessionDuration =>
      DateTime.now().difference(_chatStartTime).inSeconds;

  getMessages() {
    return Column(
      children: messageCards,
    );
  }

  addMessage(text, isMe) {
    if (!mounted) return;
    setState(() {
      messageCards.add(
        MessageBubble(
          message: text,
          isMe: isMe,
          onShare: !isMe && !widget.userData.email!.contains('.')
              ? () {
                  context.push(Routes.postChat, extra: {
                    'name': widget.userData.name!,
                    'profileImageURL': widget.userData.profilePictureURL!,
                    'chat': text,
                    'avatarID': widget.userData.email!,
                  });
                }
              : null,
        ),
      );

      chatHistory.add({text, isMe ? "user" : "ai"});

      // Track message types
      if (isMe) {
        _userMessageCount++;
        AIChatSessionTracker.incrementMessageCount(
            _characterId, 'user_message');
        _interactionTypes.add('user_message');
      } else {
        _aiResponseCount++;
        AIChatSessionTracker.incrementMessageCount(_characterId, 'ai_response');
        _interactionTypes.add('ai_response');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: ChatAppBar(
        title: widget.userData.name ?? "  ",
        subtitle: !widget.userData.isHuman ? "This is not a real person" : "",
        avatarId: widget.userData.name ?? "  ",
        avatarUrl: widget.userData.profilePictureURL,
        onBack: () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  child: SingleChildScrollView(
                    controller: _mainScrollController,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // const Text(
                        //   "Remember: This is not a real person",
                        //   style: TextStyle(color: Colors.blue),
                        // ),
                        // const SizedBox(height: 20),
                        // widget.userData.profilePictureURL == null
                        //     ? const Icon(Icons.account_circle, size: 200)
                        //     : Padding(
                        //         padding:
                        //             const EdgeInsets.only(right: 5.0, left: 5),
                        //         child: ClipRRect(
                        //           borderRadius: BorderRadius.circular(200.0),
                        //           child: CachedNetworkImage(
                        //               imageUrl:
                        //                   widget.userData.profilePictureURL!,
                        //               fit: BoxFit.fitWidth,
                        //               width: MediaQuery.of(context).size.width -
                        //                   60),
                        //         ),
                        //       ),
                        const SizedBox(height: 20),
                        getMessages()
                      ],
                    ),
                  ),
                ),
              ),
              ChatInput(
                receiverAvatarUrl: widget.userData.profilePictureURL ?? "",
                receiverAvatarId: widget.userData.email ??
                    "", // AI character ID is stored in email field
                controller: msg,
                scrollController: _scrollController,
                onSend: () async {
                  if (_isSending || msg.text.trim().isEmpty) return;

                  setState(() {
                    _isSending = true;
                  });

                  scrollToEnd();
                  String userMessage = msg.text;

                  // Track user message analytics
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId != null) {
                    AppsFlyerService().logEvent('ai_character_message_sent', {
                      'character_id': _characterId,
                      'character_name': widget.userData.name ?? 'Unknown',
                      'user_id': userId,
                      'message_length': userMessage.length,
                      'session_duration_so_far': sessionDuration,
                      'message_number': _userMessageCount + 1,
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    });
                  }

                  scrollToEnd();
                  addMessage(userMessage, true);
                  msg.clear();
                  scrollToEnd();

                  String? aiResponse;
                  final responseStartTime = DateTime.now();

                  if (widget.userData.chatId != null) {
                    if (kDebugMode) {
                      print("Chat id found.");
                    }
                    if (kDebugMode) {
                      print(widget.userData.email);
                    }
                    aiResponse = await InZoneDatabase.sendMessageToAI(
                        userMessage,
                        widget.userData.email!,
                        widget.userData.chatId,
                        chatHistory);
                  } else {
                    if (kDebugMode) {
                      print("Chat id not found.");
                    }

                    aiResponse = await InZoneDatabase.sendMessageToAI(
                        userMessage, widget.userData.email!, null, chatHistory);
                  }

                  if (aiResponse != null) {
                    addMessage(aiResponse, false);

                    // Track AI response analytics
                    final responseTime = DateTime.now()
                        .difference(responseStartTime)
                        .inMilliseconds;
                    if (userId != null) {
                      AppsFlyerService()
                          .logEvent('ai_character_response_received', {
                        'character_id': _characterId,
                        'character_name': widget.userData.name ?? 'Unknown',
                        'user_id': userId,
                        'response_length': aiResponse.length,
                        'response_time_ms': responseTime,
                        'session_duration_so_far': sessionDuration,
                        'conversation_turn': _aiResponseCount + 1,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      });
                    }
                  } else {
                    // Handle failed message
                    addMessage(
                        "Failed to get a response. Please try again.", false);
                  }

                  setState(() {
                    _isSending = false;
                  });

                  scrollToEnd();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
