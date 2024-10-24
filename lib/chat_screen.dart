import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inzone/all_chats_screen.dart';
import 'package:inzone/config/custom_icons.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/inzone_database.dart';
import 'package:inzone/post_chat_screen.dart';
import 'package:random_avatar/random_avatar.dart';

class ChatScreen extends StatefulWidget {
  ChatUser userData;

  ChatScreen({super.key, required this.userData});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController msg = TextEditingController();
  ScrollController _scrollController =
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
            color: Colors.black,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(widget.userData.name!,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
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
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          style: BorderStyle.solid,
                          width: 10.0,
                        ),
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(30),
                            topLeft: Radius.circular(30)),
                      ),
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
                            RandomAvatar(widget.userData.name!,
                                width: 200, height: 200),
                            const SizedBox(height: 20),
                            Text(
                              "${widget.userData.name} was authored by @${widget.userData.email}",
                              style: const TextStyle(color: Colors.blue),
                            ),
                            getMessages()
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Place the chatInput at the bottom
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  color: Colors.white,
                  child: chatInput(),
                ),
              ],
            )),
      ),
    );
  }

  Widget chatInput() {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 8, bottom: 20, top: 2),
      child: Row(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: TextFormField(
                  scrollController: _scrollController,
                  cursorColor: Colors.black,
                  controller: msg,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    suffixIconColor: Colors.black,
                    contentPadding:
                        const EdgeInsets.only(top: 10, left: 15, right: 10),
                    border: InputBorder.none,
                    hintText: 'Send a message',
                    filled: true,
                    fillColor: Colors.blue.withOpacity(0.2),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .canvasColor, // Set the border color to canvas color
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .canvasColor, // Set the border color to canvas color
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
          ),
          MaterialButton(
            minWidth: 43,
            height: 43,
            color: Colors.blue,
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
                print("Chat id found.");
                aiResponse = await InZoneDatabase.sendMessageToAI(userMessage,
                    widget.userData.email!, widget.userData.chatId);
              } else {
                print("Chat id not found.");
                aiResponse = await InZoneDatabase.sendMessageToAI(
                    userMessage, widget.userData.name!, null);
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
                color: isMe ? Colors.blue : Theme.of(context).canvasColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomRight:
                      isMe ? const Radius.circular(18) : Radius.circular(0),
                  bottomLeft:
                      isMe ? Radius.circular(0) : const Radius.circular(18),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(color: isMe ? Colors.white : Colors.black),
              ),
            ),
          ),
          if (!isMe)
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return PostChatScreen(
                    name: widget.userData.name!,
                    profileImageURL: null,
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
