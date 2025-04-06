import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String bio;
  final int postCount;
  final int followingCount;
  final int followersCount;
  final Widget actionButtons;
  
  const ProfileHeader({
    super.key,
    required this.name,
    required this.bio,
    required this.postCount,
    required this.followingCount,
    required this.followersCount,
    required this.actionButtons,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 5.0, top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile picture
              CircleAvatar(
                radius: 35,
                child: RandomAvatar(name, height: 70, width: 70),
              ),
              const SizedBox(width: 16),
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat(postCount.toString(), 'Post'),
                    _buildStat(followingCount.toString(), 'Following'),
                    _buildStat(followersCount.toString(), 'Followers'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Username and bio
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            bio.isEmpty ? "No bio set yet" : bio,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          
          // Action buttons (follow/message or edit profile)
          actionButtons,
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
} 