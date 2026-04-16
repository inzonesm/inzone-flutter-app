import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/unity_game.dart';
import '../services/game_hub_service.dart';

/// A card in the game hub grid showing a game's thumbnail, title, and state.
class GameCard extends StatelessWidget {
  final UnityGame game;
  final VoidCallback onTap;

  const GameCard({super.key, required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = GameHubService.instance.getDownloadState(game);
    final hasUpdate = GameHubService.instance.hasUpdate(game);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  game.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: game.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: const Icon(Icons.videogame_asset, size: 40),
                          ),
                        )
                      : Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: const Icon(Icons.videogame_asset, size: 40),
                        ),

                  // State badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildBadge(state, hasUpdate, theme),
                  ),
                ],
              ),
            ),

            // Title + category
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${game.category} · ${game.sizeMb} MB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(GameDownloadState state, bool hasUpdate, ThemeData theme) {
    if (state == GameDownloadState.downloaded && !hasUpdate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Installed',
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (hasUpdate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Update',
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
