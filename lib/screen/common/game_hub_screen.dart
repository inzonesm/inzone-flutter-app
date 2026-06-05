import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/live_players_indicator.dart';
import 'package:inzone/data/community_game.dart';
import 'package:inzone/data/hub_game.dart';
import 'package:inzone/services/community_game_service.dart';
import 'package:provider/provider.dart';
import 'package:simula_ads/simula_ads.dart';

class GameHubScreen extends StatefulWidget {
  final ValueChanged<HubGame> onPlay;
  const GameHubScreen({super.key, required this.onPlay});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
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

    final merged = <HubGame>[
      ...(results[1] as List<CommunityGame>).map(HubGame.community),
      ...(results[0] as List<GameData>).map(HubGame.simula),
    ];

    setState(() {
      _games = merged;
      _loading = false;
      _error = merged.isEmpty;
    });
  }

  void _handleTap(HubGame game) {
    // Keep the Game Hub in the navigation stack so backing out of a game
    // returns the user here (the screen they launched it from) rather than
    // jumping all the way back to Home.
    widget.onPlay(game);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: theme.canvasColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Game Hub',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadCatalog,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.textTheme.bodyLarge?.color,
        ),
      );
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(height: 12),
            Text(
              'No games available right now.',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadCatalog, child: const Text('Retry')),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: _games.length,
      itemBuilder: (_, index) {
        final game = _games[index];
        return _GameHubTile(game: game, onTap: () => _handleTap(game));
      },
    );
  }
}

class _GameHubTile extends StatelessWidget {
  final HubGame game;
  final VoidCallback onTap;
  const _GameHubTile({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCommunity = game.source == HubGameSource.community;
    // Community games show a live "N playing" badge; Simula catalog games keep
    // their static BETA/LIVE tag (they have no sessions to count).
    final badgeText =
        game.name.toLowerCase().contains('beta') ? 'BETA' : 'LIVE';
    final subtitle =
        game.description.isNotEmpty ? game.description : 'Tap to play';

    final fallback = ColoredBox(
      color: theme.dividerColor.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          game.iconFallback ?? '🎮',
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full-bleed cover image (or emoji fallback).
              if (game.iconUrl.isEmpty)
                fallback
              else
                CachedNetworkImage(
                  imageUrl: game.iconUrl,
                  fit: BoxFit.cover,
                  // No placeholder: the home screen pre-warms these icon URLs
                  // (see _warmTopImageCache), so they paint instantly from
                  // cache. A placeholder would force a fade-in on every build
                  // and on every reopen of the hub.
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  errorWidget: (_, __, ___) => fallback,
                ),
              // Gradient scrim so the title stays legible over the image —
              // no solid bar.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x14000000),
                      Color(0x59000000),
                    ],
                  ),
                ),
              ),
              // Badge in the top-left corner: live "N playing" for community
              // games (hidden when nobody's playing), static tag otherwise.
              Positioned(
                top: 8,
                left: 8,
                child: isCommunity
                    ? LivePlayersIndicator(
                        gameId: game.id,
                        builder: (context, count, pulse) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: pulse,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: kLivePlayersGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kLivePlayersGreen,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$count playing',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
              ),
              // Title + subtitle overlaid at the bottom of the image.
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.white70,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
