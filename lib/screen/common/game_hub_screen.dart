import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Games updated on or after this date also join the Trending row, even when
  // they fall outside the newest-14 (mirrors the web hub). Midnight July 7,
  // 2026 UTC.
  static final DateTime _trendingUpdatedSince = DateTime.utc(2026, 7, 7);

  // Name keywords that bucket a game into the "Sports" row (mirrors the web hub).
  static final RegExp _sportsRe = RegExp(
    r'golf|basket|soccer|football|\bball\b|8ball|kick|fighter|box|dunk|hopper|tennis|pool|gladi|sport|goal|hoop|arena',
    caseSensitive: false,
  );

  // Live coin balance shown in the app bar (humanUsers/<uid>.balance).
  String _balance = '0';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _balanceSub;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _setupBalanceStream();
  }

  @override
  void dispose() {
    _balanceSub?.cancel();
    super.dispose();
  }

  void _setupBalanceStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _balanceSub = FirebaseFirestore.instance
        .collection('humanUsers')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final balance = doc.data()?['balance'];
      setState(() => _balance = balance?.toString() ?? '0');
    }, onError: (_) {
      if (mounted) setState(() => _balance = '0');
    });
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
          _CoinBalanceBadge(balance: _balance),
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
    final rows = _buildRows(_games);
    return CustomScrollView(
      slivers: [
        // Category shelves (horizontally scrolling), same as the web hub.
        for (final row in rows)
          SliverToBoxAdapter(
            child: _CategoryRow(
              title: row.title,
              games: row.games,
              onTap: _handleTap,
            ),
          ),
        // Full catalog below — every game, even ones already shown in a row.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
            child: Text(
              'All games',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, index) {
                final game = _games[index];
                return _GameHubTile(game: game, onTap: () => _handleTap(game));
              },
              childCount: _games.length,
            ),
          ),
        ),
      ],
    );
  }

  // Group the flat game list into the homepage rows (same logic as the web
  // hub): Trending = first 14, Sports = name-keyword match, Recommended = the
  // next 14. Games may appear in several rows and also in the "All games" grid
  // below — the overlap is intentional. Empty rows are dropped.
  List<({String title, List<HubGame> games})> _buildRows(List<HubGame> games) {
    if (games.isEmpty) return const [];
    final sports = games.where((g) => _sportsRe.hasMatch(g.name)).toList();
    // Newest 14 as before, plus any older game whose updatedAt is on/after the
    // cutoff (mirrors the web hub). The community list is already newest-first,
    // so time ordering is preserved.
    final trending = [
      ...games.take(14),
      ...games.skip(14).where((g) {
        final updated = g.updatedAt;
        return updated != null && !updated.isBefore(_trendingUpdatedSince);
      }),
    ];
    final restStart = (games.length - 14).clamp(0, 14);
    final recommended = games.skip(restStart).take(14).toList();
    final rows = <({String title, List<HubGame> games})>[
      (title: 'Trending', games: trending),
      (title: 'Sports', games: sports),
      (title: 'Recommended for you', games: recommended),
    ];
    return rows.where((r) => r.games.isNotEmpty).toList();
  }
}

// Coin/points pill — matches the design used on the Groups screen app bar
// (see CustomAppBar): a rounded card-colored pill with a primary-colored
// circular badge icon followed by the balance.
class _CoinBalanceBadge extends StatelessWidget {
  final String balance;
  const _CoinBalanceBadge({required this.balance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        height: 40,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.cardColor,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(
                Icons.local_police,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              balance,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// One horizontally-scrolling category shelf (Trending / Sports / …). Reuses the
// same _GameHubTile as the grid, just at a fixed width so several peek in view.
class _CategoryRow extends StatelessWidget {
  final String title;
  final List<HubGame> games;
  final ValueChanged<HubGame> onTap;
  const _CategoryRow({
    required this.title,
    required this.games,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final game = games[i];
              return SizedBox(
                width: 122,
                child: _GameHubTile(game: game, onTap: () => onTap(game)),
              );
            },
          ),
        ),
      ],
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
                        uploaderId: game.uploaderId,
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
