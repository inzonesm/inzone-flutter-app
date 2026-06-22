import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/components/live_players_indicator.dart';
import 'package:inzone/components/social_overlay/game_social_overlay.dart';
import 'package:inzone/components/social_overlay/social_actions_service.dart';
import 'package:inzone/components/social_overlay/social_bridge.dart';
import 'package:inzone/config/api_config.dart';
import 'package:inzone/data/community_game.dart';
import 'package:inzone/data/hub_game.dart';
import 'package:inzone/services/active_character_notifier.dart';
import 'package:inzone/services/community_game_service.dart';
import 'package:inzone/services/game_session_analytics.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simula_ads/simula_ads.dart';

/// Full-screen, TikTok-style community game player.
///
/// Renders the supplied [game] and lets the user slide vertically (up/down) to
/// move between the other games in the `html_games` Firestore collection, in
/// the same way the Astrocade game feed works. The playlist can be supplied up
/// front via [playlist]; otherwise the screen lazily fetches the full catalog.
class CommunityGameScreen extends StatefulWidget {
  final CommunityGame game;

  /// Optional pre-loaded list of community games to slide between. When null
  /// (or when it does not contain [game]) the screen fetches the catalog and
  /// merges the active game in.
  final List<CommunityGame>? playlist;

  const CommunityGameScreen({
    super.key,
    required this.game,
    this.playlist,
  });

  @override
  State<CommunityGameScreen> createState() => _CommunityGameScreenState();
}

class _CommunityGameScreenState extends State<CommunityGameScreen> {
  late final PageController _pageController;
  late List<HubGame> _games;
  int _currentIndex = 0;
  bool _loadingPlaylist = false;

  /// Accumulated vertical delta for edge-zone drag-to-navigate.
  double _edgeDragAccumulated = 0;

  @override
  void initState() {
    super.initState();
    // The app is locked to portrait globally (see main.dart), but some games
    // (e.g. BrowserQuest) require landscape and show a "rotate your device"
    // gate until the webview window is wider than tall. Allow landscape while
    // the full-screen game player is open so rotating the device actually
    // rotates the webview; dispose() restores the portrait-only default. This
    // toggle lives here — on the full-screen route — and not in
    // _CommunityGamePage, which is also embedded inline in the home feed and
    // must not rotate it.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _games = _buildInitialPlaylist();
    _currentIndex = _games
        .indexWhere((g) =>
            g.source == HubGameSource.community && g.id == widget.game.id)
        .clamp(0, _games.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    // Expand to the full roster (community + Simula) after the first frame so
    // setState/Provider access happen with a mounted, built context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFullPlaylist();
    });
  }

  /// The initial, instantly-rendered playlist is built from whatever community
  /// games we were handed (or just the active game). Simula games are merged in
  /// asynchronously by [_loadFullPlaylist].
  List<HubGame> _buildInitialPlaylist() {
    final provided = widget.playlist;
    final List<CommunityGame> base;
    if (provided != null && provided.isNotEmpty) {
      base = provided.any((g) => g.id == widget.game.id)
          ? List<CommunityGame>.from(provided)
          : [widget.game, ...provided];
    } else {
      base = [widget.game];
    }
    return base.map(HubGame.community).toList();
  }

  /// Fetch the full roster — every approved community game plus the Simula
  /// minigame catalog — so the user can slide through all of them. Community
  /// games come first (matching the Home/Hub grids), then Simula games.
  Future<void> _loadFullPlaylist() async {
    setState(() => _loadingPlaylist = true);

    final notifier = Provider.of<SimulaNotifier>(context, listen: false);

    Future<List<CommunityGame>> communityFuture() async {
      try {
        final all = await CommunityGameService.fetchAll();
        return all
            .where((g) => g.gameUrl.isNotEmpty && g.name.isNotEmpty)
            .toList();
      } catch (_) {
        return const [];
      }
    }

    Future<List<GameData>> simulaFuture() async {
      try {
        final response = await notifier.apiClient.fetchCatalog();
        return response.games;
      } catch (_) {
        return const [];
      }
    }

    try {
      final results = await Future.wait([communityFuture(), simulaFuture()]);
      if (!mounted) return;

      final community = results[0] as List<CommunityGame>;
      final simula = results[1] as List<GameData>;

      // Guarantee the active community game is present and keep it current.
      final orderedCommunity = community.any((g) => g.id == widget.game.id)
          ? community
          : <CommunityGame>[widget.game, ...community];

      final merged = <HubGame>[
        ...orderedCommunity.map(HubGame.community),
        ...simula.map(HubGame.simula),
      ];

      if (merged.isEmpty) {
        setState(() => _loadingPlaylist = false);
        return;
      }

      final newIndex = merged
          .indexWhere((g) =>
              g.source == HubGameSource.community && g.id == widget.game.id)
          .clamp(0, merged.length - 1);

      setState(() {
        _games = merged;
        _currentIndex = newIndex;
        _loadingPlaylist = false;
      });
      // Jump the controller to the active game without animating.
      if (_pageController.hasClients) {
        _pageController.jumpToPage(newIndex);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPlaylist = false);
    }
  }

  @override
  void dispose() {
    // Restore the app-wide portrait-only lock (see main.dart) now that the
    // game player is closing, so the rest of the app does not stay rotatable.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _exitToApp() async {
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  // -------------------------------------------------------------------
  // Edge-zone navigation helpers
  // -------------------------------------------------------------------

  /// Called at the end of a drag that started in the top or bottom edge zone.
  /// Navigates to the next or previous page based on velocity / displacement.
  void _navigateByEdgeDrag(double velocity) {
    const velocityThreshold = 300.0;
    const distanceThreshold = 60.0;
    final swipeUp = velocity < -velocityThreshold ||
        _edgeDragAccumulated < -distanceThreshold;
    final swipeDown = velocity > velocityThreshold ||
        _edgeDragAccumulated > distanceThreshold;
    if (swipeUp && _currentIndex < _games.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (swipeDown && _currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// A transparent strip that intercepts vertical drags for page navigation.
  Widget _edgeZoneDetector() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) => _edgeDragAccumulated = 0,
      onVerticalDragUpdate: (d) => _edgeDragAccumulated += d.delta.dy,
      onVerticalDragEnd: (d) => _navigateByEdgeDrag(d.primaryVelocity ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTitle = _games.isEmpty
        ? widget.game.name
        : _games[_currentIndex.clamp(0, _games.length - 1)].name;

    return ColorfulSafeArea(
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Vertical, TikTok-style game feed.
            // NeverScrollableScrollPhysics disables the default full-screen
            // drag; edge-zone GestureDetectors below handle navigation so
            // that center-of-screen drags reach the game webview unobstructed.
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _games.length,
              onPageChanged: (index) {
                if (!mounted) return;
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final hub = _games[index];
                final isActive = index == _currentIndex;
                if (hub.source == HubGameSource.community) {
                  return _CommunityGamePage(
                    key: ValueKey('community-${hub.id}'),
                    game: hub.communityGame!,
                    isActive: isActive,
                    onClose: _exitToApp,
                  );
                }
                return _SimulaGamePage(
                  key: ValueKey('simula-${hub.id}'),
                  game: hub.simulaGame!,
                  isActive: isActive,
                  onClose: _exitToApp,
                );
              },
            ),

            // Edge-zone drag strips for page navigation.
            // Only the top and bottom 18 % of the screen trigger swipe-to-
            // next-game; the center is left untouched so games can handle
            // their own vertical gestures freely.
            if (_games.length > 1) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.18,
                child: _edgeZoneDetector(),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.18,
                child: _edgeZoneDetector(),
              ),
            ],

            // Title + back button overlay (no solid bar — a soft scrim only).
            _GameTopOverlay(
              title: activeTitle,
              onBack: () => unawaited(_exitToApp()),
            ),

            // Subtle hint that more games live above/below (only when >1 game).
            // Decorative only — must never intercept touches (the social
            // overlay button can be dragged to this edge).
            if (_games.length > 1)
              const Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: IgnorePointer(child: _SlideHint()),
              ),

            if (_loadingPlaylist)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Loading more games…',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight up/down chevrons hinting that the feed scrolls vertically.
class _SlideHint extends StatelessWidget {
  const _SlideHint();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.keyboard_arrow_up, color: Colors.white24, size: 22),
        SizedBox(height: 240),
        Icon(Icons.keyboard_arrow_down, color: Colors.white24, size: 22),
      ],
    );
  }
}

/// The title/back overlay shown on top of every game. Uses a translucent
/// gradient scrim instead of a solid app bar so it does not draw a black bar
/// around the title text.
class _GameTopOverlay extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _GameTopOverlay({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    // Only the back button may intercept touches here. This overlay sits
    // above the game pages in the screen-level Stack, so a hit-testable
    // gradient Container would swallow every tap in the top strip —
    // including taps meant for the social overlay button drawn inside
    // _CommunityGamePage. The scrim and title are decorative, so they are
    // wrapped in IgnorePointer and taps pass through to the game page.
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: IgnorePointer(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single playable community game inside the vertical feed. Owns its own
/// webview, InZone SDK bridge, and analytics session.
class _CommunityGamePage extends StatefulWidget {
  final CommunityGame game;
  final bool isActive;
  final Future<void> Function() onClose;

  /// True when this page is embedded inside a scrolling parent (the home
  /// feed's `InlineCommunityGameCard`). In that case the webview must claim
  /// vertical drags so center-of-game gestures reach the game instead of
  /// scrolling the feed. The full-screen player leaves this false because its
  /// PageView is already `NeverScrollableScrollPhysics` and edge zones handle
  /// navigation.
  final bool embeddedInFeed;

  const _CommunityGamePage({
    super.key,
    required this.game,
    required this.isActive,
    required this.onClose,
    this.embeddedInFeed = false,
  });

  @override
  State<_CommunityGamePage> createState() => _CommunityGamePageState();
}

class _CommunityGamePageState extends State<_CommunityGamePage> {
  static const String _fixtureAssetPath =
      'assets/html/social_loop_tap_targets.html';

  InAppWebViewController? _controller;
  bool _isLoading = true;
  String _loadError = '';
  late final bool _useLocalFixture;
  late final Future<String> _fixtureHtmlFuture;
  late final String _sessionId;
  late final String _backendBaseUrl;
  late final String? _playerId;
  late final String? _gameKey;
  late final DateTime _sessionOpenedAt;
  Future<void>? _sessionEndFuture;
  int _sessionCoinsSpent = 0;
  String? _lastSharedChallengeKey;

  // Social overlay: floating share button drawn over every community game
  // (send challenge / open chat / share score to InZone). The bridge holds
  // the latest score teed from the InZoneSDK `postScore` action.
  final SocialBridge _socialBridge = SocialBridge();
  late final SocialActionsService _socialActions =
      SocialActionsService(game: widget.game);

  @override
  void initState() {
    super.initState();
    _useLocalFixture = _isLocalFixtureUrl(widget.game.gameUrl);
    _fixtureHtmlFuture = _useLocalFixture
        ? rootBundle.loadString(_fixtureAssetPath)
        : Future.value('');
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _sessionOpenedAt = DateTime.now();
    _backendBaseUrl = _resolveBackendBaseUrl();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim();
    _playerId = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : null;
    final key = widget.game.gameKey?.trim();
    _gameKey = key != null && key.isNotEmpty ? key : null;
    // If the game has no key yet, generate one and persist it.
    if (_gameKey == null && widget.game.id.isNotEmpty) {
      unawaited(_ensureGameKey());
    }
    unawaited(_recordSessionStart());
  }

  @override
  void dispose() {
    unawaited(_recordSessionEnd());
    super.dispose();
  }

  bool _isLocalFixtureUrl(String gameUrl) {
    final normalized = gameUrl.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'inzone-test://social-loop' ||
        normalized == 'asset://social-loop-tap-targets';
  }

  String _resolveBackendBaseUrl() {
    return ApiConfig.baseUrl.trim();
  }

  Future<void> _ensureGameKey() async {
    try {
      final generated = await CommunityGameService.ensureGameKey(
        gameId: widget.game.id,
        uploaderId: widget.game.uploaderId,
      );
      if (mounted && generated.isNotEmpty) {
        _gameKey = generated;
      }
    } catch (e) {
      debugPrint('Failed to ensure gameKey: $e');
    }
  }

  Future<Map<String, dynamic>> _handleSocialLoopAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final overrideBaseUrl = _extractBackendBaseUrl(payload);
    final client = _SocialLoopBackendClient(
      baseUrl: overrideBaseUrl ?? _backendBaseUrl,
      gameKey: _gameKey,
    );

    Map<String, dynamic> mergePayload(Map<String, dynamic> extra) {
      return {
        'gameId': widget.game.id,
        'gameName': widget.game.name,
        'gameKey': _gameKey,
        'sessionId': _sessionId,
        'userId': _playerId,
        'playerId': _playerId,
        ...payload,
        ...extra,
      };
    }

    switch (action) {
      case 'getConfig':
        return {
          'success': true,
          'data': {
            'gameId': widget.game.id,
            'gameName': widget.game.name,
            'gameKey': _gameKey,
            'sessionId': _sessionId,
            'userId': _playerId,
            'backendBaseUrl': _backendBaseUrl,
            'fixtureMode': _useLocalFixture,
          },
        };
      case 'openSocialScreen':
        return client.openSocialScreen(mergePayload({}));
      case 'gameState':
        return client.gameState(mergePayload({}));
      case 'dashboard':
        return client.dashboard(mergePayload({}));
      case 'postScore':
        // Tee the score into the social overlay so its share flows can
        // include it. Games that never call postScore still work — the
        // overlay falls back to score-less messages. We tee both the request
        // payload and the normalized backend response (which carries the
        // canonical value/best).
        _socialBridge.recordScoreFromMap(payload);
        final postScoreResponse = await client.postScore(mergePayload({}));
        _socialBridge.recordScoreFromResponse(postScoreResponse);
        return postScoreResponse;
      case 'sendChallenge':
        _socialBridge.recordScoreFromMap(payload);
        final response = await client.sendChallenge(mergePayload({}));
        _socialBridge.recordScoreFromResponse(response);
        unawaited(_shareFromSendChallengeResponse(response));
        return response;
      case 'shareCard':
        // share-card was merged into send-challenge; route legacy calls there
        _socialBridge.recordScoreFromMap(payload);
        return client.sendChallenge(mergePayload({}));
      case 'openChat':
        // open-chat carries the score inside `context: { score, ... }`.
        _socialBridge.recordScoreFromMap(payload);
        return client.openChat(mergePayload({}));
      case 'notifyScore':
        // Sent by the injected fetch/XHR interceptor for games that call the
        // REST endpoints directly instead of the SDK bridge methods.
        final scoreRequest = payload['request'];
        final scoreResponse = payload['response'];
        if (scoreRequest is Map) _socialBridge.recordScoreFromMap(scoreRequest);
        if (scoreResponse is Map) {
          _socialBridge.recordScoreFromResponse(scoreResponse);
        }
        return {'success': true};
      case 'notifyShare':
        final response = payload['response'] is Map
            ? Map<String, dynamic>.from(payload['response'] as Map)
            : <String, dynamic>{};
        if (response.isNotEmpty) {
          unawaited(_shareFromSendChallengeResponse(response));
        }
        return {'success': true};
      case 'purchaseCoinTier':
        final coins = (payload['coins'] as num?)?.toInt();
        if (coins == null) {
          throw ArgumentError('coins is required for purchaseCoinTier');
        }
        final response = await client.purchaseCoinTier(
            coins, mergePayload({'coins': coins}));
        _sessionCoinsSpent += coins;
        unawaited(_recordSessionCoinSpend(coins));
        return response;
      case 'close':
        await widget.onClose();
        return {'success': true};
      default:
        throw ArgumentError('Unknown social loop action: $action');
    }
  }

  String? _extractBackendBaseUrl(Map<String, dynamic> payload) {
    final raw = payload['backendBaseUrl']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  Future<void> _recordSessionStart() async {
    final userId = _playerId;
    if (userId == null) return;

    try {
      await GameSessionAnalytics.recordSessionStart(
        gameId: widget.game.id,
        sessionId: _sessionId,
        userId: userId,
        openedAt: _sessionOpenedAt,
        gameName: widget.game.name,
      );
    } catch (_) {
      // Session analytics must not block game playback.
    }
  }

  Future<void> _recordSessionCoinSpend(int coins) async {
    if (coins <= 0) return;
    final userId = _playerId;
    if (userId == null) return;

    try {
      await GameSessionAnalytics.recordSessionCoinSpend(
        gameId: widget.game.id,
        sessionId: _sessionId,
        coins: coins,
      );
    } catch (_) {
      // The final session write will persist the total if this update fails.
    }
  }

  Future<void> _recordSessionEnd() {
    final ongoing = _sessionEndFuture;
    if (ongoing != null) return ongoing;

    final userId = _playerId;
    if (userId == null) {
      return Future.value();
    }

    final closedAt = DateTime.now();
    final future = GameSessionAnalytics.recordSessionEnd(
      gameId: widget.game.id,
      sessionId: _sessionId,
      userId: userId,
      openedAt: _sessionOpenedAt,
      closedAt: closedAt,
      coinsSpent: _sessionCoinsSpent,
      gameName: widget.game.name,
    );
    _sessionEndFuture = future.catchError((_) {
      // The session should fail quietly if Firestore is unavailable.
    });
    return _sessionEndFuture!;
  }

  Future<void> _shareFromSendChallengeResponse(
      Map<String, dynamic> response) async {
    final shareText =
        CommunityGameService.buildShareTextFromSendChallenge(response);
    if (shareText == null || shareText.isEmpty) return;

    final shareKey =
        CommunityGameService.extractShareKeyFromSendChallenge(response);
    if (shareKey != null && shareKey.isNotEmpty) {
      if (shareKey == _lastSharedChallengeKey) return;
      _lastSharedChallengeKey = shareKey;
    }

    final subject =
        CommunityGameService.buildShareSubjectFromSendChallenge(response);
    final params = (subject == null || subject.isEmpty)
        ? ShareParams(text: shareText)
        : ShareParams(text: shareText, subject: subject);

    await SharePlus.instance.share(params);
  }

  String _bridgeInjectionScript() {
    final config = jsonEncode({
      'gameId': widget.game.id,
      'gameName': widget.game.name,
      'gameKey': _gameKey,
      'sessionId': _sessionId,
      'userId': _playerId,
      'backendBaseUrl': _backendBaseUrl,
      'fixtureMode': _useLocalFixture,
      'gameUrl': widget.game.gameUrl,
    });

    return '''
      (function () {
        const config = $config;
        window.__INZONE_SOCIAL_LOOP_CONFIG__ = config;

        if (window.InZoneSDK && window.InZoneSDK.__inzoneInjected) {
          window.InZoneSDK.config = config;
          window.dispatchEvent(new CustomEvent('inzone:sdk-ready', { detail: config }));
          return;
        }

        const callBridge = (action, payload) => {
          if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) {
            return Promise.reject(new Error('InZone bridge is unavailable'));
          }
          return window.flutter_inappwebview.callHandler('socialLoop', {
            action: action,
            payload: payload || {},
          });
        };

        window.InZoneSDK = {
          __inzoneInjected: true,
          config: config,
          getConfig: function () {
            return Promise.resolve(config);
          },
          openSocialScreen: function (payload) {
            return callBridge('openSocialScreen', payload);
          },
          gameState: function (payload) {
            return callBridge('gameState', payload);
          },
          dashboard: function (payload) {
            return callBridge('dashboard', payload);
          },
          postScore: function (payload) {
            return callBridge('postScore', payload);
          },
          sendChallenge: function (payload) {
            return callBridge('sendChallenge', payload);
          },
          shareCard: function (payload) {
            return callBridge('shareCard', payload);
          },
          openChat: function (payload) {
            return callBridge('openChat', payload);
          },
          purchaseCoinTier: function (coins, payload) {
            return callBridge('purchaseCoinTier', Object.assign({ coins: coins }, payload || {}));
          },
          close: function () {
            return callBridge('close', {});
          },
        };

        if (!window.__INZONE_SOCIAL_LOOP_INTERCEPTOR__) {
          window.__INZONE_SOCIAL_LOOP_INTERCEPTOR__ = true;

          // send-challenge feeds the native share sheet (existing behavior).
          const isShareEndpoint = (url) =>
            !!url && url.indexOf('/api/game-sdk/send-challenge') !== -1;

          // Endpoints whose request/response can carry a score. Games that talk
          // to the REST API directly (instead of the SDK bridge methods) are
          // captured here so the social overlay still learns the score.
          const isScoreEndpoint = (url) => {
            if (!url) return false;
            return url.indexOf('/api/game-sdk/post-score') !== -1 ||
              url.indexOf('/api/game-sdk/send-challenge') !== -1 ||
              url.indexOf('/api/game-sdk/progress/share') !== -1 ||
              url.indexOf('/api/game-sdk/open-chat') !== -1;
          };

          const parseBody = (body) => {
            if (!body || typeof body !== 'string') return null;
            try { return JSON.parse(body); } catch (e) { return null; }
          };

          const notifyShare = (data) => {
            try {
              callBridge('notifyShare', { response: data || {} });
            } catch (e) {
            }
          };

          const notifyScore = (request, response) => {
            try {
              callBridge('notifyScore', {
                request: request || null,
                response: response || null,
              });
            } catch (e) {
            }
          };

          if (window.fetch) {
            const originalFetch = window.fetch;
            window.fetch = function (input, init) {
              const url = typeof input === 'string' ? input : (input && input.url);
              const share = isShareEndpoint(url || '');
              const scored = isScoreEndpoint(url || '');
              const reqBody = scored ? parseBody(init && init.body) : null;
              return originalFetch.apply(this, arguments).then((resp) => {
                if (!share && !scored) return resp;
                try {
                  const cloned = resp.clone();
                  cloned.text().then((text) => {
                    let data = null;
                    try { data = JSON.parse(text); } catch (e) { }
                    if (scored) notifyScore(reqBody, data);
                    if (share) notifyShare(data || {});
                  });
                } catch (e) {
                }
                return resp;
              });
            };
          }

          if (window.XMLHttpRequest) {
            const originalOpen = window.XMLHttpRequest.prototype.open;
            const originalSend = window.XMLHttpRequest.prototype.send;

            window.XMLHttpRequest.prototype.open = function (method, url) {
              this.__inzone_url = url;
              return originalOpen.apply(this, arguments);
            };

            window.XMLHttpRequest.prototype.send = function (body) {
              const url = this.__inzone_url || '';
              const share = isShareEndpoint(url);
              const scored = isScoreEndpoint(url);
              if (share || scored) {
                const reqBody = scored
                  ? parseBody(typeof body === 'string' ? body : null)
                  : null;
                this.addEventListener('load', () => {
                  let data = null;
                  try { data = JSON.parse(this.responseText || '{}'); } catch (e) { }
                  if (scored) notifyScore(reqBody, data);
                  if (share) notifyShare(data || {});
                });
              }
              return originalSend.apply(this, arguments);
            };
          }
        }

        window.dispatchEvent(new CustomEvent('inzone:sdk-ready', { detail: config }));
      })();
    ''';
  }

  Widget _buildWebView(ThemeData theme, {String? initialHtml}) {
    return Stack(
      children: [
        InAppWebView(
          // When embedded in the scrolling home feed, claim vertical drags so
          // a drag that starts in the center of the game reaches the game
          // (instead of being stolen by the feed's scroll view). The feed is
          // still scrollable via the transparent edge strips that
          // `InlineCommunityGameCard` overlays on the top and bottom of the
          // game. The full-screen player passes embeddedInFeed=false so its
          // own edge-zone navigation keeps working unchanged.
          gestureRecognizers: widget.embeddedInFeed
              ? <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => VerticalDragGestureRecognizer(),
                  ),
                }
              : null,
          initialData: initialHtml == null
              ? null
              : InAppWebViewInitialData(
                  data: initialHtml,
                  baseUrl: WebUri('https://inzone.local'),
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                ),
          initialUrlRequest: initialHtml == null
              ? URLRequest(
                  url: WebUri(
                    _withServerUrl(widget.game.gameUrl, widget.game.serverUrl),
                  ),
                )
              : null,
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            iframeAllow: 'camera; microphone; geolocation; encrypted-media',
            iframeAllowFullscreen: true,
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            hardwareAcceleration: true,
            supportZoom: true,
            builtInZoomControls: false,
            displayZoomControls: false,
            useWideViewPort: true,
            loadWithOverviewMode: true,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            controller.addJavaScriptHandler(
              handlerName: 'socialLoop',
              callback: (args) async {
                final raw = args.isNotEmpty && args.first is Map
                    ? Map<String, dynamic>.from(args.first as Map)
                    : <String, dynamic>{};
                final action = raw['action']?.toString() ?? '';
                final payload = raw['payload'] is Map
                    ? Map<String, dynamic>.from(raw['payload'] as Map)
                    : <String, dynamic>{};
                return _handleSocialLoopAction(action, payload);
              },
            );
          },
          onLoadStart: (_, __) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _loadError = '';
            });
          },
          onLoadStop: (controller, __) async {
            if (!mounted) return;
            await controller.evaluateJavascript(
                source: _bridgeInjectionScript());
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
          },
          onReceivedError: (_, __, error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _loadError = 'Failed to load game: ${error.description}';
            });
          },
        ),
        // Home-feed embed only: transparent, hit-test-opaque strips over the
        // very top and bottom of the game. They claim no gesture of their own,
        // so a drag starting on an edge is not given to the game webview behind
        // them and instead falls through to the home feed's scroll view (an
        // ancestor), scrolling the feed with its normal physics. The center of
        // the game has no strip, so the webview's own vertical-drag recognizer
        // wins there and gameplay is never interrupted. These sit above the
        // webview but below the social overlay so the share button stays
        // tappable even when docked near an edge.
        if (widget.embeddedInFeed) ...[
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 56,
            child: _FeedScrollEdge(),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 64,
            child: _FeedScrollEdge(),
          ),
        ],
        if (_isLoading)
          Container(
            color: theme.canvasColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Loading ${widget.game.name}…',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        if (_loadError.isNotEmpty && !_isLoading)
          Container(
            color: theme.canvasColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Game',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _loadError,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadError = '';
                        _isLoading = true;
                      });
                      _controller?.reload();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        // Floating social button + menu (send challenge / open chat /
        // share score to InZone). Draggable with edge snapping; only
        // shown once the game has loaded successfully.
        if (!_isLoading && _loadError.isEmpty)
          GameSocialOverlay(
            bridge: _socialBridge,
            actions: _socialActions,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: Colors.black,
      child: _useLocalFixture
          ? FutureBuilder<String>(
              future: _fixtureHtmlFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child:
                        CircularProgressIndicator(color: theme.primaryColor),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Text(
                      'Failed to load social loop test page.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                return _buildWebView(theme, initialHtml: snapshot.data!);
              },
            )
          : _buildWebView(theme),
    );
  }
}

/// A fully interactive community game embedded directly inside a home-feed
/// post slot. This is styled to match the regular home-feed post cards: same
/// width, card color, corner radius and shadow, with a header that mirrors a
/// post's avatar+username row (the game icon + game title), an optional
/// description, and the live [_CommunityGamePage] as the card body.
class InlineCommunityGameCard extends StatelessWidget {
  final CommunityGame game;

  const InlineCommunityGameCard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    // Tall enough to be genuinely playable; capped so it never dominates the
    // whole viewport on short screens.
    final gameHeight = (screenHeight * 0.6).clamp(360.0, 620.0);
    final description = game.description.trim();
    final iconUrl = game.iconUrl.trim();

    return Padding(
      // Mirror the bottom spacing used by the regular post cards.
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        // Match the regular post card width (full width minus the 8px the feed
        // reserves on each side).
        width: MediaQuery.of(context).size.width - 8,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — mirrors the post card avatar+username row: the game icon
            // in the top-left circle and the game title beside it. No options
            // (three-dot) menu, per spec.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: iconUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: iconUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox(
                              width: 40,
                              height: 40,
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.sports_esports,
                              size: 40,
                            ),
                          )
                        : const Icon(Icons.sports_esports, size: 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textTheme.titleLarge?.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        // Live "N playing now" — hidden when nobody's in the game,
                        // same signal as the game-hub cards.
                        LivePlayersIndicator(
                          gameId: game.id,
                          builder: (context, players, pulse) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FadeTransition(
                                  opacity: pulse,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: kLivePlayersGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$players playing now',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kLivePlayersGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Optional game description — only shown when it has real text.
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
                child: Text(
                  description,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            // Live, interactive game body. Clip only the bottom corners so it
            // fits the card's rounded base.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(15),
              ),
              child: SizedBox(
                height: gameHeight,
                width: double.infinity,
                // embeddedInFeed makes the game claim gestures in its center
                // (so play is never interrupted by the feed scrolling under the
                // finger) while leaving its top/bottom edges free to scroll the
                // feed — see `_buildWebView`.
                child: _CommunityGamePage(
                  key: ValueKey('inline_game_${game.id}'),
                  game: game,
                  isActive: true,
                  embeddedInFeed: true,
                  onClose: () async {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A transparent strip placed over the very top and bottom of an inline
/// home-feed game. It is hit-test *opaque*, so it stops the drag from reaching
/// the game webview directly behind it, but it registers no gesture recognizer
/// of its own — which means the gesture falls through to the home feed's scroll
/// view (an ancestor) and scrolls the feed with its normal physics. The result:
/// dragging the center of the game plays the game, while dragging its top/bottom
/// edges scrolls the feed.
class _FeedScrollEdge extends StatelessWidget {
  const _FeedScrollEdge();

  @override
  Widget build(BuildContext context) {
    return const Listener(
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(),
    );
  }
}

/// Resolved character context used to launch a feed Simula game.
class _FeedCharacterContext {
  final String charId;
  final String charName;
  final String? charImage;
  final String? charDesc;

  const _FeedCharacterContext({
    required this.charId,
    required this.charName,
    this.charImage,
    this.charDesc,
  });
}

/// Session-scoped cache so every feed Simula game in one session uses the same
/// randomly chosen fallback character (rather than re-rolling per game).
_FeedCharacterContext? _cachedRandomFeedCharacter;

/// Append `?serverUrl=…` to a multiplayer game's [gameUrl] so the embedded
/// client can read it from `window.location.search` and dial the right
/// WebSocket backend. Without this, multiplayer clients (e.g. BrowserQuest)
/// fall back to their baked-in default host (`localhost`) and fail to connect.
///
/// This mirrors the InZone web portal's `withServerUrl` helper so games behave
/// identically in the app and on the web. [serverUrl] is empty for
/// single-player games, in which case [gameUrl] is returned unchanged.
String _withServerUrl(String gameUrl, String serverUrl) {
  if (gameUrl.isEmpty || serverUrl.isEmpty) return gameUrl;
  try {
    final uri = Uri.parse(gameUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['serverUrl'] = serverUrl;
    return uri.replace(queryParameters: params).toString();
  } catch (_) {
    final separator = gameUrl.contains('?') ? '&' : '?';
    return '$gameUrl${separator}serverUrl=${Uri.encodeComponent(serverUrl)}';
  }
}

String? _firstNonEmptyField(List<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

/// Decide which character a feed Simula game should launch with.
///
/// Primary choice is the character the user most recently interacted with
/// ([ActiveCharacterNotifier]). When none has been chosen yet, the default
/// "InZone" placeholder has no avatar — which renders as a grayed-out box in
/// the game — so we instead pick a random real character (one that actually has
/// a profile image) from the `popularCharacters` collection. If that lookup
/// fails we fall back to whatever the notifier provides.
Future<_FeedCharacterContext> _resolveFeedCharacter(
  ActiveCharacterNotifier active,
) async {
  if (active.hasActiveCharacter) {
    return _FeedCharacterContext(
      charId: active.charID,
      charName: active.charName,
      charImage: active.charImage,
      charDesc: active.charDesc,
    );
  }

  final cached = _cachedRandomFeedCharacter;
  if (cached != null) return cached;

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('popularCharacters')
        .orderBy('numberOfChats', descending: true)
        .limit(100)
        .get();

    final withImages = snapshot.docs.where((doc) {
      final data = doc.data();
      final image = _firstNonEmptyField([
        data['profile_picture_url'],
        data['profilePicture'],
        data['profile_picture'],
        data['avatar'],
      ]);
      return image != null && image.isNotEmpty;
    }).toList();

    if (withImages.isNotEmpty) {
      final doc = withImages[Random().nextInt(withImages.length)];
      final data = doc.data();
      final chosen = _FeedCharacterContext(
        charId: doc.id,
        charName: _firstNonEmptyField([
              data['name'],
              data['displayName'],
              data['username'],
            ]) ??
            'AI Character',
        charImage: _firstNonEmptyField([
          data['profile_picture_url'],
          data['profilePicture'],
          data['profile_picture'],
          data['avatar'],
        ]),
        charDesc: _firstNonEmptyField([
          data['personality'],
          data['greeting'],
          data['description'],
        ]),
      );
      _cachedRandomFeedCharacter = chosen;
      return chosen;
    }
  } catch (_) {
    // Fall through to the notifier default below.
  }

  return _FeedCharacterContext(
    charId: active.charID,
    charName: active.charName,
    charImage: active.charImage,
    charDesc: active.charDesc,
  );
}


class _SimulaGamePage extends StatefulWidget {
  final GameData game;
  final bool isActive;
  final Future<void> Function() onClose;

  const _SimulaGamePage({
    super.key,
    required this.game,
    required this.isActive,
    required this.onClose,
  });

  @override
  State<_SimulaGamePage> createState() => _SimulaGamePageState();
}

class _SimulaGamePageState extends State<_SimulaGamePage> {
  InAppWebViewController? _controller;
  String? _iframeUrl;
  bool _resolving = true;
  bool _webLoading = true;
  String _error = '';
  bool _resolved = false;

  late final String _sessionId;
  late final DateTime _sessionOpenedAt;
  late final String? _playerId;
  Future<void>? _sessionEndFuture;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _sessionOpenedAt = DateTime.now();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim();
    _playerId = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : null;
    unawaited(_recordSessionStart());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolve the iframe once, after the providers/MediaQuery are available.
    if (!_resolved) {
      _resolved = true;
      unawaited(_resolveIframe());
    }
  }

  @override
  void dispose() {
    unawaited(_recordSessionEnd());
    super.dispose();
  }

  Future<void> _resolveIframe() async {
    if (!mounted) return;
    setState(() {
      _resolving = true;
      _error = '';
    });

    final notifier = Provider.of<SimulaNotifier>(context, listen: false);
    final session = notifier.sessionId;
    if (session == null || session.isEmpty) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = 'Session not available. Pull to retry.';
      });
      return;
    }

    final active = Provider.of<ActiveCharacterNotifier>(
      context,
      listen: false,
    );
    final size = MediaQuery.of(context).size;

    // Resolve the character context: the user's last-used character if one
    // exists, otherwise a random AI character so the avatar box is never the
    // grayed-out default placeholder.
    final character = await _resolveFeedCharacter(active);
    if (!mounted) return;

    try {
      final response = await notifier.apiClient.getMinigame(
        gameType: widget.game.id,
        sessionId: session,
        w: size.width.toInt() + 5,
        h: size.height.toInt() + 5,
        charId: character.charId,
        charName: character.charName,
        charImage: character.charImage ?? '',
        charDesc: character.charDesc,
        messages: [
          Message(
            role: 'assistant',
            content:
                'Current game is ${widget.game.id}. Keep responses concise and useful for this specific game context.',
          ),
        ],
        delegateChar: true,
      );
      if (!mounted) return;
      final url = response.iframeUrl;
      if (url.isEmpty) {
        setState(() {
          _resolving = false;
          _error = 'This game is unavailable right now.';
        });
        return;
      }
      setState(() {
        _iframeUrl = url;
        _resolving = false;
        _webLoading = true;
      });
      // If the webview is already alive (a retry), load the new URL directly.
      if (_controller != null) {
        unawaited(_controller!.loadUrl(
          urlRequest: URLRequest(url: WebUri(url)),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = 'Failed to load game. Please try again.';
      });
    }
  }

  Future<void> _recordSessionStart() async {
    final userId = _playerId;
    if (userId == null) return;
    try {
      await GameSessionAnalytics.recordSessionStart(
        gameId: widget.game.id,
        sessionId: _sessionId,
        userId: userId,
        openedAt: _sessionOpenedAt,
        gameName: widget.game.name,
      );
    } catch (_) {
      // Analytics must never block playback.
    }
  }

  Future<void> _recordSessionEnd() {
    final ongoing = _sessionEndFuture;
    if (ongoing != null) return ongoing;

    final userId = _playerId;
    if (userId == null) return Future.value();

    final future = GameSessionAnalytics.recordSessionEnd(
      gameId: widget.game.id,
      sessionId: _sessionId,
      userId: userId,
      openedAt: _sessionOpenedAt,
      closedAt: DateTime.now(),
      coinsSpent: 0,
      gameName: widget.game.name,
    );
    _sessionEndFuture = future.catchError((_) {
      // Fail quietly if Firestore is unavailable.
    });
    return _sessionEndFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showLoading = _resolving || (_iframeUrl != null && _webLoading);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          if (_iframeUrl != null)
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_iframeUrl!)),
              initialSettings: InAppWebViewSettings(
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: 'camera; microphone; geolocation; encrypted-media',
                iframeAllowFullscreen: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                hardwareAcceleration: true,
                supportZoom: true,
                builtInZoomControls: false,
                displayZoomControls: false,
                useWideViewPort: true,
                loadWithOverviewMode: true,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStart: (_, __) {
                if (!mounted) return;
                setState(() => _webLoading = true);
              },
              onLoadStop: (_, __) {
                if (!mounted) return;
                setState(() => _webLoading = false);
              },
              onReceivedError: (_, __, error) {
                if (!mounted) return;
                setState(() {
                  _webLoading = false;
                  _error = 'Failed to load game: ${error.description}';
                });
              },
            ),
          if (showLoading && _error.isEmpty)
            Container(
              color: theme.canvasColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Loading ${widget.game.name}…',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          if (_error.isNotEmpty)
            Container(
              color: theme.canvasColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error Loading Game',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => unawaited(_resolveIframe()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialLoopBackendClient {
  _SocialLoopBackendClient({required this.baseUrl, required this.gameKey});

  final String baseUrl;
  final String? gameKey;

  Future<Map<String, dynamic>> openSocialScreen(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/open-social-screen', payload,
        attachGameKey: false);
  }

  Future<Map<String, dynamic>> gameState(Map<String, dynamic> payload) {
    return _getJson('/api/game-sdk/game-state', payload, attachGameKey: true);
  }

  Future<Map<String, dynamic>> dashboard(Map<String, dynamic> payload) {
    return _getJson('/api/game-sdk/dashboard', payload, attachGameKey: true);
  }

  Future<Map<String, dynamic>> postScore(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/post-score', payload, attachGameKey: false);
  }

  Future<Map<String, dynamic>> sendChallenge(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/send-challenge', payload,
        attachGameKey: false);
  }

  Future<Map<String, dynamic>> shareCard(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/share-card', payload, attachGameKey: false);
  }

  Future<Map<String, dynamic>> openChat(Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/open-chat', payload, attachGameKey: false);
  }

  Future<Map<String, dynamic>> purchaseCoinTier(
      int coins, Map<String, dynamic> payload) {
    return _postJson('/api/game-sdk/coins/tier-$coins', payload,
        attachGameKey: true);
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, dynamic> payload, {
    required bool attachGameKey,
  }) async {
    final uri = _buildUri(path, payload);
    final response =
        await http.get(uri, headers: _headers(attachGameKey: attachGameKey));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    required bool attachGameKey,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final body = Map<String, dynamic>.from(payload);
    if (attachGameKey && gameKey != null && gameKey!.isNotEmpty) {
      body['gameKey'] = gameKey;
    }
    final response = await http.post(
      uri,
      headers: _headers(attachGameKey: attachGameKey),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Uri _buildUri(String path, Map<String, dynamic> payload) {
    final query = Map<String, String>.fromEntries(
      payload.entries
          .where((entry) => entry.value != null)
          .map((entry) => MapEntry(entry.key, entry.value.toString())),
    );
    if (gameKey != null && gameKey!.isNotEmpty) {
      query.putIfAbsent('gameKey', () => gameKey!);
    }
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({required bool attachGameKey}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (attachGameKey && gameKey != null && gameKey!.isNotEmpty) {
      headers['X-Game-Key'] = gameKey!;
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = decoded is Map<String, dynamic>
          ? decoded['error']?.toString() ?? 'Request failed'
          : 'Request failed';
      throw Exception(errorMessage);
    }
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'success': true, 'data': decoded};
  }
}
