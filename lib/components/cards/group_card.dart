import 'package:flutter/material.dart';
import 'dart:math';
import 'package:random_avatar/random_avatar.dart';
import 'package:image_stack/image_stack.dart';

import 'package:inzone/data/group_data.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';
import 'package:bounce/bounce.dart';

class GroupCard extends StatelessWidget {
  final GroupData group;

  const GroupCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    // 아바타 이미지 리스트 생성
    final List<String> avatarImages = [];

    // 아바타가 있으면 사용, 없으면 기본 아바타 생성
    if (group.avatars.isNotEmpty) {
      for (var avatar in group.avatars) {
        // 아바타 이미지 URL 추가
        avatarImages.add(avatar);
      }
    } else {
      // 기본 아바타 추가
      avatarImages.addAll([
        'person1',
        'person2',
        'person3',
      ]);
    }

    return Bounce(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GroupChatScreen(group: group),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            highlightColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.05),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 60,
                      child: Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 80,
                      child: Text(
                        group.description,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 24,
                      child: Row(
                        children: [
                          Icon(Icons.group,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${(group.memberCount / 1000).toStringAsFixed(1)}k',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chat_bubble_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${group.messageCount}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: ImageStack.widgets(
                        totalCount: avatarImages.length,
                        widgetCount: 3,
                        widgetRadius: 38,
                        widgetBorderWidth: 1,
                        widgetBorderColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        extraCountBorderColor: Colors.transparent,
                        extraCountTextStyle:
                            Theme.of(context).textTheme.bodyMedium ??
                                const TextStyle(),
                        children: List.generate(
                          min(3, avatarImages.length),
                          (index) => RandomAvatar(
                            avatarImages[index],
                            height: 40,
                            width: 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/*
 // Avatar stack
                  SizedBox(
                    height: 40,
                    width: 120,
                    child: Stack(
                      children: List.generate(
                        4,
                        (index) => Positioned(
                          left: index * 28.0,
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
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
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
*/