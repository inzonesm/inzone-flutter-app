import 'dart:math';

import 'package:flutter/material.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
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
  int voteCount = 23;
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
            height: 550,
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
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    child: Image.network(
                      widget.avatar.profilePicture,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Text(
                              widget.avatar.name.isNotEmpty
                                  ? widget.avatar.name
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.avatar.name,
                          style:
                              Theme.of(context).textTheme.titleMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Text(
                        //   "@${widget.avatar.username}",
                        //   style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        //     color: Colors.grey[700],
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        //   maxLines: 1,
                        //   overflow: TextOverflow.ellipsis,
                        // ),
                        const SizedBox(height: 10),
                        if (widget.avatar.greeting != null &&
                            widget.avatar.greeting!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '"${widget.avatar.greeting!}"',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                widget.avatar.bio,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: handleUpvote,
                                  child: Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    color:
                                        isUpvoted ? Colors.green : Colors.black,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 2),
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
                                const SizedBox(width: 2),
                                GestureDetector(
                                  onTap: handleDownvote,
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color:
                                        isDownvoted ? Colors.red : Colors.black,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  comments.toString(),
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () {
                                print(widget.avatar.profilePicture);
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (context) {
                                  return ChatScreen(
                                      userData: ChatUser(
                                          name: widget.avatar.name,
                                          email: widget.avatar.id,
                                          chatId: null,
                                          profilePictureURL:
                                              widget.avatar.profilePicture));
                                }));
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                              child: const Text(
                                "Chat",
                                style: TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
