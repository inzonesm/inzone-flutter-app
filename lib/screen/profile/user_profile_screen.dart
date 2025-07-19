import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:inzone/components/cards/post_card.dart';
import 'package:inzone/components/profile/avatar_card.dart';
import 'package:inzone/components/profile/user_posts_tab.dart';
import 'package:inzone/components/ui/profile_appbar.dart';
import 'package:inzone/components/posts/shimmering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/data/inzone_avatar.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/screen/settings/settings_screen.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // State variables
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
  String? currentUserId;
  List<InZonePost> _posts = [];

  // Saved characters
  List<Map<String, String>> _savedCharacters = [];
  bool _areCharactersLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Get the current user ID
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
      await fetchUserProfile();
      await fetchUserPosts();
      await _fetchSavedCharacters();
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      isRefreshing = true;
    });

    try {
      await fetchUserProfile();
      await fetchUserPosts();
      await _fetchSavedCharacters();
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  Future<void> _fetchSavedCharacters() async {
    if (currentUserId == null) {
      if (mounted) {
        setState(() => _areCharactersLoading = false);
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(currentUserId!)
          .get();

      List<Map<String, String>> fetchedCharacters = [];
      if (userDoc.exists && userDoc.data()!.containsKey('savedCharacters')) {
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
          _areCharactersLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching saved characters on user profile screen: $e');
      if (mounted) {
        setState(() => _areCharactersLoading = false);
      }
    }
  }

  // Methods that were previously overridden from BaseProfileScreen
  String getUserId() {
    return currentUserId ?? '';
  }

  Widget buildActionButtons() {
    final theme = Theme.of(context);

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            context.push(
              Routes.settings,
            );
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
              FeatherIcons.settings,
              size: 18,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: GestureDetector(
            onTap: () {
              if (currentUserId == null) return;

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
                  fetchUserPosts();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[900]
                    : Colors.grey[100],
                border: Border.all(
                  color: theme.dividerColor,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Edit Profile',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Methods that were previously in BaseProfileScreen
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

      if (mounted) {
        setState(() {
          name = userProfile["name"] ?? userProfile["Name"] ?? "Unknown";
          username =
              userProfile["username"] ?? userProfile["Username"] ?? "Unknown";
          bio = userProfile["bio"] ?? userProfile["Bio"] ?? "";
          profileImageUrl = userProfile["profilePicture"] ??
              userProfile["ProfilePicture"] ??
              "";
          followersCount = followers.length;
          followingCount = following.length;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchUserPosts() async {
    String userId = getUserId();
    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final result = await InZoneDatabase.getUserPosts(userId);
      List<InZonePost> fetchedPosts = [];
      if (result != null) {
        fetchedPosts = result.map((json) => InZonePost.fromJson(json)).toList();
      }

      if (mounted) {
        setState(() {
          _posts = fetchedPosts;
          postCount = fetchedPosts.length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user posts: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show shimmering during initial loading or refresh
    // if (true) {
    if (isLoading || isRefreshing) {
      // Changed to always show shimmering
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Show dimmed content only during refresh (not initial load)
              if (isRefreshing && !isLoading)
                Opacity(
                  opacity: 0.3,
                  child: _buildMainContent(),
                ),
              // Shimmering overlay
              ProfileShimmering(context, false),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        slivers: [
          // Profile header
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
                savedCharacters: _savedCharacters,
                areCharactersLoading: _areCharactersLoading,
                onCharacterTap: (characterId, characterName, characterImage) {
                  context.pushNamed('chat',
                      extra: ChatUser(
                        name: characterName,
                        email: characterId,
                        chatId: null,
                        isHuman: false,
                        profilePictureURL: characterImage,
                      ));
                },
              ),
            ),
          ),

          // Posts list
          if (_posts.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(50.0),
                  child: Text(
                    'No posts found',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(15.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _posts.length) {
                      return const SizedBox(height: 100);
                    }
                    return Column(
                      children: [
                        PostCard(
                          post: _posts[index],
                          profileImageUrl: profileImageUrl,
                          showHue: false,
                          onTap: (postId) {},
                          inProfile: true,
                        ),
                      ],
                    );
                  },
                  childCount: _posts.length + 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// The below classes are kept as they were in the original file
class PersonalFeedScreen extends StatefulWidget {
  const PersonalFeedScreen({super.key});

  @override
  State<PersonalFeedScreen> createState() => _PersonalFeedScreenState();
}

class _PersonalFeedScreenState extends State<PersonalFeedScreen> {
  List<PostCard> posts = [];
  List<AvatarCard> avatarCards = [];
  bool isLoading = true;

  Future<void> getFeed({bool isRefresh = false}) async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await InZoneDatabase.getFeed();
      if (response != null &&
          response.containsKey('posts') &&
          response.containsKey('characters')) {
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
        isLoading = false;
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
        inProfile: true,
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
            child: CircularProgressIndicator(),
          )
        : Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: posts,
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
  bool isLoading = true;

  Future<void> getFeed({bool isRefresh = false}) async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await InZoneDatabase.getFeed();

      if (response != null &&
          response.containsKey('posts') &&
          response.containsKey('characters')) {
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
        isLoading = false;
      });
    }
  }

  void _addPostsToScreen(List<dynamic> fetchedPosts) async {
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
              child: CircularProgressIndicator(),
            ),
          )
        : Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: avatarCards,
              ),
            ),
          );
  }
}
