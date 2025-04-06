import 'package:flutter/material.dart';
import 'package:inzone/components/inzone_searchbar.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/screen/profile/profile_screen.dart';

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
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchFollowersAndFollowing() async {
    setState(() {
      isLoading = true;
    });

    try {
      // We're not making API calls anymore, just refreshing the UI with existing data
      updateMessageShown();
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process followers/following: $e')));
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

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        Flexible(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            width: MediaQuery.of(context).size.width - 10,
            decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(100)),
            child: Row(children: [
              Expanded(
                child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        followersSelected = true;
                        updateMessageShown();
                      });
                    },
                    style: ButtonStyle(
                        elevation: WidgetStateProperty.all(0),
                        backgroundColor: followersSelected
                            ? WidgetStateProperty.all(Colors.blue)
                            : WidgetStateProperty.all(Colors.white),
                        foregroundColor: WidgetStateProperty.all(Colors.black),
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100.0),
                        ))),
                    child: const Text("Followers")),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        followersSelected = false;
                        updateMessageShown();
                      });
                    },
                    style: ButtonStyle(
                        elevation: WidgetStateProperty.all(0),
                        backgroundColor: followersSelected
                            ? WidgetStateProperty.all(Colors.white)
                            : WidgetStateProperty.all(Colors.blue),
                        foregroundColor: WidgetStateProperty.all(Colors.black),
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100.0),
                        ))),
                    child: const Text("Following")),
              ),
            ]),
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        const Flexible(
          flex: 1,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: InZoneSearchBar(
              backgroundColor: Color(0xffA8D7E9),
            ),
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Flexible(
            flex: 7,
            child: messageShown
                ? Center(
                    child: Text(
                        "No ${followersSelected ? "Followers" : "Following"} yet"))
                : buildUserList()),
        Flexible(
          flex: 1,
          child: Container(
            height: 90,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).canvasColor,
                  spreadRadius: 40,
                  blurRadius: 40,
                  offset: const Offset(0, 6), // changes position of shadow
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
                const Text(
                  " Following ",
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  "${displayUserList["followers"]!.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  " Followers",
                ),
              ],
            ),
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

        return FutureBuilder<String?>(
            future: InZoneDatabase.getCurrentUserUid(),
            builder: (context, snapshot) {
              final isCurrentUser = snapshot.hasData && userId == snapshot.data;

              return ListTile(
                leading: RandomAvatar(
                  userId,
                  height: 50,
                  width: 50,
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
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'remove_follower') {
                            await InZoneDatabase.removeFromFollowers(userId);
                            // Refresh the list
                            setState(() {
                              displayUserList["followers"]!.removeWhere((u) =>
                                  u['id'] == userId || u['uid'] == userId);
                              updateMessageShown();
                            });
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'remove_follower',
                            child: Text('Remove follower'),
                          ),
                        ],
                      ),
                  ],
                ),
                onTap: () {
                  // Navigate to user profile using MaterialPageRoute instead of named route
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        uid: userId,
                        isAI: userType == 'ai', // Check if it's an AI user
                      ),
                    ),
                  ).then((_) {
                    // Refresh the list when returning from profile
                    fetchFollowersAndFollowing();
                  });
                },
              );
            });
      },
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
