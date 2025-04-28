import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/chat/post_chat_screen.dart';
import 'package:inzone/theme/light_theme.dart'; // Import for ChatTheme extension
import 'package:random_avatar/random_avatar.dart';

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
    setState(() {
      messageCards.add(messageCard(text, isMe));

      chatHistory.add({text, isMe?"user":"ai"});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).canvasColor,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
            ),
            color: Theme.of(context).primaryColor,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(widget.userData.name!,
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        ),
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
                            ? RandomAvatar(widget.userData.name!,
                                width: 200, height: 200)
                            : Padding(
                                padding:
                                    const EdgeInsets.only(right: 5.0, left: 5),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(200.0),
                                  child: Image.network(
                                    widget.userData.profilePictureURL!,
                                    fit: BoxFit.fitWidth,
                                    width:
                                        MediaQuery.of(context).size.width - 60,
                                    errorBuilder: (context, object, st) {
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                        const SizedBox(height: 20),
                        // Text(
                        //   textAlign: TextAlign.center,
                        //   "${widget.userData.name} was authored by @${widget.userData.email}",
                        //   style: const TextStyle(color: Colors.blue),
                        // ),
                        getMessages()
                      ],
                    ),
                  ),
                ),
              ),
              chatInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget chatInput() {
    return Container(
      color: Theme.of(context).canvasColor,
      child: Padding(
        padding:
            const EdgeInsets.only(left: 10.0, right: 10, bottom: 30, top: 2),
        child: Row(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: TextFormField(
                    scrollController: _scrollController,
                    cursorColor: Theme.of(context).primaryColor,
                    controller: msg,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      suffixIconColor: Theme.of(context).iconTheme.color,
                      contentPadding:
                          const EdgeInsets.only(top: 10, left: 15, right: 10),
                      border: InputBorder.none,
                      hintText: 'Send a message',
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(30),
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
                  aiResponse = await InZoneDatabase.sendMessageToAI(userMessage,
                      widget.userData.email!, widget.userData.chatId, chatHistory);
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
              child: const Center(
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget messageCard(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end, // Align at the bottom for multiline text
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            // Flexible allows the text to wrap on multiple lines
            child: Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).myChatBubbleColor
                    : Theme.of(context).otherChatBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomRight: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(0),
                  bottomLeft: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(18),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                    color: isMe
                        ? Theme.of(context).myChatTextColor
                        : Theme.of(context).otherChatTextColor),
              ),
            ),
          ),
          if (!isMe && !widget.userData.email!.contains('.'))
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return PostChatScreen(
                    name: widget.userData.name!,
                    profileImageURL: widget.userData.profilePictureURL!,
                    chat: text,
                    avatarID: widget.userData.email!,
                  );
                }));
              },
              child: SizedBox(
                height: 25,
                width: 25,
                child: SvgPicture.asset(
                    CustomIcons.send), // Placeholder for the icon
              ),
            ),
        ],
      ),
    );
  }
}
