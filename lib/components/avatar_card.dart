import 'dart:math';

import 'package:flutter/material.dart';
import 'package:inzone/all_chats_screen.dart';
import 'package:inzone/chat_screen.dart';
  import 'package:inzone/data/inzone_avatar.dart';

class AvatarCard extends StatefulWidget {
  InZoneAvatar avatar;
  final Function(String)? onTap;

  AvatarCard({super.key, required this.avatar, this.onTap});

  @override
  State<AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends State<AvatarCard> {
  bool isUpvoted = false; // State for tracking upvote
  bool isDownvoted = false; // State for tracking downvote
  int voteCount = 23; // Initial vote count (change this as per your actual data)
int comments = 23;
  @override
  void initState() {
    super.initState();
    voteCount = getRandomNumber(0, 999);
    comments = getRandomNumber(0, 300);
  }

  int getRandomNumber(int min, int max) {
    final random = Random();
    return min + random.nextInt(max - min + 1);
  }

  void handleUpvote() {
    setState(() {
      if (isUpvoted) {
        // If already upvoted, clicking again will undo the upvote
        voteCount--;
        isUpvoted = false;
      } else {
        // If not upvoted, upvote it
        if (isDownvoted) {
          // Remove downvote if it was previously downvoted
          voteCount++;
          isDownvoted = false;
        }
        voteCount++;
        isUpvoted = true;
      }
    });
  }

  void handleDownvote() {
    setState(() {
      if (isDownvoted) {
        voteCount++;
        isDownvoted = false;
      } else {
        if (isUpvoted) {
          voteCount--;
          isUpvoted = false;
        }
        voteCount--;
        isDownvoted = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: GestureDetector(
        onTap: () {
          // Handle single tap if needed
        },
        onDoubleTap: () {
          // Handle double tap if needed
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Container(
            height: 450,
            width: 250,
            padding: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff959595).withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 4), // Changes the position of shadow
                ),
              ],
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      widget.avatar.profilePicture,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.avatar.name,
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 13.0),
                          child: Text.rich(
                            TextSpan(
                              text: widget.avatar.bio.substring(
                                  0, widget.avatar.bio.length), // Part of the description
                              children: const [
                                TextSpan(
                                  text: '... ', // Ellipsis with a space
                                ),
                                TextSpan(
                                  text: 'more', // Text after the ellipsis
                                  style: TextStyle(
                                    color: Colors.blue, // Optional: styling the "Read more" part
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: handleUpvote,
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: isUpvoted ? Colors.green : Colors.black,
                              ),
                            ),
                            Text(
                              '$voteCount',
                              style: TextStyle(
                                color: isUpvoted
                                    ? Colors.green
                                    : isDownvoted
                                    ? Colors.red
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: handleDownvote,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: isDownvoted ? Colors.red : Colors.black,
                              ),
                            ),
                            const Align(
                              alignment: Alignment.bottomCenter,
                              child: Icon(
                                Icons.chat_bubble_rounded,
                                size: 16,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topCenter,
                              child:  Text(
                                comments.toString(),
                              ),
                            ),
                       const SizedBox(width: 8,),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (context) {
                                      return ChatScreen(userData: ChatUser(
                                          name: widget.avatar.name,
                                          email: widget.avatar.id,
                                          chatId: null
                                      ));
                                    }));
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16), // Adjust the value to make it less round
                                ),
                              ),
                              child: const Text("Chat"),
                            )

                          ],
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            "@${widget.avatar.username}",
                            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: Colors.grey,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
