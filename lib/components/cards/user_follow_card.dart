import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:inzone/services/inzone_database.dart';

class UserFollowCard extends StatelessWidget {
  final String userId;
  final String username;
  final String userType;
  final String profileImageUrl;
  final bool isCurrentUser;
  final bool isFollowersTab;
  final VoidCallback? onUnfollow;
  final VoidCallback? onRemoveFollower;
  final VoidCallback onTap;

  const UserFollowCard({
    super.key,
    required this.userId,
    required this.username,
    required this.userType,
    required this.profileImageUrl,
    required this.isCurrentUser,
    required this.isFollowersTab,
    this.onUnfollow,
    this.onRemoveFollower,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDarkMode ? AppColors.darkSurfaceColor : AppColors.lightSurfaceColor;
    final textColor =
        isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile Image
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: userType == 'ai'
                      ? AppColors.primaryBlue.withOpacity(0.3)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: profileImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profileImageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        color: null, // Remove any color overlay
                        colorBlendMode:
                            BlendMode.srcOver, // Use default blend mode
                        memCacheWidth: 100, // Limit memory cache size
                        memCacheHeight: 100,
                        maxWidthDiskCache: 200, // Limit disk cache size
                        maxHeightDiskCache: 200,
                        placeholder: (context, url) => Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppColors.primaryBlue.withOpacity(0.6),
                            size: 24,
                          ),
                        ),
                        errorWidget: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppColors.primaryBlue.withOpacity(0.6),
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: AppColors.primaryBlue.withOpacity(0.6),
                          size: 28,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username
                  Text(
                    username.isEmpty ? 'Unknown User' : username,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // AI Badge or User Type
                  if (userType == 'ai')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue.withOpacity(0.1),
                            AppColors.lightBlue.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI User',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'User',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),

            // Action Buttons
            if (!isCurrentUser) ...[
              const SizedBox(width: 12),
              if (!isFollowersTab)
                // Unfollow button for following tab
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: TextButton(
                    onPressed: onUnfollow,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Unfollow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                )
              else
                // More options button for followers tab
                GestureDetector(
                  onTap: onRemoveFollower,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade800.withOpacity(0.3)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      FeatherIcons.moreVertical,
                      size: 20,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
