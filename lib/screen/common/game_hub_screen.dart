import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    Navigator.of(context).pop();
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
    final fallback = Container(
      color: theme.dividerColor.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          game.iconFallback ?? '🎮',
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (game.iconUrl.isEmpty)
                    fallback
                  else
                    CachedNetworkImage(
                      imageUrl: game.iconUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => fallback,
                    ),
                  if (isCommunity)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'COMMUNITY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(
                game.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
