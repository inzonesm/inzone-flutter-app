import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/profile/user_posts_tab.dart';
import 'package:inzone/components/profile/followers_following_tab.dart';
import 'package:inzone/components/ui/profile_appbar.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
import 'package:inzone/screen/chat/human_chat_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart'; // For ChatUser class
import 'package:inzone/services/inzone_database.dart';
import 'package:go_router/go_router.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/router/routes.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  final bool isAI;

  const ProfileScreen({super.key, required this.uid, this.isAI = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State variables that were previously in BaseProfileScreenState
  int currentPage = 0;
  String name = "Loading";
  String bio = 'Loading';
  String username = 'Loading';
  String profileImageUrl = "";
  int postCount = 0;
  int followingCount = 0;
  int followersCount = 0;
  bool isLoading = true;
  bool isRefreshing = false;
  List<InZonePost> _posts = [];

  // Saved characters
  List<Map<String, String>> _savedCharacters = [];
  bool _areCharactersLoading = true;

  // Additional state for this specific screen
  bool isFollowing = false;
  bool _isFollowedBy = false;

  // SmartRefresher controller
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();

    if (!widget.isAI) {
      _fetchSavedCharacters();
    } else {
      // AI 프로필의 경우 saved characters를 표시하지 않음
      setState(() {
        _areCharactersLoading = false;
        _savedCharacters = [];
      });
    }

    fetchUserProfile();
    fetchUserPosts(widget.isAI);
    checkFollowStatus();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _fetchSavedCharacters() async {
    // _areCharactersLoading is initialized to true, so the loader will show on first build.
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(widget.uid)
          .get();

      List<Map<String, String>> fetchedCharacters = [];
      if (userDoc.exists &&
          userDoc.data() != null &&
          userDoc.data()!.containsKey('savedCharacters')) {
        final savedCharactersData =
            userDoc.get('savedCharacters') as List<dynamic>;

        fetchedCharacters = savedCharactersData
            .map((charData) {
              final name = charData['name'] as String?;
              final imageUrl = charData['profilePictureUrl'] as String?;
              final characterId = charData['characterId'] as String?;

              if (name != null && imageUrl != null && characterId != null) {
                return {
                  'id': characterId,
                  'name': name,
                  'image': imageUrl,
                };
              }
              return null;
            })
            .whereType<Map<String, String>>()
            .toList();
      }

      if (mounted) {
        setState(() {
          _savedCharacters = fetchedCharacters;
          _areCharactersLoading = false; // Update loading state here
        });
      }
    } catch (e) {
      debugPrint('Error fetching saved characters on profile screen: $e');
      if (mounted) {
        setState(() {
          _areCharactersLoading = false; // Also stop loading on error
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      isRefreshing = true;
    });

    try {
      await fetchUserProfile();
      await fetchUserPosts(widget.isAI);
      if (!widget.isAI) {
        await _fetchSavedCharacters();
      } else {
        // AI 프로필의 경우 saved characters를 표시하지 않음
        setState(() {
          _areCharactersLoading = false;
          _savedCharacters = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  void _onRefresh() async {
    await _handleRefresh();
    _refreshController.refreshCompleted();
  }

  // Methods previously from BaseProfileScreen
  String getUserId() {
    return widget.uid;
  }

  Widget buildActionButtons() {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Message Button
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: GestureDetector(
            onTap: () async {
              String? currentUserId = await InZoneDatabase.getCurrentUserUid();
              if (currentUserId == null) {
                ToastService.showToast(
                  context,
                  backgroundColor: Theme.of(context).canvasColor,
                  shadowColor: Colors.transparent,
                  leading: const Icon(
                    FeatherIcons.xCircle,
                    color: Colors.redAccent,
                  ),
                  message: 'Please log in to send messages',
                );
                return;
              }

              String targetUserId = getUserId();

              try {
                // For AI characters, just navigate to the chat screen directly
                if (widget.isAI) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return ChatScreen(
                      userData: ChatUser(
                        name: name,
                        email: targetUserId,
                        chatId: null,
                        isHuman: false,
                        profilePictureURL: profileImageUrl,
                      ),
                    );
                  }));
                  return;
                }

                // For human users, first check if they might be a human-created AI
                final characterDoc = await FirebaseFirestore.instance
                    .collection('popularCharacters')
                    .doc(targetUserId)
                    .get();

                if (characterDoc.exists &&
                    characterDoc.data()?['createdByHuman'] == true) {
                  // This is a human-created AI character
                  final characterData = characterDoc.data()!;
                  final imageUrl = characterData['profile_picture_url'] ?? '';

                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return ChatScreen(
                      userData: ChatUser(
                        name: name,
                        email: targetUserId,
                        chatId: null,
                        isHuman: false,
                        profilePictureURL: imageUrl,
                      ),
                    );
                  }));
                } else {
                  // This is a regular human user
                  List<String> sortedIds = [currentUserId, targetUserId]
                    ..sort();
                  String conversationId = "${sortedIds[0]}_${sortedIds[1]}";

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

                  context.pushNamed(
                    'human_chat',
                    pathParameters: {'conversationId': conversationId},
                    extra: {
                      'otherUserId': targetUserId,
                      'otherUserName': name,
                      'otherUserProfilePicture': profileImageUrl,
                    },
                  );
                }
              } catch (e) {
                print('Error handling message button tap: $e');
                ToastService.showToast(
                  context,
                  backgroundColor: Theme.of(context).canvasColor,
                  shadowColor: Colors.transparent,
                  leading: const Icon(
                    FeatherIcons.xCircle,
                    color: Colors.redAccent,
                  ),
                  message: 'Failed to open conversation.',
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[300]
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                FeatherIcons.messageCircle,
                size: 18,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ),

        // Follow/Following Button
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: GestureDetector(
            onTap: toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFollowing
                    ? Colors.transparent
                    : theme.colorScheme.primary,
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
      ],
    );
  }

  // Data fetching methods
  Future<void> fetchUserProfile() async {
    String userId = getUserId();
    if (userId.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Get profile data directly from Firebase instead of API
    Map<String, dynamic>? userProfile;

    try {
      if (widget.isAI) {
        // For AI users, get from aiUsers collection
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('aiUsers')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          userProfile = userDoc.data() as Map<String, dynamic>;
        }
      } else {
        // For human users, get from humanUsers collection
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          userProfile = userDoc.data() as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile from Firebase: $e');
    }

    if (userProfile != null) {
      // Debug print for AI users
      if (widget.isAI) {
        debugPrint('AI User Profile Data: $userProfile');
        debugPrint('Profile Picture URL: ${userProfile["profilePicture"]}');
        debugPrint(
            'Profile Picture URL (alt): ${userProfile["profile_picture_url"]}');
      }

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
        name = userProfile!["name"] ?? userProfile["Name"] ?? "Unknown";
        bio = userProfile["bio"] ?? userProfile["Bio"] ?? "";
        username =
            userProfile["username"] ?? userProfile["Username"] ?? "Unknown";
        profileImageUrl = userProfile["profilePicture"] ??
            userProfile["ProfilePicture"] ??
            userProfile["profile_picture_url"] ??
            "";

        // Get followers and following counts - prioritize API count fields, fallback to array length
        followersCount = userProfile["followers_count"] ?? followers.length;
        followingCount = userProfile["following_count"] ?? following.length;
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
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Could not load user profile',
      );
    }
  }

  Future<void> fetchUserPosts([bool isAi = false]) async {
    String userId = getUserId();
    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    // Set loading state at the beginning. This ensures that when refreshing,
    // the UI shows a loading state for the posts tab as well.
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // Fetch post data from the database.
      List? postJsonList = [];
      if (isAi) {
        postJsonList = await InZoneDatabase.getAIUserPosts(userId);
      } else {
        postJsonList = await InZoneDatabase.getUserPosts(userId);
      }

      List<InZonePost> fetchedPosts = [];
      if (postJsonList != null && postJsonList.isNotEmpty) {
        // Convert JSON data to a list of InZonePost objects.
        fetchedPosts =
            postJsonList.map((json) => InZonePost.fromJson(json)).toList();
      }

      // Update the state with the fetched posts.
      if (mounted) {
        setState(() {
          postCount = fetchedPosts.length;
          _posts = fetchedPosts;
        });
      }
    } catch (e) {
      // Handle any errors during the fetch operation.
      debugPrint("Error fetching user posts: $e");
    } finally {
      // Ensure the loading indicator is turned off.
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget refreshIcon() {
    return Image.asset(
      'assets/icons/dark.png',
      width: 35,
      height: 35,
    );
  }

  // Follow functionality
  Future<void> checkFollowStatus() async {
    String userId = getUserId();
    if (userId.isEmpty) return;

    try {
      String? currentUserId = await InZoneDatabase.getCurrentUserUid();
      if (currentUserId != null && currentUserId != userId) {
        // Get the current user's profile to check their relationships
        Map<String, dynamic>? currentUserProfile =
            await InZoneDatabase.getCurrentUserProfile();

        if (currentUserProfile != null) {
          List<dynamic> currentUserFollowing =
              currentUserProfile['following'] ?? [];
          List<dynamic> currentUserFollowers =
              currentUserProfile['followers'] ?? [];

          setState(() {
            // Check 1: Is the current user following the viewed profile?
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

            // Check 2: Is the viewed profile following the current user?
            _isFollowedBy = false;
            for (var follower in currentUserFollowers) {
              if (follower is Map<String, dynamic>) {
                if (follower['id'] == userId) {
                  _isFollowedBy = true;
                  break;
                }
              } else if (follower is String && follower == userId) {
                _isFollowedBy = true;
                break;
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isFollowing = false;
          _isFollowedBy = false;
        });
      }
    }
  }

  void toggleFollow() async {
    String userId = getUserId();
    if (userId.isEmpty) return;

    String? currentUserId = await InZoneDatabase.getCurrentUserUid();
    if (currentUserId == null) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Please log in to follow users',
      );
      return;
    }

    bool currentFollowState = isFollowing;
    bool newFollowState = !currentFollowState;

    try {
      bool success = false;
      if (widget.isAI) {
        // For AI users
        if (newFollowState) {
          success = await InZoneDatabase.followAIUser(userId);
          if (success) {
            ToastService.showToast(
              context,
              backgroundColor: Theme.of(context).canvasColor,
              shadowColor: Colors.transparent,
              leading: const Icon(
                FeatherIcons.checkCircle,
                color: Colors.greenAccent,
              ),
              message: 'Following $username',
            );
          }
        } else {
          success = await InZoneDatabase.unfollowAIUser(userId);
          if (success) {
            ToastService.showToast(
              context,
              backgroundColor: Theme.of(context).canvasColor,
              shadowColor: Colors.transparent,
              leading: const Icon(
                FeatherIcons.checkCircle,
                color: Colors.greenAccent,
              ),
              message: 'Unfollowed $username',
            );
          }
        }
      } else {
        // For human users
        if (newFollowState) {
          String currentUserName = await _getCurrentUserName(currentUserId);
          await InZoneDatabase.followUser(userId, currentUserName);
          success = true;
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.checkCircle,
              color: Colors.greenAccent,
            ),
            message: 'Following $username',
          );
        } else {
          await InZoneDatabase.unfollowUser(userId);
          success = true;
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              FeatherIcons.checkCircle,
              color: Colors.greenAccent,
            ),
            message: 'Unfollowed $username',
          );
        }
      }

      if (success) {
        // Refresh profile after successful follow/unfollow to get accurate counts
        await fetchUserProfile();
        await checkFollowStatus(); // Also refresh follow status
      } else {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            FeatherIcons.xCircle,
            color: Colors.redAccent,
          ),
          message: 'Failed to ${newFollowState ? 'follow' : 'unfollow'} user',
        );
      }
    } catch (e) {
      // Show error message
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Failed to ${newFollowState ? 'follow' : 'unfollow'} user: $e',
      );
    }
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

  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 15),
            InkWell(
              onTap: _isFollowedBy
                  ? () async {
                      Navigator.of(context).pop(); // Close the bottom sheet
                      String? currentUserId =
                          await InZoneDatabase.getCurrentUserUid();
                      if (currentUserId != null) {
                        bool success = await InZoneDatabase.removeFromFollowers(
                            getUserId());
                        if (success) {
                          ToastService.showToast(
                            context,
                            backgroundColor: Theme.of(context).canvasColor,
                            shadowColor: Colors.transparent,
                            leading: const Icon(
                              Icons.person_remove,
                              color: Colors.redAccent,
                            ),
                            message: 'User removed from your followers',
                          );
                          // Refresh the profile data
                          fetchUserProfile();
                        }
                      }
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_remove,
                      color: _isFollowedBy
                          ? Theme.of(context).iconTheme.color
                          : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Remove from followers',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isFollowedBy
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Colors.grey,
                      ),
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

  // Build AI Badge with tooltip functionality
  Widget _buildAIBadge() {
    return GestureDetector(
      onTap: () => _showAITooltip(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2196F3).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI Profile',
              style: TextStyle(
                color: const Color(0xFF2196F3).withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show AI explanation tooltip
  void _showAITooltip() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with AI icon and title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2196F3),
                            Color(0xFF03A9F4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Explanation text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meet our AI personas. They\'re active creators and chat partners, posting content, commenting, and sparking great discussions.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build feature items
  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main content is always present
            _buildMainContent(),
            // Show shimmering overlay during loading or refresh
            if (isLoading || isRefreshing)
              Positioned(
                top: isRefreshing ? 80 : 0, // refresh 시 아이콘 영역 비워둠
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Theme.of(context)
                      .scaffoldBackgroundColor
                      .withOpacity(isRefreshing ? 0.9 : 1.0),
                  child: ProfileShimmering(context, widget.isAI),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SmartRefresher(
      enablePullDown: true,
      controller: _refreshController,
      onRefresh: _onRefresh,
      // Use AlwaysScrollableScrollPhysics
      physics: const AlwaysScrollableScrollPhysics(),
      header: ClassicHeader(
        releaseIcon: refreshIcon(),
        refreshingIcon: refreshIcon(),
        completeIcon: refreshIcon(),
        idleIcon: refreshIcon(),
        failedIcon: refreshIcon(),
        refreshingText: "",
        releaseText: "",
        completeText: "",
        idleText: "",
        failedText: "",
      ),
      // Use CustomScrollView instead of nested SingleChildScrollView for better performance
      child: CustomScrollView(
        // Remove nested scroll physics conflicts
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Profile header
                Container(
                  color: Theme.of(context).cardColor,
                  child: Stack(
                    children: [
                      ProfileAppbar(
                        name: name,
                        bio: bio,
                        profileImageUrl: profileImageUrl,
                        username: username,
                        postCount: postCount,
                        followingCount: followingCount,
                        followersCount: followersCount,
                        actionButtons: buildActionButtons(),
                        isProfilePage: true,
                        savedCharacters: _savedCharacters,
                        areCharactersLoading: _areCharactersLoading,
                        onCharacterTap:
                            (characterId, characterName, characterImage) {
                          context.pushNamed('chat',
                              extra: ChatUser(
                                name: characterName,
                                email: characterId,
                                chatId: null,
                                isHuman: false,
                                profilePictureURL: characterImage,
                              ));
                        },
                        onFollowersTap: () {
                          context.push(
                              Routes.followersFollowingPath(widget.uid),
                              extra: true);
                        },
                        onFollowingTap: () {
                          context.push(
                              Routes.followersFollowingPath(widget.uid),
                              extra: false);
                        },
                      ),
                      Positioned(
                        top: 10,
                        left: 15,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_back_ios,
                                  size: 18,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // AI Badge (only show for AI profiles)
                      if (widget.isAI)
                        Positioned(
                          top: 15,
                          right: 20,
                          child: _buildAIBadge(),
                        ),
                      // More options button (AI가 아닐 때만 표시)
                      if (!widget.isAI)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => _showOptionsBottomSheet(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .cardColor
                                    .withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.more_horiz,
                                color: Theme.of(context).primaryColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Posts list
                if (_posts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(50.0),
                      child: Text(
                        'No posts found',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        ...List.generate(_posts.length, (index) {
                          return PostCard(
                            post: _posts[index],
                            profileImageUrl: profileImageUrl,
                            showHue: false,
                            onTap: (postId) {},
                            inProfile: true,
                          );
                        }),
                        const SizedBox(height: 100), // 하단 여백
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
