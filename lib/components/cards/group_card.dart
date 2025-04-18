import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:random_avatar/random_avatar.dart';
import 'package:image_stack/image_stack.dart';

import 'package:inzone/data/group_data.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';

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

    return Padding(
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
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 그룹 타이틀 - 항상 표시, 최대 2줄
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.titleLarge?.color,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.isMember)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 그룹 설명 - 1줄로 제한
                    Text(
                      group.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),

                    // 하단 섹션 - 통계 및 아바타
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.group,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(group.memberCount / 1000).toStringAsFixed(1)}k',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color:
                                Theme.of(context).textTheme.titleMedium?.color,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.messageCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color:
                                Theme.of(context).textTheme.titleMedium?.color,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // avatar
                    ImageStack.widgets(
                      totalCount: avatarImages.length,
                      widgetCount: 3,
                      widgetRadius: 40,
                      widgetBorderWidth: 1,
                      widgetBorderColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      extraCountBorderColor: Colors.transparent,
                      extraCountTextStyle:
                          Theme.of(context).textTheme.bodyMedium ??
                              const TextStyle(),
                      children: List.generate(
                        min(3, avatarImages.isEmpty ? 3 : avatarImages.length),
                        (index) {
                          if (avatarImages.isEmpty) {
                            return CircleAvatar(
                              backgroundColor: Colors
                                  .primaries[index % Colors.primaries.length],
                              child: Icon(
                                [
                                  Icons.person,
                                  Icons.face,
                                  Icons.face_retouching_natural
                                ][index % 3],
                                color: Colors.white,
                                size: 18,
                              ),
                            );
                          } else {
                            return RandomAvatar(
                              avatarImages[index],
                              height: 40,
                              width: 40,
                            );
                          }
                        },
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