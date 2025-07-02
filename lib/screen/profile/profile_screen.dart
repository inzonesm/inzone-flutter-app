import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/profile/user_posts_tab.dart';
import 'package:inzone/components/profile/followers_following_tab.dart';
import 'package:inzone/components/ui/profile_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
import 'package:inzone/screen/chat/human_chat_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart'; // For ChatUser class
import 'package:inzone/services/inzone_database.dart';
import 'package:go_router/go_router.dart';
import 'package:toasty_box/toast_service.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  final bool isAI;

  const ProfileScreen({super.key, required this.uid, this.isAI = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
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

  // Additional state for this specific screen
  bool isFollowing = false;
  late TabController _tabController;
  late TabController _scrollTabController;

  // Store the community tab data
  Map<String, List<Map<String, dynamic>>> _communityTabData = {
    "followers": [],
    "following": []
  };

  @override
  void initState() {
    super.initState();
    // Initialize tab controllers
    _tabController = TabController(length: getTabLabels().length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        currentPage = _tabController.index;
      });
    });

    // Create a separate controller for our scrollable UI
    _scrollTabController =
        TabController(length: getTabLabels().length, vsync: this);
    _scrollTabController.addListener(() {
      if (_scrollTabController.index != currentPage) {
        setState(() {
          currentPage = _scrollTabController.index;
        });
      }
    });

    fetchUserProfile();
    fetchUserStats(widget.isAI);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollTabController.dispose();
    super.dispose();
  }

  // Methods previously from BaseProfileScreen
  String getUserId() {
    return widget.uid;
  }

  List<String> getTabLabels() {
    // Both AI and human users show Posts and Community tabs
    return const ['Posts', 'Community'];
  }

  List<Widget> getTabViews({String? profileImageUrl}) {
    return [
      // Posts tab
      UserPostsTab(
        userId: getUserId(),
        ai: widget.isAI,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      ),

      // Community tab - 스크롤 문제를 해결하기 위한 래핑
      Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FollowersFollowingTab(
          userList: _communityTabData,
          userId: getUserId(),
        ),
      ),
    ];
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
              bool isAiUser = widget.isAI;

              try {
                if (isAiUser) {
                  // For AI users
                  context.pushNamed('chat',
                      extra: ChatUser(
                        name: name,
                        email: targetUserId,
                        chatId: null,
                        isHuman: false,
                      ));
                } else {
                  // For human users
                  List<String> sortedIds = [currentUserId, targetUserId]
                    ..sort();
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
                    ToastService.showToast(
                      context,
                      backgroundColor: Theme.of(context).canvasColor,
                      shadowColor: Colors.transparent,
                      leading: const Icon(
                        FeatherIcons.xCircle,
                        color: Colors.redAccent,
                      ),
                      message: 'Failed to open conversation: $e',
                    );
                  }
                }
              } catch (e) {
                ToastService.showToast(
                  context,
                  backgroundColor: Theme.of(context).canvasColor,
                  shadowColor: Colors.transparent,
                  leading: const Icon(
                    FeatherIcons.xCircle,
                    color: Colors.redAccent,
                  ),
                  message: 'Error navigating to chat: $e',
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

    // First, get basic user profile data
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
          }
        } catch (e) {}
      }
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
          }
        } catch (e) {}
      }
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

    // Check follow status for both human and AI users
    await checkFollowStatus();
  }

  Future<void> fetchUserStats([bool isAi = false]) async {
    String userId = getUserId();
    if (userId.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Fetch post count from user posts
    List posts = [];
    if (isAi) {
      final result = await InZoneDatabase.getAIUserPosts(userId);
      if (result != null) {
        posts = result;
      }
    } else {
      final result = await InZoneDatabase.getUserPosts(userId);
      if (result != null) {
        posts = result;
      }
    }
    setState(() {
      postCount = posts.length;
    });

    setState(() {
      isLoading = false;
    });
  }

  // Follow functionality
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
        // If successful, refresh the profile data to get updated followers/following lists
        await fetchUserProfile();
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
                        'This is an AI profile that acts like a human user autonomously:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(Icons.chat_bubble_outline, 'Comments autonomously on posts'),
                      _buildFeatureItem(Icons.create_outlined, 'Creates and shares content'),
                      _buildFeatureItem(Icons.forum_outlined, 'Converses naturally in chats'),
                      _buildFeatureItem(Icons.people_outline, 'Interacts with other users'),
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
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              // 상단 여백 (앱바 대신 사용)
              const SliverToBoxAdapter(
                child: SizedBox(height: 0),
              ),

              // Profile header
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).cardColor,
                  child: Stack(
                    children: [
                      // Profile info section
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
              ),

              // Tab bar
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  Container(
                    height: 54.0,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Center(
                      child: TabBar(
                        controller: _scrollTabController,
                        tabs: getTabLabels()
                            .map((label) => Tab(text: label))
                            .toList(),
                        indicatorColor: Theme.of(context).primaryColor,
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.6),
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.label,
                        dividerColor: Colors.transparent,
                        indicator: UnderlineTabIndicator(
                          borderSide: BorderSide(
                              width: 3,
                              color: Theme.of(context).colorScheme.primary),
                          insets: const EdgeInsets.symmetric(horizontal: 0),
                        ),
                        labelPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                      ),
                    ),
                  ),
                ),
                pinned: true,
              ),

              // Add space
              const SliverToBoxAdapter(
                child: SizedBox(height: 5),
              ),
            ];
          },
          body: TabBarView(
            controller: _scrollTabController,
            children: getTabViews(profileImageUrl: profileImageUrl),
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate(this.child);

  @override
  double get minExtent => 54.0;

  @override
  double get maxExtent => 54.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      width: double.infinity,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}
