import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:random_avatar/random_avatar.dart';

import 'package:inzone/data/group_data.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';

class GroupCard extends StatelessWidget {
  final GroupData group;

  const GroupCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: group.isMember
              ? const Color(0xFFEAF7FB)
              : Theme.of(context).canvasColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'icons/nav_bar_icons/groups_selected.png',
                        width: 18,
                        height: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(group.memberCount / 1000).toStringAsFixed(1)}k',
                        style: const TextStyle(
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        'icons/incoin.png',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group.messageCount}',
                        style: const TextStyle(
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                group.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // group.description.contains('—but totally worth it')
              //     ? const Row(
              //         mainAxisSize: MainAxisSize.min,
              //         children: [
              //           Text(
              //             'More',
              //             style: TextStyle(
              //               fontSize: 14,
              //               color: Color(0xFF333333),
              //               decoration: TextDecoration.underline,
              //             ),
              //           ),
              //         ],
              //       )
              //     : const SizedBox(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Avatar stack
                  SizedBox(
                    height: 40,
                    width: 120,
                    child: Stack(
                      children: List.generate(
                        group.avatars.isEmpty ? 4 : group.avatars.length,
                        (index) => Positioned(
                          left: index * 28.0,
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: group.avatars.isEmpty 
                              ? CircleAvatar(
                                  backgroundColor: Colors
                                      .primaries[index % Colors.primaries.length],
                                  child: Icon(
                                    [
                                      Icons.person,
                                      Icons.face,
                                      Icons.face_retouching_natural,
                                      Icons.person_outline
                                    ][index % 4],
                                    color: Colors.white,
                                  ),
                                )
                              : RandomAvatar(group.avatars[index], height: 40, width: 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Join/Open button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GroupChatScreen(group: group),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF14CFEE),
                            Color(0xFF2196F3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Text(
                          group.isMember ? 'Open' : 'Join',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
}
