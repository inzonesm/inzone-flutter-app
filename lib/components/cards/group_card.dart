import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'dart:math';
import 'package:image_stack/image_stack.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/data/group_chat_data.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';
import 'package:bounce/bounce.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GroupCard extends StatefulWidget {
  final GroupData group;

  const GroupCard({super.key, required this.group});

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  // Get random participant profile pictures
  List<String> _getRandomParticipantProfilePictures(
      List<Participant> participants) {
    if (!widget.group.showRandomCharacters || participants.isEmpty) {
      return [];
    }

    // Filter participants that have profile pictures
    List<String> availablePictures = participants
        .where((p) =>
            p.profilePictureUrl != null && p.profilePictureUrl!.isNotEmpty)
        .map((p) => p.profilePictureUrl!)
        .toList();

    // Shuffle and take up to 3
    if (availablePictures.isNotEmpty) {
      availablePictures.shuffle();
      return availablePictures.take(3).toList();
    }

    return [];
  }

  // Build composite group profile picture with 3 AI characters side by side
  Widget _buildCompositeGroupAvatar(List<Participant> participants) {
    final profilePictures = _getRandomParticipantProfilePictures(participants);

    if (profilePictures.isEmpty) {
      // Show fallback icon if no participant pictures available
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(FeatherIcons.users, size: 24),
        ),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: profilePictures.length == 1
            ? _buildSingleCharacterAvatar(profilePictures[0])
            : profilePictures.length == 2
                ? _buildTwoCharacterAvatar(profilePictures)
                : _buildThreeCharacterAvatar(profilePictures),
      ),
    );
  }

  Widget _buildSingleCharacterAvatar(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: 64,
        height: 64,
        color: null, // Remove any color overlay
        colorBlendMode: BlendMode.srcOver, // Use default blend mode
        placeholder: (context, url) => const Center(
          child: Icon(FeatherIcons.image, size: 24),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(FeatherIcons.users, size: 24),
        ),
      ),
    );
  }

  Widget _buildTwoCharacterAvatar(List<String> imageUrls) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Transform.rotate(
              angle: -0.08, // Slight left tilt
              child: CachedNetworkImage(
                imageUrl: imageUrls[0],
                fit: BoxFit.cover,
                height: 64,
                color: null, // Remove any color overlay
                colorBlendMode: BlendMode.srcOver, // Use default blend mode
                placeholder: (context, url) => const Center(
                  child: Icon(FeatherIcons.image, size: 16),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(FeatherIcons.user, size: 16),
                ),
              ),
            ),
          ),
          Container(
            width: 0.5,
            height: 64,
            color: Colors.white,
          ),
          Expanded(
            child: Transform.rotate(
              angle: 0.08, // Slight right tilt
              child: CachedNetworkImage(
                imageUrl: imageUrls[1],
                fit: BoxFit.cover,
                height: 64,
                color: null, // Remove any color overlay
                colorBlendMode: BlendMode.srcOver, // Use default blend mode
                placeholder: (context, url) => const Center(
                  child: Icon(FeatherIcons.image, size: 16),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(FeatherIcons.user, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeCharacterAvatar(List<String> imageUrls) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Transform.rotate(
              angle: -0.12, // Left tilt
              child: CachedNetworkImage(
                imageUrl: imageUrls[0],
                fit: BoxFit.cover,
                height: 64,
                color: null, // Remove any color overlay
                colorBlendMode: BlendMode.srcOver, // Use default blend mode
                placeholder: (context, url) => const Center(
                  child: Icon(FeatherIcons.image, size: 12),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(FeatherIcons.user, size: 12),
                ),
              ),
            ),
          ),
          Container(
            width: 0.5,
            height: 64,
            color: Colors.white,
          ),
          Expanded(
            child: CachedNetworkImage(
              imageUrl: imageUrls[1],
              fit: BoxFit.cover,
              height: 64,
              color: null, // Remove any color overlay
              colorBlendMode: BlendMode.srcOver, // Use default blend mode
              placeholder: (context, url) => const Center(
                child: Icon(FeatherIcons.image, size: 12),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(FeatherIcons.user, size: 12),
              ),
            ),
          ),
          Container(
            width: 0.5,
            height: 64,
            color: Colors.white,
          ),
          Expanded(
            child: Transform.rotate(
              angle: 0.12, // Right tilt
              child: CachedNetworkImage(
                imageUrl: imageUrls[2],
                fit: BoxFit.cover,
                height: 64,
                color: null, // Remove any color overlay
                colorBlendMode: BlendMode.srcOver, // Use default blend mode
                placeholder: (context, url) => const Center(
                  child: Icon(FeatherIcons.image, size: 12),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(FeatherIcons.user, size: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                context.push(Routes.groupChat, extra: widget.group);
              } catch (e) {}
            },
            borderRadius: BorderRadius.circular(24),
            splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            highlightColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.05),
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('groupChats')
                  .doc(widget.group.id)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: Platform.isAndroid ? 150 : 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  return Container(
                    height: Platform.isAndroid ? 150 : 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child:
                        const Center(child: Icon(FeatherIcons.alertTriangle)),
                  );
                }

                final groupChatData =
                    GroupChatData.fromSnapshot(snapshot.data!);

                return Container(
                  height: Platform.isAndroid ? 150 : 130,
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
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title section - always fully visible
                        SizedBox(height: Platform.isAndroid ? 18 : 12),
                        Row(
                          children: [
                            // Avatar section - either composite or single image
                            widget.group.showRandomCharacters
                                ? _buildCompositeGroupAvatar(
                                    groupChatData.participants)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      groupChatData.imageUrl,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      color: null, // Remove any color overlay
                                      colorBlendMode: BlendMode
                                          .srcOver, // Use default blend mode
                                      loadingBuilder:
                                          (context, child, progress) {
                                        return progress == null
                                            ? child
                                            : Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Center(
                                                  child:
                                                      Icon(FeatherIcons.image),
                                                ),
                                              );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                              FeatherIcons.alertTriangle),
                                        );
                                      },
                                    ),
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.group.name,
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
                                    widget.group.description,
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
                              _buildParticipantAvatars(
                                  context, groupChatData.participants),
                              const Spacer(),
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 4, right: 4),
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
                                _formatMemberCount(widget.group.memberCount),
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
                                '${widget.group.messageCount}',
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
                                '${groupChatData.entryFee}',
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Build participant avatars with actual AI profile pictures
  Widget _buildParticipantAvatars(
      BuildContext context, List<Participant> participants) {
    if (widget.group.avatars.isEmpty) {
      return const SizedBox.shrink();
    }

    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    // Generate a list of avatar URLs
    final avatarUrls = participants
        .map((p) => p.profilePictureUrl)
        .where((url) => url != null)
        .cast<String>()
        .toList();

    // Ensure we have at least some avatars to show
    if (avatarUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use ImageStack with actual profile pictures
    return ImageStack(
      key: ValueKey('avatars_loaded_${widget.group.id}'),
      imageList: avatarUrls,
      totalCount: participants.length,
      imageCount: 3,
      imageRadius: 25,
      imageBorderWidth: 1,
      imageBorderColor: Colors.white,
      backgroundColor: Colors.transparent,
      extraCountBorderColor: Colors.transparent,
      extraCountTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleMedium?.color,
      ),
    );
  }
}
