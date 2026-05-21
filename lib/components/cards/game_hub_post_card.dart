import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inzone/data/community_game.dart';
import 'package:inzone/data/hub_game.dart';
import 'package:inzone/services/community_game_service.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:simula_ads/simula_ads.dart';

class GameHubPostCard extends StatelessWidget {
  final HubGame game;
  final VoidCallback onPlay;

  const GameHubPostCard({
    super.key,
    required this.game,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final titleColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7);
    final borderColor = theme.dividerColor.withValues(alpha: 0.5);
    final isCommunity = game.source == HubGameSource.community;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.blueGradient,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sports_esports,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Game Hub',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          isCommunity ? 'Community game' : 'Featured game',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Container(
                  color: AppColors.lightGrey,
                  child: game.iconUrl.isEmpty
                      ? _FallbackIcon(fallback: game.iconFallback)
                      : CachedNetworkImage(
                          imageUrl: game.iconUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: titleColor,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) =>
                              _FallbackIcon(fallback: game.iconFallback),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    if (game.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        game.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final String? fallback;
  const _FallbackIcon({this.fallback});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        fallback ?? '🎮',
        style: const TextStyle(fontSize: 56),
      ),
    );
  }
}

class GameHubSheet extends StatefulWidget {
  final ValueChanged<HubGame> onPlay;
  const GameHubSheet({super.key, required this.onPlay});

  @override
  State<GameHubSheet> createState() => _GameHubSheetState();
}

class _GameHubSheetState extends State<GameHubSheet> {
  List<HubGame> _games = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    final notifier = Provider.of<SimulaNotifier>(context, listen: false);

    Future<List<GameData>> simulaFuture() async {
      try {
        final response = await notifier.apiClient.fetchCatalog();
        return response.games;
      } catch (_) {
        return const [];
      }
    }

    Future<List<CommunityGame>> communityFuture() async {
      try {
        return await CommunityGameService.fetchAll();
      } catch (_) {
        return const [];
      }
    }

    final results = await Future.wait([simulaFuture(), communityFuture()]);
    if (!mounted) return;

    final simula = (results[0] as List<GameData>).map(HubGame.simula);
    final community =
        (results[1] as List<CommunityGame>).map(HubGame.community);
    final merged = <HubGame>[...community, ...simula];

    setState(() {
      _games = merged;
      _loading = false;
      _error = merged.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom + 16;

    Widget content;
    if (_loading) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
      );
    } else if (_error || _games.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.textTheme.bodyMedium?.color,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'No games are available right now. Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadCatalog,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final game in _games) ...[
            GameHubPostCard(
              game: game,
              onPlay: () => widget.onPlay(game),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}
