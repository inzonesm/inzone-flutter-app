import 'dart:async';
import 'dart:collection';
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
import 'package:inzone/components/social_overlay/game_score_reader.dart';
import 'package:inzone/components/social_overlay/game_social_overlay.dart';
import 'package:inzone/components/social_overlay/social_actions_service.dart';
import 'package:inzone/components/social_overlay/social_bridge.dart';
import 'package:inzone/config/api_config.dart';
import 'package:inzone/data/community_game.dart';
import 'package:inzone/data/hub_game.dart';
import 'package:inzone/router/app_route_observer.dart';
import 'package:inzone/services/active_character_notifier.dart';
import 'package:inzone/services/analytics_service.dart';
import 'package:inzone/services/community_game_service.dart';
import 'package:inzone/services/game_session_analytics.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simula_ads/simula_ads.dart';
import 'package:visibility_detector/visibility_detector.dart';

Future<void> _forwardLifecycleProductEvent({
  required AnalyticsService analyticsService,
  required String eventName,
  Map<String, Object?>? parameters,
  String? gameId,
  String? gameName,
  String? sessionId,
}) {
  return analyticsService.trackProductEvent(
    eventName,
    parameters: parameters,
    gameId: gameId,
    gameName: gameName,
    sessionId: sessionId,
  );
}

bool _isAppLifecycleActive(AppLifecycleState? state) {
  return state == AppLifecycleState.resumed;
}

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

class _CommunityGamePageState extends State<_CommunityGamePage>
    with WidgetsBindingObserver, RouteAware {
  static const String _fixtureAssetPath =
      'assets/html/social_loop_tap_targets.html';

  /// Injected at document-start (before the game boots) so WebGL games — Unity
  /// WebGL, Construct WebGL, etc. — render into a buffer that can be read back
  /// with `canvas.toDataURL()`. Without `preserveDrawingBuffer`, a WebGL canvas
  /// returns a blank image, which is why OCR could never see the score on those
  /// games. This is harmless to games that don't need it (they keep clearing
  /// their own buffer each frame) and does not affect the Construct 2 state
  /// read, so games that already work — like Dunk Shot — are unchanged.
  static const String _webglReadbackScript = r'''
(function () {
  try {
    if (window.__inzoneWebGLReadback) return;
    window.__inzoneWebGLReadback = true;
    var orig = HTMLCanvasElement.prototype.getContext;
    if (!orig) return;
    HTMLCanvasElement.prototype.getContext = function (type, attrs) {
      try {
        if (typeof type === 'string' && /webgl/i.test(type)) {
          attrs = attrs || {};
          if (attrs.preserveDrawingBuffer !== true) {
            attrs.preserveDrawingBuffer = true;
          }
        }
      } catch (e) {}
      return orig.call(this, type, attrs);
    };
  } catch (e) {}
})();
''';

  /// Makes HTML5 / Unity WebGL games fit the webview instead of being cut off
  /// or rendered at the wrong scale. Two problems are fixed here:
  ///
  /// 1. Many community games ship without a `<meta name="viewport">` tag, so
  ///    Android lays the page out at its 980px-wide legacy viewport instead of
  ///    the webview's real size. A `width=device-width` viewport meta is
  ///    injected (or an existing one normalized) so `window.innerWidth/Height`
  ///    report the actual view size the game should render at.
  /// 2. Games with fixed-size canvases / Unity containers (e.g. a 1280×720
  ///    build) overflow the view and get clipped. Known game containers are
  ///    pinned to the full viewport, and any canvas that overflows is scaled
  ///    back down to explicit, aspect-preserving pixel dimensions and
  ///    centered. Explicit sizing (instead of object-fit letterboxing) keeps
  ///    the canvas bounding rect equal to the visible game area, which is
  ///    what game engines use to translate touch coordinates — so the game
  ///    stays both fully visible and correctly tappable.
  ///
  /// The fit pass re-runs on resize/orientation change and on a few delayed
  /// retries, because most engines create or resize their canvas asynchronously
  /// after `load`. All work is no-op for games that already fit correctly.
  static const String _viewportFitScript = r'''
(function () {
  try {
    if (window.__inzoneViewportFit) return;
    window.__inzoneViewportFit = true;

    var ensureViewportMeta = function () {
      try {
        var head = document.head || document.getElementsByTagName('head')[0];
        if (!head) return;
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.setAttribute('name', 'viewport');
          head.appendChild(meta);
        }
        meta.setAttribute('content',
          'width=device-width, height=device-height, initial-scale=1.0, ' +
          'minimum-scale=1.0, maximum-scale=1.0, user-scalable=no, ' +
          'viewport-fit=cover');
      } catch (e) {}
    };

    var injectFitStyles = function () {
      try {
        if (document.getElementById('__inzone-fit-style')) return;
        if (!document.head && !document.documentElement) return;
        var style = document.createElement('style');
        style.id = '__inzone-fit-style';
        style.textContent =
          'html, body {' +
          '  margin: 0 !important; padding: 0 !important;' +
          '  width: 100% !important; height: 100% !important;' +
          '  overflow: hidden !important;' +
          '}' +
          '#unity-container, #unityContainer, #gameContainer,' +
          '#game-container, #game_container, #canvas-container,' +
          '.webgl-content {' +
          '  position: fixed !important; left: 0 !important; top: 0 !important;' +
          '  width: 100vw !important; height: 100vh !important;' +
          '  max-width: 100vw !important; max-height: 100vh !important;' +
          '  margin: 0 !important; transform: none !important;' +
          '}';
        (document.head || document.documentElement).appendChild(style);
      } catch (e) {}
    };

    var fitCanvas = function (c, vw, vh) {
      try {
        var rect = c.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) return;
        var alreadyFitted = c.getAttribute('data-inzone-fitted') === '1';
        var overflows =
          rect.width > vw + 1 || rect.height > vh + 1 ||
          rect.left < -1 || rect.top < -1 ||
          rect.right > vw + 1 || rect.bottom > vh + 1;
        // Once fitted, keep refitting on later passes (viewport/orientation
        // changes shrink the element below the overflow threshold).
        if (!overflows && !alreadyFitted) return;
        // Scale uniformly to fit the viewport using explicit pixel
        // dimensions, centered. Explicit sizing — as opposed to
        // object-fit letterboxing inside a 100vw×100vh element — keeps the
        // canvas's bounding rect identical to the visible game area, so
        // engines that map touch coordinates through
        // getBoundingClientRect()/offsetWidth (GameMaker, Construct, Unity
        // templates) keep translating input to the right in-game position.
        var aspect = (c.width > 0 && c.height > 0)
          ? c.width / c.height
          : rect.width / rect.height;
        if (!aspect || !isFinite(aspect)) return;
        var w = vw;
        var h = w / aspect;
        if (h > vh) {
          h = vh;
          w = h * aspect;
        }
        w = Math.floor(w);
        h = Math.floor(h);
        c.style.setProperty('width', w + 'px', 'important');
        c.style.setProperty('height', h + 'px', 'important');
        c.style.setProperty('max-width', 'none', 'important');
        c.style.setProperty('max-height', 'none', 'important');
        c.style.setProperty('position', 'fixed', 'important');
        c.style.setProperty('left', Math.floor((vw - w) / 2) + 'px', 'important');
        c.style.setProperty('top', Math.floor((vh - h) / 2) + 'px', 'important');
        c.style.setProperty('display', 'block', 'important');
        c.style.setProperty('margin', '0', 'important');
        c.setAttribute('data-inzone-fitted', '1');
      } catch (e) {}
    };

    var refit = function () {
      try {
        ensureViewportMeta();
        injectFitStyles();
        var vw = window.innerWidth;
        var vh = window.innerHeight;
        if (!vw || !vh) return;
        var canvases = document.getElementsByTagName('canvas');
        for (var i = 0; i < canvases.length; i++) {
          fitCanvas(canvases[i], vw, vh);
        }
      } catch (e) {}
    };
    window.__inzoneRefit = refit;

    // Engines create/resize their canvas asynchronously, so retry a few
    // times after the document settles rather than fitting only once.
    var schedule = function () {
      refit();
      setTimeout(refit, 500);
      setTimeout(refit, 1500);
      setTimeout(refit, 3000);
      setTimeout(refit, 6000);
    };
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', schedule);
    } else {
      schedule();
    }
    window.addEventListener('load', schedule);
    window.addEventListener('resize', function () { setTimeout(refit, 50); });
    window.addEventListener('orientationchange', function () {
      setTimeout(refit, 250);
    });

    // The meta tag can be injected as early as document-start; the rest waits
    // for the DOM.
    ensureViewportMeta();
  } catch (e) {}
})();
''';

  InAppWebViewController? _controller;
  bool _isLoading = true;
  String _loadError = '';
  late final bool _useLocalFixture;
  late final Future<String> _fixtureHtmlFuture;
  late final String _backendBaseUrl;
  late final String? _playerId;
  late final String? _gameKey;

  final AnalyticsService _analyticsService = AnalyticsService();
  late final GameSessionLifecycleCoordinator _lifecycle;
  String? _sessionId;
  DateTime? _sessionOpenedAt;

  Future<void>? _sessionEndFuture;
  int _sessionCoinsSpent = 0;
  String? _lastSharedChallengeKey;
  ModalRoute<dynamic>? _observedRoute;

  // Social overlay: floating share button drawn over every community game
  // (send challenge / open chat / share score to InZone). The bridge holds
  // the latest score teed from the InZoneSDK `postScore` action.
  final SocialBridge _socialBridge = SocialBridge();
  late final SocialActionsService _socialActions =
      SocialActionsService(game: widget.game);

  // Reads the score straight off the game's UI (DOM scrape, then OCR) for the
  // many third-party games that never call the SDK's postScore. Resolved on
  // demand when the share menu opens / a share action is tapped.
  late final GameScoreReader _scoreReader =
      GameScoreReader(controllerGetter: () => _controller);

  /// Returns the best score we can establish for the share flows: whatever the
  /// SDK already teed, refreshed with a live read of the on-screen value.
  Future<int?> _resolveLatestScore() async {
    try {
      final int? uiScore = await _scoreReader.read();
      if (uiScore != null) _socialBridge.recordUiScore(uiScore);
    } catch (_) {
      // Reading the UI is best-effort; fall back to whatever we already have.
    }
    return _socialBridge.latestScore;
  }

  /// Fold a UI-read score into an outgoing send-challenge / open-chat payload
  /// when the game itself didn't supply one. This is what makes those endpoints
  /// work for the Ultimate Game Stash (Construct 2) and Unity games, which
  /// never pass a score — the score is read from the game's runtime/UI instead.
  /// Games that already include a score are left untouched (no costly UI read).
  Future<Map<String, dynamic>> _withResolvedScore(
    Map<String, dynamic> outgoing, {
    required bool inContext,
  }) async {
    if (SocialBridge.scoreIn(outgoing) != null) return outgoing;
    final int? score = await _resolveLatestScore();
    if (score == null) return outgoing;
    final Map<String, dynamic> enriched = Map<String, dynamic>.from(outgoing)
      ..['score'] = score;
    if (inContext) {
      // open-chat builds its message from `context: { score, ... }`.
      final Map<String, dynamic> ctx = enriched['context'] is Map
          ? Map<String, dynamic>.from(enriched['context'] as Map)
          : <String, dynamic>{};
      ctx['score'] = score;
      enriched['context'] = ctx;
    }
    return enriched;
  }

  @override
  void initState() {
    super.initState();
    _useLocalFixture = _isLocalFixtureUrl(widget.game.gameUrl);
    _fixtureHtmlFuture = _useLocalFixture
        ? rootBundle.loadString(_fixtureAssetPath)
        : Future.value('');
    _backendBaseUrl = _resolveBackendBaseUrl();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim();
    _playerId = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : null;
    _lifecycle = GameSessionLifecycleCoordinator(
      gameId: widget.game.id,
      gameName: widget.game.name,
      creatorId: widget.game.uploaderId,
      source: 'community',
      trackEvent: (
        eventName, {
        parameters,
        gameId,
        gameName,
        sessionId,
      }) {
        return _forwardLifecycleProductEvent(
          analyticsService: _analyticsService,
          eventName: eventName,
          parameters: parameters,
          gameId: gameId,
          gameName: gameName,
          sessionId: sessionId,
        );
      },
    );
    WidgetsBinding.instance.addObserver(this);
    _lifecycle.setScreenVisible(widget.isActive);
    _lifecycle.setAppActive(
      _isAppLifecycleActive(WidgetsBinding.instance.lifecycleState),
    );
    final key = widget.game.gameKey?.trim();
    _gameKey = key != null && key.isNotEmpty ? key : null;
    // If the game has no key yet, generate one and persist it.
    if (_gameKey == null && widget.game.id.isNotEmpty) {
      unawaited(_ensureGameKey());
    }
    if (widget.isActive) {
      _onPresented();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _observedRoute) return;
    if (_observedRoute != null) {
      appRouteObserver.unsubscribe(this);
    }
    _observedRoute = route;
    appRouteObserver.subscribe(this, route);
  }

  @override
  void didUpdateWidget(covariant _CommunityGamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _lifecycle.setScreenVisible(true);
      _onPresented();
    } else if (oldWidget.isActive && !widget.isActive) {
      _lifecycle.setScreenVisible(false);
      unawaited(_endSession(reason: 'navigation'));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle.setAppActive(_isAppLifecycleActive(state));
  }

  @override
  void dispose() {
    final disposeReason = _loadError.isNotEmpty ? 'error' : 'dispose';
    WidgetsBinding.instance.removeObserver(this);
    if (_observedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _observedRoute = null;
    }
    _lifecycle.setScreenVisible(false);
    _lifecycle.setAppActive(false);
    unawaited(_endSession(reason: disposeReason));
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _lifecycle.setScreenVisible(false);
    unawaited(_endSession(reason: 'navigation'));
  }

  @override
  void didPopNext() {
    if (!widget.isActive) return;
    _lifecycle.setScreenVisible(true);
    _onPresented();
  }

  @override
  void didPop() {
    _lifecycle.setScreenVisible(false);
  }

  void _onPresented() {
    _ensureSessionStarted();
    unawaited(_lifecycle.markGameViewed());
    if (!_isLoading && _loadError.isEmpty) {
      unawaited(_lifecycle.markGameLoaded());
    }
  }

  void _ensureSessionStarted() {
    if (_sessionId != null) return;
    _sessionId = _lifecycle.startSession();
    _sessionOpenedAt = _lifecycle.sessionStartedAt;
    _sessionCoinsSpent = 0;
    _sessionEndFuture = null;
    unawaited(_recordSessionStart());
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
    _ensureSessionStarted();

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
        'sessionId': _sessionId ?? '',
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
            'sessionId': _sessionId ?? '',
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
        final score = GameSessionAnalytics.extractScoreValue(
          primary: payload,
          secondary: postScoreResponse,
        );
        if (score != null) {
          unawaited(_lifecycle.trackScoreSubmitted(
            score: score,
            scoreType: GameSessionAnalytics.extractScoreType(
              primary: payload,
              secondary: postScoreResponse,
            ),
          ));
        }
        return postScoreResponse;
      case 'sendChallenge':
        _socialBridge.recordScoreFromMap(payload);
        final response = await client.sendChallenge(
          await _withResolvedScore(mergePayload({}), inContext: false),
        );
        _socialBridge.recordScoreFromResponse(response);
        unawaited(_shareFromSendChallengeResponse(response));
        return response;
      case 'shareCard':
        // share-card was merged into send-challenge; route legacy calls there
        _socialBridge.recordScoreFromMap(payload);
        return client.sendChallenge(
          await _withResolvedScore(mergePayload({}), inContext: false),
        );
      case 'openChat':
        // open-chat carries the score inside `context: { score, ... }`.
        _socialBridge.recordScoreFromMap(payload);
        return client.openChat(
          await _withResolvedScore(mergePayload({}), inContext: true),
        );
      case 'notifyScore':
        // Sent by the injected fetch/XHR interceptor for games that call the
        // REST endpoints directly instead of the SDK bridge methods.
        final scoreRequest = payload['request'];
        final scoreResponse = payload['response'];
        if (scoreRequest is Map) _socialBridge.recordScoreFromMap(scoreRequest);
        if (scoreResponse is Map) {
          _socialBridge.recordScoreFromResponse(scoreResponse);
        }
        final requestMap = scoreRequest is Map
            ? Map<String, dynamic>.from(scoreRequest)
            : null;
        final responseMap = scoreResponse is Map
            ? Map<String, dynamic>.from(scoreResponse)
            : null;
        final score = GameSessionAnalytics.extractScoreValue(
          primary: requestMap,
          secondary: responseMap,
        );
        if (score != null) {
          unawaited(_lifecycle.trackScoreSubmitted(
            score: score,
            scoreType: GameSessionAnalytics.extractScoreType(
              primary: requestMap,
              secondary: responseMap,
            ),
          ));
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
        unawaited(_lifecycle.markCoinSpend(coins: coins));
        return response;
      case 'close':
        await _endSession(reason: 'user_close');
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
    final sessionId = _sessionId;
    final openedAt = _sessionOpenedAt;
    if (sessionId == null || openedAt == null) return;

    final userId = _playerId;
    if (userId == null) return;

    try {
      await GameSessionAnalytics.recordSessionStart(
        gameId: widget.game.id,
        sessionId: sessionId,
        userId: userId,
        openedAt: openedAt,
        gameName: widget.game.name,
      );
    } catch (_) {
      // Session analytics must not block game playback.
    }
  }

  Future<void> _recordSessionCoinSpend(int coins) async {
    if (coins <= 0) return;
    final sessionId = _sessionId;
    if (sessionId == null) return;

    final userId = _playerId;
    if (userId == null) return;

    try {
      await GameSessionAnalytics.recordSessionCoinSpend(
        gameId: widget.game.id,
        sessionId: sessionId,
        coins: coins,
      );
    } catch (_) {
      // The final session write will persist the total if this update fails.
    }
  }

  Future<void> _endSession({String? reason}) async {
    await _lifecycle.endSession(endReason: reason);
    await _recordSessionEnd();

    _sessionId = null;
    _sessionOpenedAt = null;
  }

  Future<void> _recordSessionEnd() {
    final sessionId = _sessionId;
    final openedAt = _sessionOpenedAt;
    if (sessionId == null || openedAt == null) {
      return Future.value();
    }

    final ongoing = _sessionEndFuture;
    if (ongoing != null) return ongoing;

    final userId = _playerId;
    if (userId == null) {
      return Future.value();
    }

    final closedAt = DateTime.now();
    final future = GameSessionAnalytics.recordSessionEnd(
      gameId: widget.game.id,
      sessionId: sessionId,
      userId: userId,
      openedAt: openedAt,
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
      'sessionId': _sessionId ?? '',
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
          // Force WebGL canvases to keep their drawing buffer so the OCR
          // fallback can screenshot them (Unity WebGL, Construct WebGL, …).
          // Runs before the game's own scripts; see [_webglReadbackScript].
          initialUserScripts: UnmodifiableListView<UserScript>(<UserScript>[
            UserScript(
              source: _webglReadbackScript,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            // Normalize the viewport and keep oversized game canvases fitted
            // to the view — see [_viewportFitScript].
            UserScript(
              source: _viewportFitScript,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
          ]),
          // When embedded in the scrolling home feed, eagerly claim every
          // gesture that starts on the game — taps as well as drags. A
          // vertical-drag recognizer alone is not enough: taps then sit in
          // the gesture arena with the feed's scroll view and are only
          // replayed to the webview after the arena resolves, which
          // timing-sensitive game input handlers miss — making the game feel
          // untappable. The eager recognizer wins the arena on pointer-down,
          // so events stream to the game in real time. The feed is still
          // scrollable via the transparent edge strips that
          // `InlineCommunityGameCard` overlays on the top and bottom of the
          // game (they sit above the webview, so gestures there never enter
          // this arena). The full-screen player passes embeddedInFeed=false
          // so its own edge-zone navigation keeps working unchanged.
          gestureRecognizers: widget.embeddedInFeed
              ? <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
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
            // Kick a fit pass now that the document has settled (the user
            // script schedules its own delayed retries for late canvases).
            await controller.evaluateJavascript(
                source: 'window.__inzoneRefit && window.__inzoneRefit();');
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
            if (widget.isActive) {
              _ensureSessionStarted();
              unawaited(_lifecycle.markGameLoaded());
            }
          },
          onReceivedError: (_, __, error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _loadError = 'Failed to load game: ${error.description}';
            });
            unawaited(_endSession(reason: 'error'));
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
            scoreResolver: _resolveLatestScore,
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
                    child: CircularProgressIndicator(color: theme.primaryColor),
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
class InlineCommunityGameCard extends StatefulWidget {
  final CommunityGame game;

  const InlineCommunityGameCard({super.key, required this.game});

  @override
  State<InlineCommunityGameCard> createState() =>
      _InlineCommunityGameCardState();
}

class _InlineCommunityGameCardState extends State<InlineCommunityGameCard> {
  CommunityGame get game => widget.game;

  /// Whether the live game (webview) is mounted. The feed pre-builds cards
  /// well outside the viewport (cacheExtent + keep-alives), so mounting the
  /// game on build meant it ran — audio included — before the user ever
  /// reached it and kept running after they scrolled past. Instead the game
  /// is mounted only while the card is actually on screen; off screen we show
  /// a same-sized placeholder so the card's layout never changes.
  bool _gameActive = false;

  /// Unique per state instance (the same game can appear in several feed
  /// slots, so game.id alone would collide as a VisibilityDetector key).
  final Key _visibilityKey = UniqueKey();

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final fraction = info.visibleFraction;
    // Hysteresis: start the game once half the card is visible, stop it only
    // when it has almost fully left the screen — avoids flickering the game
    // on/off while the boundary hovers near the viewport edge.
    if (!_gameActive && fraction >= 0.5) {
      setState(() => _gameActive = true);
    } else if (_gameActive && fraction <= 0.1) {
      setState(() => _gameActive = false);
    }
  }

  /// Same footprint as the live game body; shown while the card is off
  /// screen. Users only ever glimpse it mid-scroll.
  Widget _buildGamePlaceholder(ThemeData theme, String iconUrl) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: iconUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: iconUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const SizedBox(width: 72, height: 72),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.sports_esports,
                        size: 72,
                        color: Colors.white24,
                      ),
                    )
                  : const Icon(
                      Icons.sports_esports,
                      size: 72,
                      color: Colors.white24,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              game.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    // Match the regular post card width (full width minus the 8px the feed
    // reserves on each side).
    final cardWidth = screenSize.width - 8;
    // Size the game body like the video post cards, which render their media
    // at width / aspect-ratio with a 9:16 portrait default — so a game post
    // has the same visual footprint in the feed as a video post. Capped at
    // 85% of the viewport so the card header stays visible on short/wide
    // screens.
    final gameHeight = min(cardWidth * 16 / 9, screenSize.height * 0.85);
    final description = game.description.trim();
    final iconUrl = game.iconUrl.trim();

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: Padding(
        // Mirror the bottom spacing used by the regular post cards.
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Container(
          width: cardWidth,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            uploaderId: game.uploaderId,
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
                  padding:
                      const EdgeInsets.only(left: 10, right: 10, bottom: 8),
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
                  //
                  // The live game is mounted only while the card is on screen
                  // (see _onVisibilityChanged); otherwise a same-sized
                  // placeholder keeps the layout identical.
                  child: _gameActive
                      ? _CommunityGamePage(
                          key: ValueKey('inline_game_${game.id}'),
                          game: game,
                          isActive: true,
                          embeddedInFeed: true,
                          onClose: () async {},
                        )
                      : _buildGamePlaceholder(theme, iconUrl),
                ),
              ),
            ],
          ),
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

class _SimulaGamePageState extends State<_SimulaGamePage>
    with WidgetsBindingObserver, RouteAware {
  InAppWebViewController? _controller;
  String? _iframeUrl;
  bool _resolving = true;
  bool _webLoading = true;
  String _error = '';
  bool _resolved = false;

  final AnalyticsService _analyticsService = AnalyticsService();
  late final GameSessionLifecycleCoordinator _lifecycle;
  String? _sessionId;
  DateTime? _sessionOpenedAt;

  late final String? _playerId;
  Future<void>? _sessionEndFuture;
  ModalRoute<dynamic>? _observedRoute;

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim();
    _playerId = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : null;
    _lifecycle = GameSessionLifecycleCoordinator(
      gameId: widget.game.id,
      gameName: widget.game.name,
      source: 'simula',
      trackEvent: (
        eventName, {
        parameters,
        gameId,
        gameName,
        sessionId,
      }) {
        return _forwardLifecycleProductEvent(
          analyticsService: _analyticsService,
          eventName: eventName,
          parameters: parameters,
          gameId: gameId,
          gameName: gameName,
          sessionId: sessionId,
        );
      },
    );
    WidgetsBinding.instance.addObserver(this);
    _lifecycle.setScreenVisible(widget.isActive);
    _lifecycle.setAppActive(
      _isAppLifecycleActive(WidgetsBinding.instance.lifecycleState),
    );
    if (widget.isActive) {
      _onPresented();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _observedRoute) {
      if (_observedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _observedRoute = route;
      appRouteObserver.subscribe(this, route);
    }

    // Resolve the iframe once, after the providers/MediaQuery are available.
    if (!_resolved) {
      _resolved = true;
      unawaited(_resolveIframe());
    }
  }

  @override
  void didUpdateWidget(covariant _SimulaGamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _lifecycle.setScreenVisible(true);
      _onPresented();
    } else if (oldWidget.isActive && !widget.isActive) {
      _lifecycle.setScreenVisible(false);
      unawaited(_endSession(reason: 'navigation'));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle.setAppActive(_isAppLifecycleActive(state));
  }

  @override
  void dispose() {
    final disposeReason = _error.isNotEmpty ? 'error' : 'dispose';
    WidgetsBinding.instance.removeObserver(this);
    if (_observedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _observedRoute = null;
    }
    _lifecycle.setScreenVisible(false);
    _lifecycle.setAppActive(false);
    unawaited(_endSession(reason: disposeReason));
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _lifecycle.setScreenVisible(false);
    unawaited(_endSession(reason: 'navigation'));
  }

  @override
  void didPopNext() {
    if (!widget.isActive) return;
    _lifecycle.setScreenVisible(true);
    _onPresented();
  }

  @override
  void didPop() {
    _lifecycle.setScreenVisible(false);
  }

  void _onPresented() {
    _ensureSessionStarted();
    unawaited(_lifecycle.markGameViewed());
    if (!_webLoading && _iframeUrl != null && _error.isEmpty) {
      unawaited(_lifecycle.markGameLoaded());
    }
  }

  void _ensureSessionStarted() {
    if (_sessionId != null) return;
    _sessionId = _lifecycle.startSession();
    _sessionOpenedAt = _lifecycle.sessionStartedAt;
    _sessionEndFuture = null;
    unawaited(_recordSessionStart());
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
      unawaited(_endSession(reason: 'error'));
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
        unawaited(_endSession(reason: 'error'));
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
      unawaited(_endSession(reason: 'error'));
    }
  }

  Future<void> _recordSessionStart() async {
    final sessionId = _sessionId;
    final openedAt = _sessionOpenedAt;
    if (sessionId == null || openedAt == null) return;

    final userId = _playerId;
    if (userId == null) return;
    try {
      await GameSessionAnalytics.recordSessionStart(
        gameId: widget.game.id,
        sessionId: sessionId,
        userId: userId,
        openedAt: openedAt,
        gameName: widget.game.name,
      );
    } catch (_) {
      // Analytics must never block playback.
    }
  }

  Future<void> _endSession({String? reason}) async {
    await _lifecycle.endSession(endReason: reason);
    await _recordSessionEnd();

    _sessionId = null;
    _sessionOpenedAt = null;
  }

  Future<void> _recordSessionEnd() {
    final sessionId = _sessionId;
    final openedAt = _sessionOpenedAt;
    if (sessionId == null || openedAt == null) return Future.value();

    final ongoing = _sessionEndFuture;
    if (ongoing != null) return ongoing;

    final userId = _playerId;
    if (userId == null) return Future.value();

    final future = GameSessionAnalytics.recordSessionEnd(
      gameId: widget.game.id,
      sessionId: sessionId,
      userId: userId,
      openedAt: openedAt,
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
                if (widget.isActive) {
                  _ensureSessionStarted();
                  unawaited(_lifecycle.markGameLoaded());
                }
              },
              onReceivedError: (_, __, error) {
                if (!mounted) return;
                setState(() {
                  _webLoading = false;
                  _error = 'Failed to load game: ${error.description}';
                });
                unawaited(_endSession(reason: 'error'));
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
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
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
