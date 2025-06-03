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
  void dispose() {
    _mainScrollController.dispose();
    msg.dispose();
    _scrollController
        .dispose(); // Dispose the controller when the widget is destroyed
    super.dispose();
  }

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: ChatAppBar(
        title: widget.userData.name ?? "  ",
        avatarId: widget.userData.name ?? "  ",
        avatarUrl: widget.userData.profilePictureURL,
        onBack: () {
          if (mounted) context.pop();
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
                        const Text(
                          "Remember: This is not a real person",
                          style: TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(height: 20),
                        widget.userData.profilePictureURL == null
                            ? const Icon(Icons.account_circle, size: 200)
                            : Padding(
                                padding:
                                    const EdgeInsets.only(right: 5.0, left: 5),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(200.0),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        widget.userData.profilePictureURL!,
                                    fit: BoxFit.fitWidth,
                                    width:
                                        MediaQuery.of(context).size.width - 60,
                                    placeholder: (context, url) =>
                                        const SizedBox(),
                                    errorWidget: (context, url, error) {
                                      return const Icon(Icons.account_circle,
                                          size: 200);
                                    },
                                  ),
                                ),
                              ),
                        const SizedBox(height: 20),
                        getMessages()
                      ],
                    ),
                  ),
                ),
              ),
              ChatInput(
                controller: msg,
                scrollController: _scrollController,
                onSend: () async {
                  scrollToEnd();
                  String userMessage = msg.text;

                  scrollToEnd();
                  addMessage(userMessage, true);
                  msg.clear();
                  scrollToEnd();
                  String? aiResponse;
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
                  }

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
