import 'package:flutter/material.dart';
import 'dart:math';
import 'package:image_stack/image_stack.dart';
import 'package:go_router/go_router.dart';

import 'package:inzone/data/group_data.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';
import 'package:bounce/bounce.dart';
import 'package:inzone/router/routes.dart';

class GroupCard extends StatelessWidget {
  final GroupData group;

  const GroupCard({super.key, required this.group});

  // Helper method to format member count dynamically
  String _formatMemberCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    } else {
      return count.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create avatar image list
    final List<String> avatarImages = [];

    // Use avatars if they exist, otherwise use default avatars
    if (group.avatars.isNotEmpty) {
      for (var avatar in group.avatars) {
        // Add avatar image URL
        avatarImages.add(avatar);
      }
    } else {
      // Add default avatars
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

              try {
                // Try using Go Router first
                context.push(Routes.groupChat, extra: group);
              } catch (e) {}
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
                    // Title section - always fully visible
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Description section with flexible height
                    Expanded(
                      flex: 2,
                      child: Text(
                        group.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.2,
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Stats row
                    Row(
                      children: [
                        Icon(Icons.group,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                                                  Text(
                            _formatMemberCount(group.memberCount),
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: _buildParticipantAvatars(),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build participant avatars with static blue AI profile pictures
  Widget _buildParticipantAvatars() {
    if (group.avatars.isEmpty) {
      return const SizedBox.shrink();
    }

    return ImageStack.widgets(
      key: ValueKey('avatars_${group.id}'),
      totalCount: group.avatars.length, // This preserves the +1, +2, etc. functionality
      widgetCount: 3,
      widgetRadius: 38,
      widgetBorderWidth: 1,
      widgetBorderColor: Colors.white,
      backgroundColor: Colors.transparent,
      extraCountBorderColor: Colors.transparent,
      extraCountTextStyle: const TextStyle(),
      children: List.generate(
        min(3, group.avatars.length),
        (index) => Container(
          key: ValueKey('static_avatar_${group.id}_$index'),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade100,
          ),
          child: const Icon(
            Icons.smart_toy,
            color: Colors.blueAccent,
            size: 24,
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
