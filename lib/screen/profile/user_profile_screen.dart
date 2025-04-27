import 'package:flutter/material.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/profile/base_profile_screen.dart';
import 'package:inzone/components/profile/user_posts_tab.dart';
import 'package:inzone/screen/profile/edit_profile_screen.dart';

import 'package:inzone/data/inzone_post.dart';

class UserProfileScreen extends BaseProfileScreen {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState
    extends BaseProfileScreenState<UserProfileScreen> {
  String? currentUserId;
  String profileImageUrl = "";
  // Store the community tab data
  Map<String, List<Map<String, dynamic>>> _communityTabData = {
    "followers": [],
    "following": []
  };

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    currentUserId = await InZoneDatabase.getCurrentUserUid();
    if (currentUserId == null) {
      setState(() {
        name = "Not logged in";
        bio = "Please log in to view your profile";
        isLoading = false;
      });
    } else {
      // 여기서만 fetch 시작
      await fetchUserProfile();
      await fetchUserStats();
    }
  }

  @override
  String getUserId() {
    return currentUserId ?? '';
  }

  @override
  List<String> getTabLabels() {
    return const ['Posts'];
  }

  @override
  List<Widget> getTabViews() {
    if (currentUserId == null) {
      return [
        const Center(child: Text('Please log in to view your posts')),
        const Center(child: Text('Please log in to view your community')),
      ];
    }
    return [
      UserPostsTab(
        userId: currentUserId!,
        ai: false,
      ),
      // FollowersFollowingTab(
      //   userList: _communityTabData,
      //   userId: currentUserId!,
      // ),
    ];
  }

//edit profile button
  @override
  Widget buildActionButtons() {
    // For the current user, we could add an edit profile button here
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Navigate to edit profile screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    userId: currentUserId!,
                    initialName: name,
                    initialUsername: name, // Using name as username for now
                    initialBio: bio,
                  ),
                ),
              ).then((updated) {
                // Refresh profile if updated
                if (updated == true) {
                  fetchUserProfile();
                  fetchUserStats();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(
              'Edit profile',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }

  @override
  PreferredSizeWidget? buildAppBar() {
    return PreferredSize(
      preferredSize: Size.zero,
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    );
  }

  @override
  Future<void> fetchUserProfile() async {
    if (currentUserId == null) return;

    Map<String, dynamic>? userProfile =
        await InZoneDatabase.getUserProfile(currentUserId!);

    if (userProfile != null) {
      List<dynamic> followers = userProfile["followers"] ?? [];
      List<dynamic> following = userProfile["following"] ?? [];

      List<Map<String, dynamic>> formattedFollowers = [];
      List<Map<String, dynamic>> formattedFollowing = [];

      // Process followers
      for (var follower in followers) {
        if (follower is Map<String, dynamic>) {
          formattedFollowers.add({
            'id': follower['id'] ?? '',
            'username': follower['username'] ?? '',
            'type': follower['type'] ?? 'human',
          });
        } else if (follower is String) {
          try {
            Map<String, dynamic>? followerProfile =
                await InZoneDatabase.getUserProfile(follower);
            if (followerProfile != null) {
              formattedFollowers.add({
                'id': follower,
                'username': followerProfile['username'] ?? '',
                'type': 'human',
              });
            }
          } catch (e) {
            // ignore
          }
        }
      }

      // Process following
      for (var follow in following) {
        if (follow is Map<String, dynamic>) {
          formattedFollowing.add({
            'id': follow['id'] ?? '',
            'username': follow['username'] ?? '',
            'type': follow['type'] ?? 'human',
          });
        } else if (follow is String) {
          try {
            Map<String, dynamic>? followProfile =
                await InZoneDatabase.getUserProfile(follow);
            if (followProfile != null) {
              formattedFollowing.add({
                'id': follow,
                'username': followProfile['username'] ?? '',
                'type': 'human',
              });
            }
          } catch (e) {
            // ignore
          }
        }
      }

      // ✅ 데이터 업데이트
      setState(() {
        name = userProfile["name"] ?? "Unknown"; // 이름
        username = userProfile["username"] ?? "Unknown"; // 유저네임
        bio = userProfile["bio"] ?? ""; // 바이오
        profileImageUrl =
            userProfile["profilePicture"] ?? ""; // ✅ 프로필 이미지 URL 추가
        followersCount = followers.length;
        followingCount = following.length;
        _communityTabData = {
          "followers": formattedFollowers,
          "following": formattedFollowing,
        };
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Future<void> fetchUserStats([bool isAi = false]) async {
    // Do nothing, we're handling this in _getCurrentUserId
    if (currentUserId == null) return;
    await super.fetchUserStats();
  }
}

class PersonalFeedScreen extends StatefulWidget {
  const PersonalFeedScreen({super.key});

  @override
  State<PersonalFeedScreen> createState() => _PersonalFeedScreenState();
}

class _PersonalFeedScreenState extends State<PersonalFeedScreen> {
  List<PostCard> posts = [];
  List<AvatarCard> avatarCards = [];
  bool isLoading = true; // Loading state

  Future<void> getFeed({bool isRefresh = false}) async {
    try {
      setState(() {
        isLoading = true; // Start loading
      });

      final response = await InZoneDatabase.getFeed();
      if (response != null &&
          response.containsKey('posts') &&
          response.containsKey('characters')) {
        // Parse the posts and avatars
        List<dynamic> fetchedPosts = response['posts'];
        List<dynamic> fetchedCharacters = response['characters'];

        for (var characterJson in fetchedCharacters) {
          InZoneAvatar avatar = InZoneAvatar.fromJson(characterJson);
          avatarCards.add(AvatarCard(avatar: avatar));
        }

        _addPostsToScreen(fetchedPosts);
      } else {
        throw Exception('Invalid response structure');
      }
    } finally {
      setState(() {
        isLoading = false; // End loading
      });
    }
  }

  void _addPostsToScreen(List<dynamic> fetchedPosts) async {
    for (var postJson in fetchedPosts) {
      InZonePost post = InZonePost.fromJson(postJson);
      posts.add(PostCard(
        post: post,
        showHue: false,
        onTap: (postId) {},
      ));
    }
    setState(() {
      posts.shuffle();
    });
  }

  @override
  void initState() {
    super.initState();
    getFeed();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(), // Show loading indicator
          )
        : Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: posts, // Display posts once loaded
              ),
            ),
          );
  }
}

class LikedScreen extends StatefulWidget {
  const LikedScreen({super.key});

  @override
  State<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends State<LikedScreen> {
  List<PostCard> posts = [];
  List<AvatarCard> avatarCards = [];
  bool isLoading = true; // Loading state

  Future<void> getFeed({bool isRefresh = false}) async {
    try {
      setState(() {
        isLoading = true; // Start loading
      });

      final response = await InZoneDatabase.getFeed();

      // Ensure the response contains the expected structure
      if (response != null &&
          response.containsKey('posts') &&
          response.containsKey('characters')) {
        // Parse the posts and avatars
        List<dynamic> fetchedPosts = response['posts'];
        List<dynamic> fetchedCharacters = response['characters'];

        for (var characterJson in fetchedCharacters) {
          InZoneAvatar avatar = InZoneAvatar.fromJson(characterJson);
          avatarCards.add(AvatarCard(avatar: avatar));
        }

        _addPostsToScreen(fetchedPosts);
      } else {
        throw Exception('Invalid response structure');
      }
    } finally {
      setState(() {
        isLoading = false; // End loading
      });
    }
  }

  void _addPostsToScreen(List<dynamic> fetchedPosts) async {
    // Limit the posts to a maximum of 10
    final limitedPosts = fetchedPosts.take(10).toList();

    for (var postJson in limitedPosts) {
      InZonePost post = InZonePost.fromJson(postJson);
      posts.add(PostCard(
        post: post,
        showHue: false,
        onTap: (postId) {},
      ));
    }

    setState(() {
      posts.shuffle();
    });
  }

  @override
  void initState() {
    super.initState();
    getFeed();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Align(
            alignment: Alignment.center,
            child: Center(
              child: CircularProgressIndicator(), // Show loading indicator
            ),
          )
        : Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10, // Horizontal space between items
                runSpacing: 10, // Vertical space between rows
                children: avatarCards, // Use your avatar cards list here
              ),
            ),
          );
  }
}
