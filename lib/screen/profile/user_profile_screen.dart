import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/screen/settings/settings_screen.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/profile/base_profile_screen.dart';
import 'package:inzone/components/profile/user_posts_tab.dart';
import 'package:inzone/screen/profile/edit_profile_screen.dart';
import 'package:inzone/components/ui/profile_appbar.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';

import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/theme/app_colors.dart';

class UserProfileScreen extends BaseProfileScreen {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState
    extends BaseProfileScreenState<UserProfileScreen> {
  String? currentUserId;
  @override
  String profileImageUrl = "";
  late TabController _scrollTabController;

  // Store the community tab data
  Map<String, List<Map<String, dynamic>>> _communityTabData = {
    "followers": [],
    "following": []
  };

  @override
  void initState() {
    super.initState();
    _scrollTabController =
        TabController(length: getTabLabels().length, vsync: this);

    // Keep the controllers in sync
    _scrollTabController.addListener(() {
      if (_scrollTabController.index != currentPage) {
        setState(() {
          currentPage = _scrollTabController.index;
        });
      }
    });

    _getCurrentUserId();
  }

  @override
  void dispose() {
    _scrollTabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    currentUserId = await InZoneDatabase.getCurrentUserUid();
    if (currentUserId == null) {
      setState(() {
        name = "Not logged in";
        username = "Not logged in";
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
      ];
    }
    return [
      UserPostsTab(
        userId: currentUserId!,
        ai: false,
      ),
    ];
  }

//edit profile button
  @override
  Widget buildActionButtons() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () {
              context.push(
                Routes.editProfile,
                extra: {
                  'userId': currentUserId!,
                  'initialName': name,
                  'initialUsername': username,
                  'initialBio': bio,
                },
              ).then((updated) {
                if (updated == true) {
                  fetchUserProfile();
                  fetchUserStats();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: theme.dividerColor, // ✔️ 라인도 테마 기반으로
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FeatherIcons.user,
                    size: 18,
                    color: theme.textTheme.bodyMedium?.color, // ✔️ 아이콘 컬러 테마 적용
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Profile',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color, // ✔️ 텍스트 컬러 테마 적용
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: theme.dividerColor, // ✔️ 라인도 테마 기반으로
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FeatherIcons.settings,
                    size: 18,
                    color: theme.textTheme.bodyMedium?.color, // ✔️ 아이콘 컬러 테마 적용
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color, // ✔️ 텍스트 컬러 테마 적용
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

  @override
  PreferredSizeWidget? buildAppBar() {
    return null; // SliverAppBar를 사용하므로 여기선 null을 반환
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
        name = userProfile["name"] ?? userProfile["Name"] ?? "Unknown"; // name
        username = userProfile["username"] ??
            userProfile["Username"] ??
            "Unknown"; // user name
        bio = userProfile["bio"] ?? userProfile["Bio"] ?? ""; // bio
        profileImageUrl = userProfile["profilePicture"] ??
            userProfile["ProfilePicture"] ??
            ""; // profile image url
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                await fetchUserProfile();
                await fetchUserStats();
              },
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).cardColor,
                child: ProfileAppbar(
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
              ),
            ),
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
                      unselectedLabelColor: Theme.of(context).hintColor,
                      indicatorWeight: 3.0,
                    ),
                  ),
                ),
              ),
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height -
                    200, // Adjust this value as needed
                child: TabBarView(
                  controller: _scrollTabController,
                  children: getTabViews(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate(this.child);

  @override
  double get minExtent => 54.0; // 탭바의 최소 높이를 증가

  @override
  double get maxExtent => 54.0; // 탭바의 최대 높이를 증가

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
    return true; // 항상 다시 빌드하도록 설정
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
