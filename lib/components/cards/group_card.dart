import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'dart:math';
import 'package:image_stack/image_stack.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:inzone/data/group_data.dart';
import 'package:inzone/data/group_chat_data.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
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
              height: 128,
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
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title section - always fully visible
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Avatar stack
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                      fontSize: 16,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      height: 1.2,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Row(
                        children: [
                          _buildParticipantAvatars(),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, right: 4),
                            child: Icon(
                              FeatherIcons.users,
                              size: 12,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          Text(
                            _formatMemberCount(group.memberCount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: 2, left: 8, right: 4),
                            child: Icon(
                              FeatherIcons.messageSquare,
                              size: 12,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          Text(
                            '${group.messageCount}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: 2, left: 8, right: 4),
                            child: Image.asset(
                              'assets/icons/incoin.png',
                              width: 12,
                              height: 12,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          Text(
                            '100',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
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

  // Build participant avatars with actual AI profile pictures
  Widget _buildParticipantAvatars() {
    if (group.avatars.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('groupChats')
          .doc(group.id)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading state with static icons
          return ImageStack.widgets(
            key: ValueKey('avatars_loading_${group.id}'),
            totalCount: group.avatars.length,
            widgetCount: 3,
            widgetRadius: 25,
            widgetBorderWidth: 1,
            widgetBorderColor: Colors.white,
            backgroundColor: Colors.transparent,
            extraCountBorderColor: Colors.transparent,
            extraCountTextStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleMedium?.color,
              height: 0.9,
            ),
            children: List.generate(
              min(3, group.avatars.length),
              (index) => Container(
                key: ValueKey('loading_avatar_${group.id}_$index'),
                width: 25,
                height: 25,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.transparent,
                  size: 20,
                ),
              ),
            ),
          );
        }

        List<Participant> participants = [];
        if (snapshot.hasData && snapshot.data!.exists) {
          try {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final List<dynamic> participantsData = data['participants'] ?? [];
            participants = participantsData
                .map((participant) =>
                    Participant.fromMap(participant.cast<String, dynamic>()))
                .where((p) => p.type == 'ai') // Only show AI participants
                .toList();
          } catch (e) {
            print('Error parsing participants in group card: $e');
          }
        }

        // If no participants found, show static icons
        if (participants.isEmpty) {
          return ImageStack.widgets(
            key: ValueKey('avatars_static_${group.id}'),
            totalCount: group.avatars.length,
            widgetCount: 3,
            widgetRadius: 25,
            widgetBorderWidth: 1,
            widgetBorderColor: Colors.white,
            backgroundColor: Colors.transparent,
            extraCountBorderColor: Colors.transparent,
            extraCountTextStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleMedium?.color,
              height: 0.9,
            ),
            children: List.generate(
              min(3, group.avatars.length),
              (index) => Container(
                key: ValueKey('static_avatar_${group.id}_$index'),
                width: 25,
                height: 25,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.transparent,
                  size: 20,
                ),
              ),
            ),
          );
        }

        return ImageStack.widgets(
          key: ValueKey('avatars_${group.id}'),
          totalCount: participants.length,
          widgetCount: 3,
          widgetRadius: 25,
          widgetBorderWidth: 1,
          widgetBorderColor: Colors.white,
          backgroundColor: Colors.transparent,
          extraCountBorderColor: Colors.transparent,
          extraCountTextStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleMedium?.color,
            height: 0.9,
          ),
          children: List.generate(
            min(3, participants.length),
            (index) => _buildParticipantAvatar(participants[index], index),
          ),
        );
      },
    );
  }

  Widget _buildParticipantAvatar(Participant participant, int index) {
    // If participant has profile picture URL, use it
    if (participant.profilePictureUrl != null &&
        participant.profilePictureUrl!.isNotEmpty) {
      return Container(
        key: ValueKey('avatar_${group.id}_${participant.uid}'),
        width: 25,
        height: 25,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          participant.profilePictureUrl!,
          fit: BoxFit.cover,
          width: 25,
          height: 25,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to AI icon if image fails to load
            return Container(
              width: 25,
              height: 25,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.transparent,
                size: 20,
              ),
            );
          },
        ),
      );
    }

    // Fallback to AI icon if no profile picture URL
    return Container(
      key: ValueKey('fallback_avatar_${group.id}_$index'),
      width: 25,
      height: 25,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: Colors.transparent),
      child: const Icon(
        Icons.smart_toy,
        color: Colors.transparent,
        size: 20,
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
