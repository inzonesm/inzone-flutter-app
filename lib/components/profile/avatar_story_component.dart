import 'dart:math';

import 'package:flutter/material.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
import 'package:inzone/data/inzone_avatar.dart';

class AvatarStoryComponent extends StatefulWidget {
  InZoneAvatar avatar;
  final Function(String)? onTap;

  AvatarStoryComponent({super.key, required this.avatar, this.onTap});

  @override
  State<AvatarStoryComponent> createState() => _AvatarCardState();
}

class _AvatarCardState extends State<AvatarStoryComponent> {
  bool isUpvoted = false;
  bool isDownvoted = false;
  int voteCount = 23;
  int comments = 23;
  bool hasUnseenStory = true; // Track if story is seen
  late List<Color> gradientColors;
  
  @override
  void initState() {
    super.initState();
    voteCount = getRandomNumber(0, 999);
    comments = getRandomNumber(0, 300);
    // Randomize if has unseen story
    hasUnseenStory = Random().nextBool();
    // Generate unique colors based on avatar ID or name
    gradientColors = _generateUniqueGradient();
  }

  int getRandomNumber(int min, int max) {
    final random = Random();
    return min + random.nextInt(max - min + 1);
  }

  List<Color> _generateUniqueGradient() {
    // Generate a seed from the avatar's ID or name
    final seed = widget.avatar.id.hashCode + widget.avatar.name.hashCode;
    final random = Random(seed);
    
    // Predefined set of vibrant colors that work well in gradients
    final List<List<Color>> gradientOptions = [
      [const Color(0xFF14CFEE), const Color(0xFF2196F3)], // Blue cyan
      [const Color(0xFFFF9800), const Color(0xFFFF5722)], // Orange to deep orange
      [const Color(0xFF9C27B0), const Color(0xFFE91E63)], // Purple to pink
      [const Color(0xFF4CAF50), const Color(0xFF8BC34A)], // Green to light green
      [const Color(0xFFFF4081), const Color(0xFFD500F9)], // Pink to purple
      [const Color(0xFFFFC107), const Color(0xFF9C27B0)], // Amber to purple
      [const Color(0xFF00BCD4), const Color(0xFF3F51B5)], // Cyan to indigo
      [const Color(0xFF9C27B0), const Color(0xFF2196F3)], // Purple to blue
      [const Color(0xFFFF5722), const Color(0xFFFFEB3B)], // Deep orange to yellow
      [const Color(0xFF3F51B5), const Color(0xFF4CAF50)], // Indigo to green
    ];
    
    // Pick a random gradient from the options
    return gradientOptions[random.nextInt(gradientOptions.length)];
  }

  void navigateToChat() {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return ChatScreen(
        userData: ChatUser(
          name: widget.avatar.name,
          email: widget.avatar.id,
          chatId: null,
          profilePictureURL: widget.avatar.profilePicture
        )
      );
    }));
    // Mark story as seen when clicked
    if (hasUnseenStory) {
      setState(() {
        hasUnseenStory = false;
      });
    }
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
    return GestureDetector(
      onTap: navigateToChat,
      child: Container(
        width: 78,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            // Story circle with gradient border
            Container(
              width: 80,
              height: 80,
                   decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                border: null,
              ),
              // decoration: BoxDecoration(
              //   shape: BoxShape.circle,
              //   gradient: hasUnseenStory 
              //     ? LinearGradient(
              //         colors: gradientColors,
              //         begin: Alignment.topLeft,
              //         end: Alignment.bottomRight,
              //       )
              //     : null,
              //   border: !hasUnseenStory 
              //     ? Border.all(color: Colors.grey, width: 2) 
              //     : null,
              // ),
              child: Padding(
                padding: const EdgeInsets.all(2.0), // Border thickness
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0), // White padding
                    child: ClipOval(
                      child: Image.network(
                        widget.avatar.profilePicture,
                        fit: BoxFit.cover,
                        width: 78,
                        height: 78,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: Text(
                                widget.avatar.name.isNotEmpty
                                    ? widget.avatar.name.substring(0, 1).toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Username with ellipsis
            Text(
              widget.avatar.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
