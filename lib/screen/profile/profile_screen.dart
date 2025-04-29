import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/profile/base_profile_screen.dart';
import 'package:inzone/components/profile/user_posts_tab.dart';
import 'package:inzone/components/profile/followers_following_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
import 'package:inzone/screen/chat/human_chat_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart'; // For ChatUser class

import 'package:inzone/services/inzone_database.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends BaseProfileScreen {
  final String uid;
  final bool isAI;

  const ProfileScreen({super.key, required this.uid, this.isAI = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends BaseProfileScreenState<ProfileScreen> {
  bool isFollowing = false;

  @override
  Future<void> fetchUserProfile() async {
    await super.fetchUserProfile();

    // Additional profile data specific to viewing another user's profile
    String userId = getUserId();
    if (userId.isEmpty) return;

    Map<String, dynamic>? userProfile;

    // Use different API endpoints based on whether the user is an AI user or not
    if (widget.isAI) {
      // For AI users, use the AI user profile endpoint
      userProfile = await InZoneDatabase.getAIUserProfile(userId);
      // If API fails, try to get profile from Firestore
      if (userProfile == null) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('aiUsers')
              .doc(userId)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            userProfile = userDoc.data() as Map<String, dynamic>;
          } else {}
        } catch (e) {}
      } else {}
    } else {
      // For human users, use the regular user profile endpoint
      userProfile = await InZoneDatabase.getUserProfile(userId);

      // If API fails, try to get profile from Firestore
      if (userProfile == null) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('humanUsers')
              .doc(userId)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            userProfile = userDoc.data() as Map<String, dynamic>;
          } else {}
        } catch (e) {}
      }
    }

    if (userProfile != null) {
      // Process followers and following data for the community tab
      List<dynamic> followers = userProfile["followers"] ?? [];
      List<dynamic> following = userProfile["following"] ?? [];

      // Convert to the expected format for FollowersFollowingTab
      List<Map<String, dynamic>> formattedFollowers = [];
      List<Map<String, dynamic>> formattedFollowing = [];

      // Process followers
      for (var follower in followers) {
        if (follower is Map<String, dynamic>) {
          // Ensure we only use the standard keys
          Map<String, dynamic> formattedFollower = {
            'id': follower['id'] ?? '',
            'username': follower['username'] ?? '',
            'type': follower['type'] ?? 'human'
          };
          formattedFollowers.add(formattedFollower);
        } else if (follower is String) {
          // Legacy format - just an ID, try to get the user's profile
          try {
            Map<String, dynamic>? followerProfile =
                await InZoneDatabase.getUserProfile(follower);
            if (followerProfile != null) {
              formattedFollowers.add({
                'id': follower,
                'username': followerProfile['username'] ?? '',
                'type': 'human'
              });
            }
          } catch (e) {}
        }
      }

      // Process following
      for (var follow in following) {
        if (follow is Map<String, dynamic>) {
          // Ensure we only use the standard keys
          Map<String, dynamic> formattedFollow = {
            'id': follow['id'] ?? '',
            'username': follow['username'] ?? '',
            'type': follow['type'] ?? 'human'
          };
          formattedFollowing.add(formattedFollow);
        } else if (follow is String) {
          // Legacy format - just an ID, try to get the user's profile
          try {
            Map<String, dynamic>? followProfile =
                await InZoneDatabase.getUserProfile(follow);
            if (followProfile != null) {
              formattedFollowing.add({
                'id': follow,
                'username': followProfile['username'] ?? '',
                'type': 'human'
              });
            }
          } catch (e) {}
        }
      }

      setState(() {
        // Access the fields directly from the user data object
        name = userProfile!["Name"] ?? userProfile["name"] ?? "Unknown";
        bio = userProfile["Bio"] ?? userProfile["bio"] ?? "";

        // Get followers and following counts from the profile data if available
        followersCount = userProfile["followers_count"] ?? followers.length;
        followingCount = userProfile["following_count"] ?? following.length;

        // Update the community tab data
        _communityTabData = {
          "followers": formattedFollowers,
          "following": formattedFollowing
        };
      });
    } else {
      // Set default values if profile couldn't be fetched
      setState(() {
        name = "User";
        bio = "";
        followersCount = 0;
        followingCount = 0;
      });

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load user profile')));
    }

    // Check follow status for both human and AI users
    await checkFollowStatus();
  }

  // Store the community tab data
  Map<String, List<Map<String, dynamic>>> _communityTabData = {
    "followers": [],
    "following": []
  };

  @override
  List<Widget> getTabViews() {
    return [
      // Posts tab
      UserPostsTab(userId: getUserId(), ai: widget.isAI),

      // Community tab - Use the processed data
      FollowersFollowingTab(
        userList: _communityTabData,
        userId: getUserId(),
      ),
    ];
  }

  Future<void> checkFollowStatus() async {
    String userId = getUserId();
    if (userId.isEmpty) return;

    try {
      String? currentUserId = await InZoneDatabase.getCurrentUserUid();
      if (currentUserId != null && currentUserId != userId) {
        // Get the current user's profile to check who they're following
        Map<String, dynamic>? currentUserProfile =
            await InZoneDatabase.getCurrentUserProfile();

        if (currentUserProfile != null &&
            currentUserProfile.containsKey('following')) {
          List<dynamic> currentUserFollowing =
              currentUserProfile['following'] ?? [];

          setState(() {
            // Check if the profile we're viewing is in the current user's following list
            isFollowing = false;

            for (var followedUser in currentUserFollowing) {
              if (followedUser is Map<String, dynamic>) {
                if (followedUser['id'] == userId) {
                  isFollowing = true;
                  break;
                }
              } else if (followedUser is String && followedUser == userId) {
                isFollowing = true;
                break;
              }
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        isFollowing = false;
      });
    }
  }

  void toggleFollow() async {
    String userId = getUserId();
    if (userId.isEmpty) return;

    bool currentFollowState = isFollowing;
    bool newFollowState = !currentFollowState;

    setState(() {
      // Optimistically update UI
      isFollowing = newFollowState;
      if (newFollowState) {
        followersCount++;
      } else {
        followersCount = followersCount > 0 ? followersCount - 1 : 0;
      }
    });

    try {
      bool success;
      if (widget.isAI) {
        // For AI users
        if (newFollowState) {
          success = await InZoneDatabase.followAIUser(userId);
        } else {
          success = await InZoneDatabase.unfollowAIUser(userId);
        }
      } else {
        // For human users (existing implementation)
        if (newFollowState) {
          await InZoneDatabase.followUser(
              userId, await _getCurrentUserName(userId));
          success = true;
        } else {
          await InZoneDatabase.unfollowUser(userId);
          success = true;
        }
      }

      if (success) {
        // If successful, refresh the profile data to get updated followers/following lists
        String? currentUserId = await InZoneDatabase.getCurrentUserUid();
        if (currentUserId != null) {
          // Get the current user's profile
          Map<String, dynamic>? currentUserProfile =
              await InZoneDatabase.getCurrentUserProfile();

          if (currentUserProfile != null &&
              currentUserProfile.containsKey('following')) {
            // Update the community tab data with the new following list
            List<dynamic> currentUserFollowing =
                currentUserProfile['following'] ?? [];

            // Process the following list
            List<Map<String, dynamic>> formattedFollowing = [];
            for (var followedUser in currentUserFollowing) {
              if (followedUser is Map<String, dynamic>) {
                formattedFollowing.add(followedUser);
              } else if (followedUser is String) {
                formattedFollowing.add(
                    {'id': followedUser, 'username': 'User', 'type': 'human'});
              }
            }

            // Update the following list in the community tab data
            setState(() {
              _communityTabData["following"] = formattedFollowing;
            });
          }
        }
      } else {
        // If the operation failed, revert the UI changes
        setState(() {
          isFollowing = currentFollowState;
          if (currentFollowState) {
            followersCount++;
          } else {
            followersCount = followersCount > 0 ? followersCount - 1 : 0;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Failed to ${newFollowState ? 'follow' : 'unfollow'} user')));
      }
    } catch (e) {
      // If there's an error, revert the UI change
      setState(() {
        isFollowing = currentFollowState;
        if (currentFollowState) {
          followersCount++;
        } else {
          followersCount = followersCount > 0 ? followersCount - 1 : 0;
        }
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Failed to ${newFollowState ? 'follow' : 'unfollow'} user')));
    }
  }

  @override
  Future<void> fetchUserStats([bool isAi = false]) async {
    String userId = getUserId();
    if (userId.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Fetch post count from user posts
    List? posts = [];
    if (isAi) {
      posts = await InZoneDatabase.getAIUserPosts(userId);
    } else {
      posts = await InZoneDatabase.getUserPosts(userId);
    }
    if (posts != null) {
      setState(() {
        postCount = posts!.length;
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  String getUserId() {
    return widget.uid;
  }

  @override
  List<String> getTabLabels() {
    // Both AI and human users show Posts and Community tabs
    return const ['Posts', 'Community'];
  }

  @override
  Widget buildActionButtons() {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Follow/Following Button
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isFollowing
                    ? Colors.transparent
                    : theme.colorScheme.primary, // Follow시 파란색 배경
                border: Border.all(
                  color: isFollowing
                      ? theme.dividerColor
                      : theme.colorScheme.primary,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFollowing ? FeatherIcons.check : FeatherIcons.userPlus,
                    size: 18,
                    color: isFollowing
                        ? theme.textTheme.bodyMedium?.color
                        : theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isFollowing
                          ? theme.textTheme.bodyMedium?.color
                          : theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Message Button
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: GestureDetector(
            onTap: () async {
              String? currentUserId = await InZoneDatabase.getCurrentUserUid();
              if (currentUserId == null) return;

              String targetUserId = getUserId();
              bool isAiUser = widget.isAI;

              if (isAiUser) {
                context.pushNamed('chat',
                    extra: ChatUser(
                      name: name,
                      email: targetUserId,
                      chatId: null,
                    ));
              } else {
                List<String> sortedIds = [currentUserId, targetUserId]..sort();
                String conversationId = "${sortedIds[0]}_${sortedIds[1]}";

                try {
                  final conversationDoc = await FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(conversationId)
                      .get();

                  if (!conversationDoc.exists) {
                    String currentUserName =
                        await _getCurrentUserName(currentUserId);

                    await FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(conversationId)
                        .set({
                      'participants': [currentUserId, targetUserId],
                      'participantNames': {
                        currentUserId: currentUserName,
                        targetUserId: name,
                      },
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastUpdated': FieldValue.serverTimestamp(),
                      'lastMessageTime': FieldValue.serverTimestamp(),
                    });
                  }

                  context.pushNamed('chat', extra: {
                    'conversationId': conversationId,
                    'otherUserName': name,
                    'otherUserId': targetUserId,
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Failed to open conversation. Please try again.'),
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: theme.dividerColor,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FeatherIcons.messageCircle,
                    size: 18,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Message',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to get current user's name
  Future<String> _getCurrentUserName(String userId) async {
    String defaultName = "User";

    try {
      Map<String, dynamic>? userProfile =
          await InZoneDatabase.getUserProfile(userId);
      if (userProfile != null) {
        return userProfile["Name"] ?? userProfile["name"] ?? defaultName;
      }
    } catch (e) {}

    return defaultName;
  }

  @override
  PreferredSizeWidget? buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).canvasColor,
      centerTitle: true,
      title: Text("Profile", style: Theme.of(context).textTheme.titleLarge),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Theme.of(context).primaryColor),
        onPressed: () {
          context.pop();
        },
      ),
      actions: [
        // Only show the popup menu for human users
        if (!widget.isAI)
          IconButton(
            icon: Icon(Icons.more_horiz, color: Theme.of(context).primaryColor),
            onPressed: () => _showOptionsBottomSheet(context),
          ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Theme.of(context).canvasColor,
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(30),
            topLeft: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 15),
            InkWell(
              onTap: () async {
                Navigator.of(context).pop(); // Close the bottom sheet
                String? currentUserId =
                    await InZoneDatabase.getCurrentUserUid();
                if (currentUserId != null) {
                  bool success =
                      await InZoneDatabase.removeFromFollowers(getUserId());
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('User removed from your followers')));
                    // Refresh the profile data
                    fetchUserProfile();
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.person_remove),
                    SizedBox(width: 16),
                    Text(
                      'Remove from followers',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
