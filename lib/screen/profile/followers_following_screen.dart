import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/components/cards/user_follow_card.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final bool startWithFollowers;

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    this.startWithFollowers = true,
  });

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  bool followersSelected = true;
  bool isLoading = true;
  String searchQuery = '';

  Map<String, List<Map<String, dynamic>>> userList = {
    "followers": [],
    "following": []
  };

  // Store profile images for users
  final Map<String, String> _userProfileImages = {};

  @override
  void initState() {
    super.initState();
    followersSelected = widget.startWithFollowers;
    _fetchFollowersAndFollowing();
  }

  @override
  void dispose() {
    // Clear image cache to free up memory
    _userProfileImages.clear();
    super.dispose();
  }

  Future<void> _fetchFollowersAndFollowing() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user ID to check if we're viewing our own profile
      final currentUserId = await InZoneDatabase.getCurrentUserUid();

      // Get user profile data directly from Firebase
      Map<String, dynamic>? userProfile;
      DocumentSnapshot? userDoc;

      try {
        // Try humanUsers collection first
        userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(widget.userId)
            .get();

        if (userDoc.exists) {
          userProfile = userDoc.data() as Map<String, dynamic>?;
        } else {
          // Try aiUsers collection if not found in humanUsers
          userDoc = await FirebaseFirestore.instance
              .collection('aiUsers')
              .doc(widget.userId)
              .get();

          if (userDoc.exists) {
            userProfile = userDoc.data() as Map<String, dynamic>?;
          }
        }
      } catch (e) {
        print('Error fetching user document: $e');
      }

      print('Debug - User profile data from Firebase: $userProfile');

      // Process followers data
      List<Map<String, dynamic>> formattedFollowers = [];
      if (userProfile != null && userProfile.containsKey('followers')) {
        final followersList = userProfile['followers'] as List<dynamic>? ?? [];
        print('Debug - Followers list from Firebase: $followersList');

        for (var follower in followersList) {
          if (follower is Map<String, dynamic>) {
            // Already in the correct format
            formattedFollowers.add({
              'id': follower['id'] ?? '',
              'username': follower['username'] ?? 'Unknown',
              'type': follower['type'] ?? 'human'
            });
          } else if (follower is String) {
            // Legacy format - just an ID, try to get the user's profile
            try {
              // Try to get user data from Firebase
              DocumentSnapshot followerDoc = await FirebaseFirestore.instance
                  .collection('humanUsers')
                  .doc(follower)
                  .get();

              if (followerDoc.exists) {
                final followerData =
                    followerDoc.data() as Map<String, dynamic>?;
                formattedFollowers.add({
                  'id': follower,
                  'username': followerData?['username'] ??
                      followerData?['Username'] ??
                      'Unknown',
                  'type': 'human'
                });
              } else {
                // Try aiUsers collection
                followerDoc = await FirebaseFirestore.instance
                    .collection('aiUsers')
                    .doc(follower)
                    .get();

                if (followerDoc.exists) {
                  final followerData =
                      followerDoc.data() as Map<String, dynamic>?;
                  formattedFollowers.add({
                    'id': follower,
                    'username': followerData?['username'] ??
                        followerData?['Username'] ??
                        'Unknown',
                    'type': 'ai'
                  });
                } else {
                  // Fallback with just the ID
                  formattedFollowers.add(
                      {'id': follower, 'username': 'Unknown', 'type': 'human'});
                }
              }
            } catch (e) {
              print('Error fetching follower profile for $follower: $e');
              // Fallback with just the ID
              formattedFollowers.add(
                  {'id': follower, 'username': 'Unknown', 'type': 'human'});
            }
          }
        }
      }

      // Process following data from user profile
      List<Map<String, dynamic>> formattedFollowing = [];
      if (userProfile != null && userProfile.containsKey('following')) {
        final followingList = userProfile['following'] as List<dynamic>? ?? [];
        print('Debug - Following list from Firebase: $followingList');

        for (var follow in followingList) {
          if (follow is Map<String, dynamic>) {
            // Already in the correct format
            formattedFollowing.add({
              'id': follow['id'] ?? '',
              'username': follow['username'] ?? 'Unknown',
              'type': follow['type'] ?? 'human'
            });
          } else if (follow is String) {
            // Legacy format - just an ID, try to get the user's profile
            try {
              // Try to get user data from Firebase
              DocumentSnapshot followDoc = await FirebaseFirestore.instance
                  .collection('humanUsers')
                  .doc(follow)
                  .get();

              if (followDoc.exists) {
                final followData = followDoc.data() as Map<String, dynamic>?;
                formattedFollowing.add({
                  'id': follow,
                  'username': followData?['username'] ??
                      followData?['Username'] ??
                      'Unknown',
                  'type': 'human'
                });
              } else {
                // Try aiUsers collection
                followDoc = await FirebaseFirestore.instance
                    .collection('aiUsers')
                    .doc(follow)
                    .get();

                if (followDoc.exists) {
                  final followData = followDoc.data() as Map<String, dynamic>?;
                  formattedFollowing.add({
                    'id': follow,
                    'username': followData?['username'] ??
                        followData?['Username'] ??
                        'Unknown',
                    'type': 'ai'
                  });
                } else {
                  // Fallback with just the ID
                  formattedFollowing.add(
                      {'id': follow, 'username': 'Unknown', 'type': 'human'});
                }
              }
            } catch (e) {
              print('Error fetching follow profile for $follow: $e');
              // Fallback with just the ID
              formattedFollowing
                  .add({'id': follow, 'username': 'Unknown', 'type': 'human'});
            }
          }
        }
      }

      print('Debug - Final formatted followers: $formattedFollowers');
      print('Debug - Final formatted following: $formattedFollowing');

      setState(() {
        userList = {
          "followers": formattedFollowers,
          "following": formattedFollowing
        };
      });

      await _loadUserProfileImages();
    } catch (e) {
      print('Error fetching followers/following: $e');
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).cardColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Failed to load followers/following: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserProfileImages() async {
    try {
      // Limit concurrent image loading to prevent memory issues
      const int batchSize = 5;
      final allUsers = [...userList["followers"]!, ...userList["following"]!];

      for (int i = 0; i < allUsers.length; i += batchSize) {
        final batch = allUsers.skip(i).take(batchSize);
        await Future.wait(
          batch.map((user) {
            final userId = user['id'] ?? user['uid'] ?? '';
            if (userId.isNotEmpty) {
              return _loadSingleUserProfileImage(userId);
            }
            return Future.value();
          }),
          eagerError: false, // Continue even if some images fail to load
        );

        // Add a small delay between batches to prevent overwhelming the system
        if (i + batchSize < allUsers.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      print('Error loading profile images: $e');
    }
  }

  Future<void> _loadSingleUserProfileImage(String userId) async {
    if (_userProfileImages.containsKey(userId)) return;
    if (userId.isEmpty) return;

    try {
      // Add timeout to prevent hanging requests
      final userData = await InZoneDatabase.getUserProfile(userId).timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (userData != null && userData.containsKey('profilePicture')) {
        final profilePicture = userData['profilePicture'];
        if (profilePicture != null && profilePicture.toString().isNotEmpty) {
          if (mounted) {
            setState(() {
              _userProfileImages[userId] = profilePicture.toString();
            });
          }
          return;
        }
      }

      // Try AI user API with timeout
      final aiUserData = await InZoneDatabase.getAIUserProfile(userId).timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (aiUserData != null && aiUserData.containsKey('profilePicture')) {
        final profilePicture = aiUserData['profilePicture'];
        if (profilePicture != null && profilePicture.toString().isNotEmpty) {
          if (mounted) {
            setState(() {
              _userProfileImages[userId] = profilePicture.toString();
            });
          }
          return;
        }
      }

      // Fallback to Firebase with timeout - try humanUsers first
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('humanUsers')
            .doc(userId)
            .get()
            .timeout(const Duration(seconds: 3));

        if (userDoc.exists) {
          final userData = userDoc.data();
          final profilePicture =
              userData?['profilePicture'] ?? userData?['profileImage'];
          if (profilePicture != null && profilePicture.toString().isNotEmpty) {
            if (mounted) {
              setState(() {
                _userProfileImages[userId] = profilePicture.toString();
              });
            }
            return;
          }
        }
      } catch (e) {
        print('Error fetching from humanUsers for $userId: $e');
      }

      // Try aiUsers collection with timeout
      try {
        final aiUserDoc = await FirebaseFirestore.instance
            .collection('aiUsers')
            .doc(userId)
            .get()
            .timeout(const Duration(seconds: 3));

        if (aiUserDoc.exists) {
          final aiUserData = aiUserDoc.data();
          final profilePicture = aiUserData?['profilePicture'] ??
              aiUserData?['profileImage'] ??
              aiUserData?['character']?['profilePicture'];
          if (profilePicture != null && profilePicture.toString().isNotEmpty) {
            if (mounted) {
              setState(() {
                _userProfileImages[userId] = profilePicture.toString();
              });
            }
          }
        }
      } catch (e) {
        print('Error fetching from aiUsers for $userId: $e');
      }
    } catch (e) {
      print('Error loading profile image for $userId: $e');
      // Set a placeholder to prevent repeated attempts
      if (mounted) {
        setState(() {
          _userProfileImages[userId] = '';
        });
      }
    }
  }

  List<Map<String, dynamic>> get filteredCurrentList {
    final currentList =
        followersSelected ? userList["followers"]! : userList["following"]!;

    if (searchQuery.isEmpty) {
      return currentList;
    }

    return currentList.where((user) {
      final username = user['username']?.toString().toLowerCase() ?? '';
      return username.contains(searchQuery.toLowerCase());
    }).toList();
  }

  void _showRemoveFollowerBottomSheet(BuildContext context, String userId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? AppColors.darkSurfaceColor
              : AppColors.lightSurfaceColor,
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
                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 15),
            InkWell(
              onTap: () async {
                Navigator.pop(context);
                await InZoneDatabase.removeFromFollowers(userId);
                setState(() {
                  userList["followers"]!.removeWhere(
                      (u) => u['id'] == userId || u['uid'] == userId);
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_remove,
                      color: isDarkMode
                          ? AppColors.darkTextColor
                          : AppColors.lightTextColor,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Remove follower',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode
                            ? AppColors.darkTextColor
                            : AppColors.lightTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor =
        isDarkMode ? AppColors.darkSurfaceColor : AppColors.lightSurfaceColor;
    final textColor =
        isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor;

    final currentList = filteredCurrentList;

    return ColorfulSafeArea(
      color: Theme.of(context).canvasColor,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CustomAppBar(
              isHome: true,
              isSettings: true,
              isImage: false,
              title: followersSelected ? 'Followers' : 'Following',
              userPoints: "100",
              onSearchTap: () {},
              onProfileTap: () {},
              onPointsTap: () {},
            ),
          ),
        ),
        body: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading followers and following...'),
                  ],
                ),
              )
            : Column(
                children: [
                  // Custom tab buttons
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                followersSelected = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: followersSelected
                                    ? AppColors.primaryBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Center(
                                child: Text(
                                  "Followers (${userList["followers"]!.length})",
                                  style: TextStyle(
                                    color: followersSelected
                                        ? Colors.white
                                        : textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                followersSelected = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !followersSelected
                                    ? AppColors.primaryBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Center(
                                child: Text(
                                  "Following (${userList["following"]!.length})",
                                  style: TextStyle(
                                    color: !followersSelected
                                        ? Colors.white
                                        : textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: TextStyle(
                            color: textColor.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            FeatherIcons.search,
                            color: textColor.withOpacity(0.5),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Users list
                  Expanded(
                    child: currentList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  followersSelected
                                      ? FeatherIcons.users
                                      : FeatherIcons.userPlus,
                                  size: 64,
                                  color: textColor.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  followersSelected
                                      ? searchQuery.isEmpty
                                          ? "No followers yet"
                                          : "No followers found"
                                      : searchQuery.isEmpty
                                          ? "Not following anyone yet"
                                          : "No following found",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withOpacity(0.5),
                                  ),
                                ),
                                if (searchQuery.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      followersSelected
                                          ? "Share your profile to get followers"
                                          : "Discover and follow interesting people",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textColor.withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: currentList.length,
                            itemBuilder: (context, index) {
                              final user = currentList[index];
                              final userId = user['id'] ?? '';
                              final userName = user['username'] ?? '';
                              final userType = user['type'] ?? 'human';
                              final profileImageUrl =
                                  _userProfileImages[userId] ?? '';

                              return FutureBuilder<String?>(
                                future: InZoneDatabase.getCurrentUserUid(),
                                builder: (context, snapshot) {
                                  final isCurrentUser = snapshot.hasData &&
                                      userId == snapshot.data;

                                  return UserFollowCard(
                                    userId: userId,
                                    username: userName,
                                    userType: userType,
                                    profileImageUrl: profileImageUrl,
                                    isCurrentUser: isCurrentUser,
                                    isFollowersTab: followersSelected,
                                    onUnfollow: () async {
                                      if (userType == 'ai') {
                                        await InZoneDatabase.unfollowAIUser(
                                            userId);
                                      } else {
                                        await InZoneDatabase.unfollowUser(
                                            userId);
                                      }
                                      setState(() {
                                        userList["following"]!.removeWhere(
                                            (u) =>
                                                u['id'] == userId ||
                                                u['uid'] == userId);
                                      });
                                    },
                                    onRemoveFollower: () =>
                                        _showRemoveFollowerBottomSheet(
                                            context, userId),
                                    onTap: () {
                                      if (userType == 'ai') {
                                        context
                                            .push(Routes.aiProfilePath(userId));
                                      } else {
                                        context.push(
                                            Routes.regularProfilePath(userId));
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
