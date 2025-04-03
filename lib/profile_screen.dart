import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/base_profile_screen.dart';
import 'package:inzone/components/user_posts_tab.dart';
import 'package:inzone/components/followers_following_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/chat_screen.dart';
import 'package:inzone/human_chat_screen.dart';
import 'package:inzone/all_chats_screen.dart'; // For ChatUser class

import 'inzone_database.dart';

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
          } else {
          }
        } catch (e) {
        }
      } else {
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
          } else {
          }
        } catch (e) {
        }
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
            Map<String, dynamic>? followerProfile = await InZoneDatabase.getUserProfile(follower);
            if (followerProfile != null) {
              formattedFollowers.add({
                'id': follower,
                'username': followerProfile['username'] ?? '',
                'type': 'human'
              });
            }
          } catch (e) {
          }
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
            Map<String, dynamic>? followProfile = await InZoneDatabase.getUserProfile(follow);
            if (followProfile != null) {
              formattedFollowing.add({
                'id': follow,
                'username': followProfile['username'] ?? '',
                'type': 'human'
              });
            }
          } catch (e) {
          }
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
        const SnackBar(content: Text('Could not load user profile'))
      );
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
        Map<String, dynamic>? currentUserProfile = await InZoneDatabase.getCurrentUserProfile();
        
        if (currentUserProfile != null && currentUserProfile.containsKey('following')) {
          List<dynamic> currentUserFollowing = currentUserProfile['following'] ?? [];
          
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
          await InZoneDatabase.followUser(userId, await _getCurrentUserName(userId) );
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
          Map<String, dynamic>? currentUserProfile = await InZoneDatabase.getCurrentUserProfile();
          
          if (currentUserProfile != null && currentUserProfile.containsKey('following')) {
            // Update the community tab data with the new following list
            List<dynamic> currentUserFollowing = currentUserProfile['following'] ?? [];
            
            // Process the following list
            List<Map<String, dynamic>> formattedFollowing = [];
            for (var followedUser in currentUserFollowing) {
              if (followedUser is Map<String, dynamic>) {
                formattedFollowing.add(followedUser);
              } else if (followedUser is String) {
                formattedFollowing.add({
                  'id': followedUser,
                  'username': 'User',
                  'type': 'human'
                });
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${newFollowState ? 'follow' : 'unfollow'} user'))
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to ${newFollowState ? 'follow' : 'unfollow'} user'))
      );
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
    if (isAi){
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
    return Row(
      children: [
        // Show Follow button for both human and AI users
        Expanded(
          child: ElevatedButton(
            onPressed: toggleFollow,
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? Colors.white : Colors.blue,
              foregroundColor: isFollowing ? Colors.black : Colors.white,
              side: isFollowing ? BorderSide(color: Colors.grey.shade300) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: Text(isFollowing ? 'Following' : 'Follow'),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Message button is always shown
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              // Get current user ID
              String? currentUserId = await InZoneDatabase.getCurrentUserUid();
              if (currentUserId == null) {
                return; // Exit if no user is logged in
              }
              
              // Get the target user ID
              String targetUserId = getUserId();
              
              // Check if the profile is an AI user
              bool isAiUser = widget.isAI ;
              
              if (isAiUser) {
                // For AI users, navigate to ChatScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      userData: ChatUser(
                        name: name,
                        email: targetUserId,
                        chatId: null,
                      ),
                    ),
                  ),
                );
              } else {
                // For human users, create or open conversation
                
                // Create a consistent conversation ID that's the same for both users
                // Sort the IDs to ensure the same ID regardless of who initiates
                List<String> sortedIds = [currentUserId, targetUserId]..sort();
                String conversationId = "${sortedIds[0]}_${sortedIds[1]}";
                
                try {
                  // Check if conversation already exists
                  final conversationDoc = await FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(conversationId)
                      .get();
                  
                  if (!conversationDoc.exists) {
                    // Get current user's name
                    String currentUserName = await _getCurrentUserName(currentUserId);
                    
                    // Create new conversation document if it doesn't exist
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
                  
                  // Navigate to chat screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HumanChatScreen(
                        conversationId: conversationId,
                        otherUserName: name,
                        otherUserId: targetUserId,
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to open conversation. Please try again.'))
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Message'),
          ),
        ),
      ],
    );
  }
  
  // Helper method to get current user's name
  Future<String> _getCurrentUserName(String userId) async {
    String defaultName = "User";
    
    try {
      Map<String, dynamic>? userProfile = await InZoneDatabase.getUserProfile(userId);
      if (userProfile != null) {
        return userProfile["Name"] ?? userProfile["name"] ?? defaultName;
      }
    } catch (e) {
    }
    
    return defaultName;
  }

  @override
  PreferredSizeWidget? buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).canvasColor,
      centerTitle: true,
      title: const Text(
        "Profile",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      actions: [
        // Only show the popup menu for human users
        if (!widget.isAI)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onSelected: (value) async {
              if (value == 'remove_follower') {
                String? currentUserId = await InZoneDatabase.getCurrentUserUid();
                if (currentUserId != null) {
                  bool success = await InZoneDatabase.removeFromFollowers(getUserId());
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User removed from your followers'))
                    );
                    // Refresh the profile data
                    fetchUserProfile();
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'remove_follower',
                child: Text('Remove from followers'),
              ),
            ],
          ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Theme.of(context).canvasColor,
      ),
    );
  }
}