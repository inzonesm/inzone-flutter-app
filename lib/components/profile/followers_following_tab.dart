import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/ui/inzone_searchbar.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/screen/profile/profile_screen.dart';
import 'package:inzone/router/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toasty_box/toast_service.dart';

class FollowersFollowingTab extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> userList;
  final String
      userId; // The ID of the user whose followers/following we're viewing

  const FollowersFollowingTab({
    super.key,
    required this.userList,
    required this.userId,
  });

  @override
  State<FollowersFollowingTab> createState() => _FollowersFollowingTabState();
}

class _FollowersFollowingTabState extends State<FollowersFollowingTab> {
  bool followersSelected = true;
  bool messageShown = false;
  bool isLoading = true;
  Map<String, List<Map<String, dynamic>>> displayUserList = {
    "followers": [],
    "following": []
  };
  // Store profile images for users
  final Map<String, String> _userProfileImages = {};

  @override
  void initState() {
    super.initState();
    // Create a new mutable map instead of using the one from widget.userList directly
    displayUserList = {
      "followers":
          List<Map<String, dynamic>>.from(widget.userList["followers"] ?? []),
      "following":
          List<Map<String, dynamic>>.from(widget.userList["following"] ?? [])
    };

    updateMessageShown();
    _loadUserProfileImages();
  }

  Future<void> _loadUserProfileImages() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Process followers
      for (var user in displayUserList["followers"] ?? []) {
        final userId = user['id'] ?? user['uid'] ?? '';
        if (userId.isNotEmpty) {
          await _loadSingleUserProfileImage(userId);
        }
      }

      // Process following
      for (var user in displayUserList["following"] ?? []) {
        final userId = user['id'] ?? user['uid'] ?? '';
        if (userId.isNotEmpty) {
          await _loadSingleUserProfileImage(userId);
        }
      }
    } catch (e) {
      print('Error loading profile images: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSingleUserProfileImage(String userId) async {
    if (_userProfileImages.containsKey(userId)) return; // Already loaded

    try {
      // First try to get user profile from API (works for both human and AI users)
      final userData = await InZoneDatabase.getUserProfile(userId);
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

      // If API doesn't return a profile image, try AI user API
      final aiUserData = await InZoneDatabase.getAIUserProfile(userId);
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

      // If both APIs fail, try Firestore directly
      // Try humanUsers collection first
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
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

      // Try aiUsers collection
      DocumentSnapshot aiUserDoc = await FirebaseFirestore.instance
          .collection('aiUsers')
          .doc(userId)
          .get();

      if (aiUserDoc.exists) {
        final aiUserData = aiUserDoc.data() as Map<String, dynamic>?;
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
      print('Error loading profile image for $userId: $e');
    }
  }

  Future<void> fetchFollowersAndFollowing() async {
    setState(() {
      isLoading = true;
    });

    try {
      // We're not making API calls anymore, just refreshing the UI with existing data
      updateMessageShown();
      _loadUserProfileImages();
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
        message: 'Failed to process followers/following: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void updateMessageShown() {
    setState(() {
      if (followersSelected) {
        messageShown = displayUserList["followers"]!.isEmpty;
      } else {
        messageShown = displayUserList["following"]!.isEmpty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).canvasColor;
    final currentList = followersSelected
        ? displayUserList["followers"]!
        : displayUserList["following"]!;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 40,
          width: MediaQuery.of(context).size.width - 10,
          decoration: BoxDecoration(
              color: backgroundColor, borderRadius: BorderRadius.circular(100)),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    followersSelected = true;
                    updateMessageShown();
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: followersSelected ? Colors.blue : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      "Followers",
                      style: TextStyle(
                        color: followersSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    followersSelected = false;
                    updateMessageShown();
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: followersSelected ? Colors.white : Colors.blue,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      "Following",
                      style: TextStyle(
                        color: followersSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: const InZoneSearchBar(
            backgroundColor: Color(0xffA8D7E9),
          ),
        ),
        const SizedBox(height: 10),
        messageShown
            ? Text(
                followersSelected
                    ? "This user has no followers"
                    : "This user is not following anyone",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              )
            : Expanded(
                child: ListView.separated(
                  // No need for PrimaryScrollController in CustomScrollView structure
                  itemCount: currentList.length,
                  itemBuilder: (context, index) {
                    final user = currentList[index];
                    final userId = user['id'] ?? '';
                    // Use only the username key from the API response
                    final userName = user['username'] ?? '';
                    final userType = user['type'] ?? 'human';

                    // Get profile image if available
                    final profileImageUrl = _userProfileImages[userId] ?? '';

                    return FutureBuilder<String?>(
                        future: InZoneDatabase.getCurrentUserUid(),
                        builder: (context, snapshot) {
                          final isCurrentUser =
                              snapshot.hasData && userId == snapshot.data;

                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: profileImageUrl.isNotEmpty
                                  ? Image.network(
                                      profileImageUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.account_circle),
                                    )
                                  : const Icon(Icons.account_circle),
                            ),
                            title: Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(userType == 'ai' ? 'AI User' : ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Show follow/unfollow button if not the current user
                                if (!isCurrentUser && !followersSelected)
                                  SizedBox(
                                    width: 100,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        // Handle unfollow action
                                        if (userType == 'ai') {
                                          await InZoneDatabase.unfollowAIUser(
                                              userId);
                                        } else {
                                          await InZoneDatabase.unfollowUser(
                                              userId);
                                        }
                                        // Refresh the list
                                        setState(() {
                                          displayUserList["following"]!
                                              .removeWhere((u) =>
                                                  u['id'] == userId ||
                                                  u['uid'] == userId);
                                          updateMessageShown();
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.black,
                                        side: BorderSide(
                                            color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 0),
                                      ),
                                      child: const Text('Unfollow'),
                                    ),
                                  ),

                                // Show remove follower option for followers tab
                                if (!isCurrentUser && followersSelected)
                                  IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () =>
                                        _showRemoveFollowerBottomSheet(
                                            context, userId),
                                  ),
                              ],
                            ),
                            onTap: () {
                              // Navigate to user profile using GoRouter instead of MaterialPageRoute
                              if (userType == 'ai') {
                                context
                                    .push(Routes.aiProfilePath(userId))
                                    .then((_) {
                                  // Refresh the list when returning from profile
                                  fetchFollowersAndFollowing();
                                });
                              } else {
                                context
                                    .push(Routes.regularProfilePath(userId))
                                    .then((_) {
                                  // Refresh the list when returning from profile
                                  fetchFollowersAndFollowing();
                                });
                              }
                            },
                          );
                        });
                  },
                  separatorBuilder: (context, index) => const Divider(),
                ),
              ),
        Container(
          height: 60,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).canvasColor,
                spreadRadius: 40,
                blurRadius: 40,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${displayUserList["following"]!.length}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(" Following "),
              const SizedBox(width: 10),
              Text(
                "${displayUserList["followers"]!.length}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(" Followers"),
            ],
          ),
        )
      ],
    );
  }

  Widget buildUserList() {
    final currentList = followersSelected
        ? displayUserList["followers"]!
        : displayUserList["following"]!;

    if (currentList.isEmpty) {
      return Center(
        child: Text(
          followersSelected ? "No followers yet" : "Not following anyone yet",
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: currentList.length,
      itemBuilder: (context, index) {
        final user = currentList[index];
        final userId = user['id'] ?? '';
        // Use only the username key from the API response
        final userName = user['username'] ?? '';
        final userType = user['type'] ?? 'human';

        // Get profile image if available
        final profileImageUrl = _userProfileImages[userId] ?? '';

        return FutureBuilder<String?>(
            future: InZoneDatabase.getCurrentUserUid(),
            builder: (context, snapshot) {
              final isCurrentUser = snapshot.hasData && userId == snapshot.data;

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: profileImageUrl.isNotEmpty
                      ? Image.network(
                          profileImageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.account_circle),
                        )
                      : const Icon(Icons.account_circle),
                ),
                title: Text(
                  userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(userType == 'ai' ? 'AI User' : ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show follow/unfollow button if not the current user
                    if (!isCurrentUser && !followersSelected)
                      SizedBox(
                        width: 100,
                        child: OutlinedButton(
                          onPressed: () async {
                            // Handle unfollow action
                            if (userType == 'ai') {
                              await InZoneDatabase.unfollowAIUser(userId);
                            } else {
                              await InZoneDatabase.unfollowUser(userId);
                            }
                            // Refresh the list
                            setState(() {
                              displayUserList["following"]!.removeWhere((u) =>
                                  u['id'] == userId || u['uid'] == userId);
                              updateMessageShown();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                          child: const Text('Unfollow'),
                        ),
                      ),

                    // Show remove follower option for followers tab
                    if (!isCurrentUser && followersSelected)
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () =>
                            _showRemoveFollowerBottomSheet(context, userId),
                      ),
                  ],
                ),
                onTap: () {
                  // Navigate to user profile using GoRouter instead of MaterialPageRoute
                  if (userType == 'ai') {
                    context.push(Routes.aiProfilePath(userId)).then((_) {
                      // Refresh the list when returning from profile
                      fetchFollowersAndFollowing();
                    });
                  } else {
                    context.push(Routes.regularProfilePath(userId)).then((_) {
                      // Refresh the list when returning from profile
                      fetchFollowersAndFollowing();
                    });
                  }
                },
              );
            });
      },
    );
  }

  void _showRemoveFollowerBottomSheet(BuildContext context, String userId) {
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
                Navigator.pop(context); // Close the bottom sheet
                await InZoneDatabase.removeFromFollowers(userId);
                // Refresh the list
                setState(() {
                  displayUserList["followers"]!.removeWhere(
                      (u) => u['id'] == userId || u['uid'] == userId);
                  updateMessageShown();
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  children: [
                    Icon(Icons.person_remove),
                    SizedBox(width: 16),
                    Text(
                      'Remove follower',
                      style: TextStyle(fontSize: 16),
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
}

class FollowButton extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  const FollowButton(
      {super.key, required this.otherUserId, required this.otherUserName});

  @override
  _FollowButtonState createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool isFollowing = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkFollowStatus();
  }

  Future<void> checkFollowStatus() async {
    try {
      // Get the current user's profile to check their following list
      String? currentUserId = await InZoneDatabase.getCurrentUserUid();
      if (currentUserId != null) {
        // Get the current user's profile
        Map<String, dynamic>? userProfile =
            await InZoneDatabase.getCurrentUserProfile();
        if (userProfile != null && userProfile.containsKey('following')) {
          List<dynamic> following = userProfile['following'] ?? [];

          // Check if the other user is in the following list
          bool isCurrentlyFollowing = false;
          for (var followedUser in following) {
            if (followedUser is Map<String, dynamic>) {
              if (followedUser['id'] == widget.otherUserId) {
                isCurrentlyFollowing = true;
                break;
              }
            } else if (followedUser is String &&
                followedUser == widget.otherUserId) {
              isCurrentlyFollowing = true;
              break;
            }
          }

          setState(() {
            isFollowing = isCurrentlyFollowing;
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void toggleFollow(bool follow) async {
    if (follow) {
      await InZoneDatabase.followUser(widget.otherUserId, widget.otherUserName);
      setState(() {
        isFollowing = true;
      });
    } else {
      await InZoneDatabase.unfollowUser(widget.otherUserId);
      setState(() {
        isFollowing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 80,
        height: 30,
        child: Center(
          child: SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return TextButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all<Color>(
          isFollowing
              ? Colors.blue
              : Colors
                  .transparent, // Filled when following, transparent when not
        ),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100.0),
            side: const BorderSide(
                color: Colors.blue), // Always outlined with blue
          ),
        ),
      ),
      onPressed: () {
        toggleFollow(!isFollowing);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Text(
          isFollowing ? "Following" : "Follow", // Change text based on state
          style: TextStyle(
            color: isFollowing
                ? Colors.white
                : Colors.blue, // White text for filled, blue for outlined
          ),
        ),
      ),
    );
  }
}
