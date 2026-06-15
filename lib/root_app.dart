import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:inzone/screen/common/home_screen.dart';
import 'package:inzone/screen/explore/groups_explore_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/components/video/video_widget.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart';
import 'package:iconify_flutter/icons/mdi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconify_flutter/icons/heroicons_solid.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:simula_ads/simula_ads.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:inzone/services/active_character_notifier.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/data/hub_game.dart';
import 'package:inzone/data/community_game.dart';
import 'package:inzone/screen/common/community_game_screen.dart';
import 'package:inzone/screen/common/game_hub_screen.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class _PopularCharacterOption {
  final String id;
  final String name;
  final String? imageUrl;
  final String? description;

  const _PopularCharacterOption({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
  });
}

class RootApp extends StatefulWidget {
  final Widget child;

  const RootApp({super.key, required this.child});

  @override
  _RootAppState createState() => _RootAppState();
}

class _RootAppState extends State<RootApp>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const String _defaultMiniGameCharacterId = 'inzone-default';
  int _currentPage = 0; // Track selected tab index
  final ScrollController _homeScrollController = ScrollController();
  final _key = GlobalKey<ScaffoldState>();
  bool _isKeyboardVisible = false;
  bool _isExpanded = false;
  bool _isNavBarVisible = true; // Track visibility of navigation bar
  double _lastScrollPosition = 0; // Keep track of the last scroll position
  bool _miniGameMenuOpen = false;
  bool _isCharacterPickerOpen = false;
  bool _isLoadingPopularCharacters = false;
  List<_PopularCharacterOption> _popularCharacters = const [];
  DateTime? _popularCharactersLoadedAt;
  List<Message> _miniGameMessages = const [];
  GameData? _lastCompletedMiniGame;
  String? _pendingMiniGameDeepLinkGameId;
  String? _lastCompletedMiniGameOverText;
  // Guards against the same deep link being handled twice in quick succession.
  // A single tap can arrive via several sources at once (go_router redirect, the
  // AppsFlyer SDK callback, and app_links), so we ignore repeats of the same
  // gameId within a short window.
  String? _lastHandledDeepLinkGameId;
  DateTime? _lastHandledDeepLinkAt;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _appLinksSubscription;
  StreamSubscription<String>? _minigameDeepLinkSubscription;
  StreamSubscription<String?>? _minigameMenuOpenSubscription;
  StreamSubscription<String>? _communityGameDeepLinkSubscription;
  ActiveCharacterNotifier? _activeCharacterNotifier;

  /* --- in app review --- */
  final InAppReview inAppReview = InAppReview.instance;
  int appOpenCounter = 0; // Counter for app opens

  // Add animation controllers
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  // Focus node to track app-wide focus state
  final FocusNode _rootFocusNode = FocusNode();

  // List of screens for the IndexedStack
  late final List<Widget> _screens;

  final List<String> _bottomNavBarTitles = [
    'Home',
    'Games',
    'Groups',
    'Chats',
  ];

  final List<String> _routes = [
    Routes.home,
    '',
    Routes.groups,
    Routes.chats,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set once — calling this on every build was a platform-channel call per
    // rebuild of the root shell.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Initialize rotation animation controller
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 1/8 of a full rotation (45 degrees)
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    // Initialize screens with the controller
    _screens = [
      HomeScreen(controller: _homeScrollController),
      const SizedBox.shrink(),
      const GroupsExploreScreen(),
      AllChatsScreen(key: allChatsScreenKey),
    ];

    // Add scroll listener to handle navbar visibility
    // _homeScrollController.addListener(_handleScroll);

    // Check app open count and request review if needed
    _checkAndRequestReview();
    _initAppLinks();
    _minigameDeepLinkSubscription =
        AppsFlyerService().minigameDeepLinkStream.listen((gameId) {
      if (!mounted) return;
      if (_isDuplicateDeepLink(gameId.trim())) return;
      _openMiniGameFromDeepLink(gameId);
    });
    _minigameMenuOpenSubscription =
        AppsFlyerService().minigameMenuOpenStream.listen((initialGameId) {
      if (!mounted) return;
      final normalized = initialGameId?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        _openMiniGameFromDeepLink(normalized);
        return;
      }

      setState(() {
        _pendingMiniGameDeepLinkGameId = null;
        _miniGameMenuOpen = true;
      });
      _loadPopularCharacters();
      _refreshMiniGameForCurrentCharacter();
    });
    _communityGameDeepLinkSubscription =
        AppsFlyerService().communityGameDeepLinkStream.listen((gameId) {
      if (!mounted) return;
      _openCommunityGameFromDeepLink(gameId);
    });
    // Cold start: the deep link may have been queued (via the go_router redirect)
    // before this subscription existed, so the broadcast event was dropped.
    // Consume any pending gameId once the first frame is up and the Navigator is
    // ready. The duplicate guard prevents this from double-opening with the
    // stream above on warm starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending =
          AppsFlyerService().consumePendingCommunityGameDeepLinkGameId();
      if (pending != null && pending.isNotEmpty) {
        _openCommunityGameFromDeepLink(pending);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appLinksSubscription?.cancel();
    _minigameDeepLinkSubscription?.cancel();
    _minigameMenuOpenSubscription?.cancel();
    _communityGameDeepLinkSubscription?.cancel();
    // _homeScrollController.removeListener(_handleScroll);
    _homeScrollController.dispose();
    _rootFocusNode.dispose();
    _rotationController.dispose();

    // Clean up video cache to prevent memory leaks
    try {
      disposeAllVideoCache();
    } catch (e) {
      debugPrint('Error disposing video cache in RootApp: $e');
    }

    super.dispose();
  }

  Future<void> _initAppLinks() async {
    try {
      _appLinks = AppLinks();

      final initialUri = await _appLinks!.getInitialLink();
      _handleIncomingDeepLinkUri(initialUri);

      _appLinksSubscription = _appLinks!.uriLinkStream.listen((uri) {
        _handleIncomingDeepLinkUri(uri);
      });
    } catch (_) {}
  }

  void _handleIncomingDeepLinkUri(Uri? uri) {
    if (!mounted || uri == null) return;

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final deepLinkValue = uri.queryParameters['deep_link_value']?.toLowerCase();

    // ── Community (html) games → Game Hub / CommunityGameScreen ──
    // inzone://game?gameId=social-loops
    String? communityGameId;
    if (scheme == 'inzone' && host == 'game') {
      communityGameId = uri.queryParameters['gameId'];
    }
    // inzone.app/game/social-loops (universal link)
    if ((communityGameId == null || communityGameId.trim().isEmpty) &&
        host == 'inzone.app' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'game') {
      communityGameId = uri.pathSegments[1];
    }
    // AppsFlyer deep_link_value=community_game&deep_link_sub1=social-loops
    if ((communityGameId == null || communityGameId.trim().isEmpty) &&
        (deepLinkValue == 'community_game' || deepLinkValue == 'html_game')) {
      communityGameId = uri.queryParameters['deep_link_sub1'];
    }
    if (communityGameId != null && communityGameId.trim().isNotEmpty) {
      _openCommunityGameFromDeepLink(communityGameId);
      return;
    }

    // ── Simula minigame catalogue ──
    String? gameId;

    // inzone://minigame?gameId=nova-arena
    if (scheme == 'inzone' && host == 'minigame') {
      gameId = uri.queryParameters['gameId'];
    }

    // AppsFlyer deep_link_value=minigame&deep_link_sub1=nova-arena
    if (gameId == null || gameId.trim().isEmpty) {
      if (deepLinkValue == 'minigame') {
        gameId = uri.queryParameters['deep_link_sub1'];
      }
    }

    if (gameId != null && gameId.trim().isNotEmpty) {
      _openMiniGameFromDeepLink(gameId);
    }
  }

  void _openGameHubScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameHubScreen(onPlay: _handleHubGameTap),
        fullscreenDialog: true,
      ),
    );
  }

  void _handleHubGameTap(HubGame game) {
    if (game.source == HubGameSource.community) {
      final community = game.communityGame;
      if (community == null || community.gameUrl.isEmpty) return;
      // Push the game on top of the Game Hub so the back button returns the
      // user to the hub (the screen they launched the game from).
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityGameScreen(game: community),
          fullscreenDialog: true,
        ),
      );
      return;
    }
    // Simula minigames render as an overlay on top of Home, so the Game Hub
    // route must be dismissed first to reveal it.
    Navigator.of(context).maybePop();
    _loadPopularCharacters();
    _openMiniGameFromDeepLink(game.id);
  }

  // Community (html) games open on the Game Hub via CommunityGameScreen — they
  // never belong in the Simula minigame catalogue. The deep link is already
  // tagged as a community game (deep_link_value=community_game /
  // inzone://game?gameId=…), so we route straight here and, if the game can't be
  // resolved, land the user on the Game Hub rather than the minigame menu.
  // Returns true if this gameId was already handled within the last few seconds
  // (so a duplicate deep-link delivery should be ignored).
  bool _isDuplicateDeepLink(String gameId) {
    final now = DateTime.now();
    if (_lastHandledDeepLinkGameId == gameId &&
        _lastHandledDeepLinkAt != null &&
        now.difference(_lastHandledDeepLinkAt!) < const Duration(seconds: 3)) {
      return true;
    }
    _lastHandledDeepLinkGameId = gameId;
    _lastHandledDeepLinkAt = now;
    return false;
  }

  void _openCommunityGameFromDeepLink(String gameId) {
    final normalized = gameId.trim();
    if (!mounted || normalized.isEmpty) return;
    if (_isDuplicateDeepLink(normalized)) return;

    FirebaseFirestore.instance
        .collection('html_games')
        .doc(normalized)
        .get()
        .then((snap) {
      if (!mounted) return;
      if (snap.exists) {
        final community = CommunityGame.fromSnapshot(snap);
        if (community.gameUrl.isNotEmpty) {
          // Keep the Game Hub beneath the game so backing out returns the user
          // to the hub (a valid screen) rather than jumping back to Home.
          _openGameHubScreen();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CommunityGameScreen(game: community),
              fullscreenDialog: true,
            ),
          );
          return;
        }
      }
      // Game not found or not yet playable — show the Game Hub instead of the
      // Simula catalogue so the user always lands somewhere valid.
      _openGameHubScreen();
    }).catchError((_) {
      if (!mounted) return;
      _openGameHubScreen();
    });
  }

  void _openMiniGameFromDeepLink(String gameId) {
    final normalized = gameId.trim();
    if (!mounted || normalized.isEmpty) return;

    // Check if this is a community HTML game first — those live in
    // html_games and open in CommunityGameScreen, not the Simula menu.
    FirebaseFirestore.instance
        .collection('html_games')
        .doc(normalized)
        .get()
        .then((snap) {
      if (!mounted) return;
      if (snap.exists) {
        final community = CommunityGame.fromSnapshot(snap);
        if (community.gameUrl.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CommunityGameScreen(game: community),
              fullscreenDialog: true,
            ),
          );
          return;
        }
      }
      // Not a community game (or no gameUrl) — fall through to Simula menu.
      setState(() {
        _pendingMiniGameDeepLinkGameId = normalized;
        _miniGameMenuOpen = true;
      });
      _loadPopularCharacters();
      _refreshMiniGameForCurrentCharacter();
    }).catchError((_) {
      // Firestore lookup failed — fall through to Simula menu.
      if (!mounted) return;
      setState(() {
        _pendingMiniGameDeepLinkGameId = normalized;
        _miniGameMenuOpen = true;
      });
      _loadPopularCharacters();
      _refreshMiniGameForCurrentCharacter();
    });
  }

  void _refreshMiniGameForCurrentCharacter() {
    final activeCharacter = _activeCharacterNotifier;
    if (!mounted || activeCharacter == null) return;

    _refreshMiniGameMessages(
      charID: activeCharacter.charID,
      charName: activeCharacter.charName,
      charDesc: activeCharacter.charDesc,
    );
  }

  Future<void> _consumePendingMinigameDeepLink() async {
    final gameId =
        await AppsFlyerService.consumePendingMinigameDeepLinkGameId();
    if (!mounted || gameId == null || gameId.trim().isEmpty) return;

    _openMiniGameFromDeepLink(gameId);
  }

  // Handle scroll events to show/hide navbar
  void _handleScroll() {
    // Only apply to Home screen
    if (_currentPage != 0) return;

    if (!_homeScrollController.hasClients) return;

    final currentScrollPosition = _homeScrollController.position.pixels;

    // Determine if scrolling up or down
    if (currentScrollPosition > _lastScrollPosition &&
        currentScrollPosition > 10) {
      // Scrolling down
      if (_isNavBarVisible) {
        setState(() {
          _isNavBarVisible = false;
        });
      }
    } else if (currentScrollPosition < _lastScrollPosition) {
      // Scrolling up
      if (!_isNavBarVisible) {
        setState(() {
          _isNavBarVisible = true;
        });
      }
    }

    _lastScrollPosition = currentScrollPosition;
  }

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();

    // Gamepad tab (index 1) opens the unified Game Hub screen instead of navigating.
    if (index == 1) {
      _openGameHubScreen();
      return;
    }

    if (_currentPage == index) {
      // If same tab is tapped again, do any special handling here
      if (index == 0) {
        // For home tab, check if controller is attached before scrolling to top
        if (_homeScrollController.hasClients) {
          _homeScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          // Show navbar when scrolling to top
          setState(() {
            _isNavBarVisible = true;
          });
        }
      }
    }

    // Update the current page index
    setState(() {
      _currentPage = index;
      // Show navbar when changing tabs
      _isNavBarVisible = true;
    });

    // Update the URL without rebuilding the page
    context.go(_routes[index], extra: {'skipRebuild': true});
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _fallbackMiniGameImage(BuildContext context) {
    return 'https://firebasestorage.googleapis.com/v0/b/inzone-f93e4.appspot.com/o/app_assets%2Fsplash.png?alt=media';
  }

  Future<void> _loadPopularCharacters() async {
    if (_isLoadingPopularCharacters) return;

    // Reuse a recent result — this is a 300-doc Firestore query and used to
    // re-run every time the character picker opened.
    if (_popularCharacters.length > 1 &&
        _popularCharactersLoadedAt != null &&
        DateTime.now().difference(_popularCharactersLoadedAt!) <
            const Duration(minutes: 10)) {
      return;
    }

    setState(() {
      _isLoadingPopularCharacters = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('popularCharacters')
          .orderBy('numberOfChats', descending: true)
          .limit(300)
          .get();

      const defaultInZoneOption = _PopularCharacterOption(
        id: _defaultMiniGameCharacterId,
        name: 'InZone',
        imageUrl: null,
        description: 'Default Simula mini-game AI companion.',
      );

      final loaded = snapshot.docs.map((doc) {
        final data = doc.data();
        return _PopularCharacterOption(
          id: doc.id,
          name: _firstNonEmptyString([
                data['name'],
                data['displayName'],
                data['username'],
              ]) ??
              'AI Character',
          imageUrl: _firstNonEmptyString([
            data['profile_picture_url'],
            data['profilePicture'],
            data['profile_picture'],
            data['avatar'],
          ]),
          description: _firstNonEmptyString([
            data['personality'],
            data['greeting'],
            data['description'],
          ]),
        );
      }).toList();

      if (!mounted) return;
      _popularCharactersLoadedAt = DateTime.now();
      setState(() {
        _popularCharacters = [defaultInZoneOption, ...loaded];
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _popularCharacters = const [
            _PopularCharacterOption(
              id: _defaultMiniGameCharacterId,
              name: 'InZone',
              imageUrl: null,
              description: 'Default Simula mini-game AI companion.',
            ),
          ];
        });
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(FeatherIcons.alertTriangle, color: Colors.orange),
          message:
              'Could not load characters. Opening games with current selection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPopularCharacters = false;
        });
      }
    }
  }

  Future<void> _refreshMiniGameMessages({
    required String charID,
    required String charName,
    String? charDesc,
  }) async {
    if (charID == _defaultMiniGameCharacterId) {
      if (!mounted) return;
      setState(() {
        _miniGameMessages = const [];
      });
      return;
    }

    final List<Message> messages = [
      Message(
        role: 'assistant',
        content:
            'You are $charName. Give short, contextual game hints and reactions while the user plays, adapting naturally to each game.',
      ),
    ];

    if (charDesc != null && charDesc.trim().isNotEmpty) {
      messages.add(
        Message(
          role: 'assistant',
          content: 'Character context: ${charDesc.trim()}',
        ),
      );
    }

    final history = await InZoneDatabase.loadConversationMessages(charID);
    if (history != null && history.isNotEmpty) {
      final recent =
          history.length > 10 ? history.sublist(history.length - 10) : history;

      for (final item in recent) {
        final text = (item['text'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        final speaker = (item['speaker'] ?? '').toString().toLowerCase();
        messages.add(
          Message(
            role: speaker == 'user' ? 'user' : 'assistant',
            content: text,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _miniGameMessages = messages;
    });
  }

  Future<void> _openMiniGameWithCharacterPicker() async {
    if (_isCharacterPickerOpen) return;
    _isCharacterPickerOpen = true;

    try {
      await _loadPopularCharacters();
      if (!mounted) return;

      final activeCharacter = _activeCharacterNotifier;
      if (activeCharacter == null) return;
      final selected = await showModalBottomSheet<_PopularCharacterOption>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          final theme = Theme.of(sheetContext);

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Choose Character for Mini Games',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_popularCharacters.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No popular characters found.\nUsing current character.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _popularCharacters.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final character = _popularCharacters[index];
                          final isActive =
                              activeCharacter.charID == character.id;

                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isActive
                                    ? const Color(0xFF14CFEE)
                                    : theme.dividerColor
                                        .withValues(alpha: 0.35),
                              ),
                            ),
                            tileColor: theme.canvasColor,
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: theme.cardColor,
                              backgroundImage: (character.imageUrl != null &&
                                      character.imageUrl!.isNotEmpty)
                                  ? CachedNetworkImageProvider(
                                      character.imageUrl!,
                                      maxWidth: 132)
                                  : null,
                              child: (character.imageUrl == null ||
                                      character.imageUrl!.isEmpty)
                                  ? Text(
                                      character.name.isNotEmpty
                                          ? character.name[0].toUpperCase()
                                          : '?',
                                    )
                                  : null,
                            ),
                            title: Text(
                              character.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            subtitle: character.description == null
                                ? null
                                : Text(
                                    character.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                            trailing: isActive
                                ? const Icon(Icons.check_circle,
                                    color: Color(0xFF14CFEE))
                                : const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(sheetContext).pop(character);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      if (selected != null) {
        context.read<ActiveCharacterNotifier>().setActiveCharacter(
              charName: selected.name,
              charID: selected.id,
              charImage: selected.imageUrl,
              charDesc: selected.description,
            );

        await _refreshMiniGameMessages(
          charID: selected.id,
          charName: selected.name,
          charDesc: selected.description,
        );
      }
    } finally {
      _isCharacterPickerOpen = false;
    }
  }

  // Get current page index from the current route
  void _updateCurrentPageFromRoute(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;

    for (int i = 0; i < _routes.length; i++) {
      if (location == _routes[i]) {
        if (_currentPage != i) {
          setState(() {
            _currentPage = i;
          });
        }
        break;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _activeCharacterNotifier = context.read<ActiveCharacterNotifier>();
    _updateCurrentPageFromRoute(context);
  }

  // Function to return the title based on the current page
  String _getPageTitle(int page) {
    if (page == 2) {
      return 'Explore Groups';
    }
    return _bottomNavBarTitles[page];
  }

  final List<String> _iconifyPaths = [
    Ri.home_5_fill,
    Mdi.gamepad_variant,
    Mdi.account_group,
    HeroiconsSolid.chat_bubble_oval_left_ellipsis,
  ];

  void _toggleExpanded() {
    print("Toggle expanded: ${!_isExpanded}");
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
    });
  }

  String _buildMiniGameChallengeLink(String gameId) {
    return AppsFlyerService().generateMinigameLink(gameId);
  }

  String _normalizedGameName(GameData game) {
    return '${game.id} ${game.name}'.toLowerCase();
  }

  List<int> _extractAllNumbers(String text) {
    return RegExp(r'\b\d{1,3}(?:,\d{3})+\b|\b\d+\b')
        .allMatches(text)
        .map((m) {
          final raw = (m.group(0) ?? '').replaceAll(',', '');
          return int.tryParse(raw);
        })
        .whereType<int>()
        .toList();
  }

  int? _parseExtractedNumber(String? rawValue) {
    if (rawValue == null) return null;
    final cleaned = rawValue.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return value.round();
  }

  int? _extractStatNumber(String text, String labelPattern) {
    final lowerText = text.toLowerCase();

    final labeledAfter = RegExp(
      "(?:$labelPattern)\\s*[\"']?\\s*[:=-]?\\s*[\"']?(\\d{1,3}(?:,\\d{3})+|\\d+(?:\\.\\d+)?)",
      caseSensitive: false,
    ).firstMatch(lowerText);

    if (labeledAfter != null) {
      final parsed = _parseExtractedNumber(labeledAfter.group(1));
      if (parsed != null) return parsed;
    }

    final labeledBefore = RegExp(
      '(\\d{1,3}(?:,\\d{3})+|\\d+(?:\\.\\d+)?)\\s*(?:$labelPattern)',
      caseSensitive: false,
    ).firstMatch(lowerText);

    if (labeledBefore != null) {
      final parsed = _parseExtractedNumber(labeledBefore.group(1));
      if (parsed != null) return parsed;
    }

    final jsonLike = RegExp(
      "[\"']?(?:$labelPattern)[\"']?\\s*:\\s*[\"']?(\\d{1,3}(?:,\\d{3})+|\\d+(?:\\.\\d+)?)",
      caseSensitive: false,
    ).firstMatch(lowerText);

    if (jsonLike != null) {
      final parsed = _parseExtractedNumber(jsonLike.group(1));
      if (parsed != null) return parsed;
    }

    return null;
  }

  String? _extractDifficulty(String text) {
    const levels = ['easy', 'medium', 'hard', 'expert', 'master'];
    for (final level in levels) {
      if (text.toLowerCase().contains(level)) {
        return level[0].toUpperCase() + level.substring(1);
      }
    }
    return null;
  }

  int? _extractChessMoves(String text) {
    return _extractStatNumber(
      text,
      'moves?|move[_\\s-]?count|ply|turns?',
    );
  }

  int? _extractChessCaptures(String text) {
    return _extractStatNumber(
      text,
      'captures?|captured|capture[_\\s-]?count|pieces?[_\\s-]?captured',
    );
  }

  String? _normalizeChessTitleValue(String? raw) {
    if (raw == null) return null;
    final source = raw.trim().toLowerCase();
    if (source.isEmpty) return null;

    if (source.contains('victory') ||
        source.contains('win') ||
        source.contains('won') ||
        source.contains('checkmate')) {
      return 'Victory';
    }
    if (source.contains('defeat') ||
        source.contains('lose') ||
        source.contains('loss') ||
        source.contains('lost')) {
      return 'Defeat';
    }
    if (source.contains('draw') ||
        source.contains('stalemate') ||
        source.contains('tie')) {
      return 'Draw';
    }

    return null;
  }

  Map<String, dynamic> _extractChessResultFields(String text) {
    final fields = <String, dynamic>{
      'title': null,
      'moves': null,
      'captures': null,
    };

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();

        String? valueFor(List<String> keys) {
          for (final key in keys) {
            for (final entry in map.entries) {
              if (entry.key.toLowerCase() == key.toLowerCase()) {
                final value = entry.value;
                if (value == null) continue;
                final text = value.toString().trim();
                if (text.isNotEmpty && text.toLowerCase() != 'null') {
                  return text;
                }
              }
            }
          }
          return null;
        }

        final titleRaw = valueFor([
          'title',
          'result',
          'resultTitle',
          'result_title',
          'outcome',
          'status',
          'winner',
          'gameResult',
          'game_result',
        ]);
        fields['title'] = _normalizeChessTitleValue(titleRaw);

        final movesRaw = valueFor([
          'moves',
          'moveCount',
          'move_count',
          'turns',
          'ply',
          'turn_count',
        ]);
        fields['moves'] = _parseExtractedNumber(movesRaw);

        final capturesRaw = valueFor([
          'captures',
          'captureCount',
          'capture_count',
          'piecesCaptured',
          'pieces_captured',
          'captured',
        ]);
        fields['captures'] = _parseExtractedNumber(capturesRaw);
      }
    } catch (_) {}

    fields['title'] ??= _extractChessResultTitle(text);
    fields['moves'] ??= _extractChessMoves(text);
    fields['captures'] ??= _extractChessCaptures(text);

    return fields;
  }

  String? _extractChessResultTitle(String text) {
    final source = text.toLowerCase();

    final labeled = RegExp(
      r'''(?:title|result|outcome|status)\s*["']?\s*[:=-]?\s*["']?(victory|defeat|draw)''',
      caseSensitive: false,
    ).firstMatch(source);
    if (labeled != null) {
      final value = (labeled.group(1) ?? '').trim();
      if (value.isNotEmpty) {
        return value[0].toUpperCase() + value.substring(1).toLowerCase();
      }
    }

    return _normalizeChessTitleValue(source);
  }

  int? _extractLikelyScore(String text) {
    final direct = _extractStatNumber(
      text,
      'userscore|user_score|score|points|best|final|finalscore',
    );
    if (direct != null) return direct;

    final allNumbers = _extractAllNumbers(text);
    if (allNumbers.isEmpty) return null;

    allNumbers.sort((a, b) => b.compareTo(a));
    return allNumbers.first;
  }

  int? _extractTilesScore(String text) {
    final direct = _extractStatNumber(
      text,
      'userscore|user_score|score|points|best|best[_\\s-]?score|final|final[_\\s-]?score|total|total[_\\s-]?score|tile[_\\s-]?score|game[_\\s-]?score|high[_\\s-]?score',
    );
    if (direct != null) return direct;

    return _extractLikelyScore(text);
  }

  int? _extractStrictTilesScore(String text) {
    return _extractStatNumber(
      text,
      'userscore|user_score|score|points|best|best[_\\s-]?score|final|final[_\\s-]?score|total|total[_\\s-]?score|tile[_\\s-]?score|game[_\\s-]?score|high[_\\s-]?score',
    );
  }

  int? _extractTilesLevel(String text) {
    return _extractStatNumber(
      text,
      'level|stage|round|lvl|tile[_\\s-]?level|current[_\\s-]?level',
    );
  }

  String _normalizeGameOverTextForParsing(String? rawText) {
    if (rawText == null) return '';
    String normalized = rawText.trim();
    if (normalized.isEmpty) return '';

    for (int i = 0; i < 2; i++) {
      try {
        final decoded = jsonDecode(normalized);
        if (decoded is String) {
          normalized = decoded.trim();
          continue;
        }
        if (decoded is Map || decoded is List) {
          normalized = jsonEncode(decoded);
          break;
        }
      } catch (_) {
        break;
      }
    }

    return normalized.replaceAll(r'\\"', '"').replaceAll(r'\n', ' ').trim();
  }

  String _buildGameCelebrationMessage(GameData? game) {
    if (game == null) return 'Well played!';

    final normalized = _normalizedGameName(game);

    if (normalized.contains('chess')) {
      return 'Nice Match';
    }

    if (normalized.contains('property') || normalized.contains('pursuit')) {
      return 'Good Run, You Property Tycoon!';
    }

    if (normalized.contains('flappy') || normalized.contains('fish')) {
      return 'Life is like Flappy Fish';
    }

    if (normalized.contains('tower') || normalized.contains('defense')) {
      return 'Good job defending your base!';
    }

    if (normalized.contains('tiles') || normalized.contains('puzzle')) {
      return 'Great Score';
    }

    return 'Great Run';
  }

  String _normalizeChessDifficultyLabel(String? difficulty) {
    final value = (difficulty ?? '').trim().toLowerCase();
    if (value == 'easy') return 'Easy';
    if (value == 'medium') return 'Medium';
    if (value == 'hard') return 'Hard';
    return 'Unknown';
  }

  String _normalizeChessResultLabel(String? title) {
    final value = (title ?? '').trim().toLowerCase();
    if (value.contains('victory')) return 'Victory';
    if (value.contains('defeat')) return 'Defeat';
    if (value.contains('draw')) return 'Draw';
    return 'Result';
  }

  String _buildChessNaturalSummary({
    required String gameName,
    required String actor,
    required String? difficulty,
    required String? title,
    required int? moves,
    required int? captures,
  }) {
    final difficultyLabel = _normalizeChessDifficultyLabel(difficulty);
    final resultLabel = _normalizeChessResultLabel(title);
    final movesText = moves != null ? '$moves moves' : 'moves n/a';
    final capturesText =
        captures != null ? '$captures captures' : 'captures n/a';

    if (resultLabel == 'Victory') {
      if (difficultyLabel == 'Hard') {
        return '$actor pulled off a hard-fought Victory on $gameName ($difficultyLabel) in $movesText with $capturesText.';
      }
      if (difficultyLabel == 'Medium') {
        return '$actor secured a solid Victory on $gameName ($difficultyLabel) in $movesText with $capturesText.';
      }
      return '$actor closed out a confident Victory on $gameName ($difficultyLabel) in $movesText with $capturesText.';
    }

    if (resultLabel == 'Defeat') {
      if (difficultyLabel == 'Hard') {
        return '$actor took a Defeat on $gameName against $difficultyLabel AI after $movesText and $capturesText.';
      }
      if (difficultyLabel == 'Medium') {
        return '$actor ended with a Defeat on $gameName ($difficultyLabel) after $movesText and $capturesText.';
      }
      return '$actor finished with a Defeat on $gameName ($difficultyLabel) after $movesText and $capturesText.';
    }

    if (resultLabel == 'Draw') {
      if (difficultyLabel == 'Hard') {
        return '$actor held a Draw on $gameName ($difficultyLabel) in $movesText with $capturesText.';
      }
      if (difficultyLabel == 'Medium') {
        return '$actor played to a Draw on $gameName ($difficultyLabel) in $movesText with $capturesText.';
      }
      return '$actor finished with a Draw on $gameName ($difficultyLabel) in $movesText with $capturesText.';
    }

    return '$actor finished a chess run on $gameName in $movesText with $capturesText at $difficultyLabel difficulty.';
  }

  String _buildShareProgressText(GameData game, String? gameOverText,
      {String? accomplishmentLink}) {
    final normalized = _normalizedGameName(game);
    final source = _normalizeGameOverTextForParsing(gameOverText);
    final score = _extractLikelyScore(source);
    final level = _extractStatNumber(source, 'level|stage');
    final turns = _extractStatNumber(source, 'turns|moves');
    final coins = _extractStatNumber(source, 'coins?');
    final distance = _extractStatNumber(source, 'distance');
    final difficulty = _extractDifficulty(source);

    if (normalized.contains('chess')) {
      final chess = _extractChessResultFields(source);
      final chessTitle = chess['title'] as String?;
      final chessMoves = chess['moves'] as int?;
      final chessCaptures = chess['captures'] as int?;
      final summary = _buildChessNaturalSummary(
        gameName: game.name,
        actor: 'I',
        difficulty: difficulty,
        title: chessTitle,
        moves: chessMoves,
        captures: chessCaptures,
      );
      return '$summary Can you top that?';
    }

    final isTilesGame =
        normalized.contains('tiles') || normalized.contains('puzzle');
    if (isTilesGame) {
      final tilesScore = _extractTilesScore(source);
      final tilesLevel = _extractTilesLevel(source);
      final lowerSource = source.toLowerCase();
      final hasLevelCompleteAction =
          lowerSource.contains('action: level_complete') ||
              lowerSource.contains('"action":"level_complete"') ||
              lowerSource.contains('action=level_complete');

      if (tilesScore != null && tilesLevel != null) {
        return 'Just finished ${game.name} at Level $tilesLevel with $tilesScore points — can you beat this run?';
      }
      if (tilesScore != null) {
        return 'Just scored $tilesScore on ${game.name} — can you top this?';
      }
      if (tilesLevel != null) {
        return 'Just reached Level $tilesLevel on ${game.name} — can you go further?';
      }
      if (hasLevelCompleteAction) {
        return 'Just cleared a level on ${game.name} — can you beat this run?';
      }
      debugPrint('[TilesShareFallback] source=$source');
      return 'Just wrapped a run on ${game.name} — can you beat me?';
    }

    final isScoreBased = normalized.contains('flappy') ||
        normalized.contains('fish') ||
        normalized.contains('property') ||
        normalized.contains('pursuit') ||
        normalized.contains('apes') ||
        normalized.contains('tower') ||
        normalized.contains('defense') ||
        normalized.contains('tasty');

    if (isScoreBased) {
      if (score != null && level != null) {
        return 'Just scored $score on ${game.name} (Level $level) — can you beat this?';
      }
      if (score != null) {
        return 'Just scored $score on ${game.name} — can you beat this?';
      }
      if (coins != null && distance != null) {
        return 'Just collected $coins coins and reached $distance distance on ${game.name} — can you beat this?';
      }
      if (coins != null) {
        return 'Just collected $coins coins on ${game.name} — can you beat this?';
      }
      if (distance != null) {
        return 'Just reached $distance distance on ${game.name} — can you beat this?';
      }
      if (level != null) {
        return 'Just reached level $level on ${game.name} — can you beat this?';
      }
      return 'Just put up a new run on ${game.name} — beat my next score.';
    }

    if (score != null) {
      return 'Just scored $score on ${game.name} — can you beat this?';
    }
    if (coins != null && distance != null) {
      return 'Just collected $coins coins and reached $distance distance on ${game.name} — challenge me.';
    }
    if (turns != null) {
      return 'Just finished ${game.name} in $turns turns — challenge me.';
    }
    if (level != null) {
      return 'Just reached level $level on ${game.name} — challenge me.';
    }
    return 'Just finished a run on ${game.name} — challenge me.';
  }

  String _buildChallengeShareText(
    GameData game,
    String challengeLink,
    String? gameOverText,
  ) {
    final normalized = _normalizedGameName(game);
    final source = _normalizeGameOverTextForParsing(gameOverText);
    final score = _extractLikelyScore(source);
    final level = _extractStatNumber(source, 'level|stage');
    final turns = _extractStatNumber(source, 'turns|moves');
    final coins = _extractStatNumber(source, 'coins?');
    final distance = _extractStatNumber(source, 'distance');
    final difficulty = _extractDifficulty(source);

    if (normalized.contains('chess')) {
      final chess = _extractChessResultFields(source);
      final chessTitle = chess['title'] as String?;
      final chessMoves = chess['moves'] as int?;
      final chessCaptures = chess['captures'] as int?;
      final summary = _buildChessNaturalSummary(
        gameName: game.name,
        actor: 'I',
        difficulty: difficulty,
        title: chessTitle,
        moves: chessMoves,
        captures: chessCaptures,
      );
      return '$summary Beat me 👀\n$challengeLink';
    }

    final isTilesGame =
        normalized.contains('tiles') || normalized.contains('puzzle');
    if (isTilesGame) {
      final tilesScore = _extractTilesScore(source);
      final tilesLevel = _extractTilesLevel(source);
      final lowerSource = source.toLowerCase();
      final hasLevelCompleteAction =
          lowerSource.contains('action: level_complete') ||
              lowerSource.contains('"action":"level_complete"') ||
              lowerSource.contains('action=level_complete');

      if (tilesScore != null && tilesLevel != null) {
        return 'I finished ${game.name} at Level $tilesLevel with $tilesScore points — beat this run 🎯\n$challengeLink';
      }
      if (tilesScore != null) {
        return 'I just scored $tilesScore on ${game.name} — beat me 🎯\n$challengeLink';
      }
      if (tilesLevel != null) {
        return 'I reached Level $tilesLevel on ${game.name} — beat me 🎯\n$challengeLink';
      }
      if (hasLevelCompleteAction) {
        return 'I just cleared a level on ${game.name} — beat this run 🎯\n$challengeLink';
      }
      debugPrint('[TilesChallengeFallback] source=$source');
      return 'Challenge me on ${game.name} 🎮\n$challengeLink';
    }

    final isScoreBased = normalized.contains('flappy') ||
        normalized.contains('fish') ||
        normalized.contains('property') ||
        normalized.contains('pursuit') ||
        normalized.contains('apes') ||
        normalized.contains('tower') ||
        normalized.contains('defense') ||
        normalized.contains('tasty');

    if (isScoreBased) {
      if (score != null) {
        return 'I just scored $score on ${game.name} — beat me 🎯\n$challengeLink';
      }
      if (coins != null && distance != null) {
        return 'I just collected $coins coins and hit $distance distance on ${game.name} — beat me 🎯\n$challengeLink';
      }
      if (coins != null) {
        return 'I just collected $coins coins on ${game.name} — beat me 🎯\n$challengeLink';
      }
      if (level != null) {
        return 'I just reached level $level on ${game.name} — beat me 🎯\n$challengeLink';
      }
      return 'Challenge me on ${game.name} 🎮\n$challengeLink';
    }

    if (score != null) {
      return 'I just scored $score on ${game.name} — beat me 🎯\n$challengeLink';
    }
    if (turns != null) {
      return 'I just finished ${game.name} in $turns turns — beat me 🎯\n$challengeLink';
    }
    if (coins != null) {
      return 'I just collected $coins coins on ${game.name} — beat me 🎯\n$challengeLink';
    }

    return 'Challenge me on ${game.name} 🎮\n$challengeLink';
  }

  bool _hasDerivableMiniGameResult(String? gameName, String? gameOverText) {
    final source = _normalizeGameOverTextForParsing(gameOverText);
    if (source.isEmpty) return false;

    final normalized = (gameName ?? '').toLowerCase();

    // Chess completion is considered valid only when we have a valid title,
    // captures, and moves. This prevents misreporting of results and false positives.
    if (normalized.contains('chess')) {
      final chess = _extractChessResultFields(source);
      final title = chess['title'] as String?;
      final captures = chess['captures'] as int?;
      final moves = chess['moves'] as int?;

      // Title must be a valid chess result (Victory, Defeat, or Draw)
      final lowerTitle = title?.toLowerCase() ?? '';
      final hasValidTitle = lowerTitle == 'victory' ||
          lowerTitle == 'defeat' ||
          lowerTitle == 'draw';

      // Must have captures and moves indicating actual gameplay
      final hasGameplay =
          captures != null && captures > 0 && moves != null && moves > 0;

      return hasValidTitle && hasGameplay;
    }

    // Tasty Tiles / puzzle completion requires a real score value.
    if (normalized.contains('tiles') || normalized.contains('puzzle')) {
      final score = _extractStrictTilesScore(source);
      return score != null && score > 0;
    }

    final lowerSource = source.toLowerCase();

    return _extractLikelyScore(source) != null ||
        _extractStatNumber(source, 'level|stage') != null ||
        _extractStatNumber(source, 'turns|moves') != null ||
        _extractStatNumber(source, 'coins?') != null ||
        _extractStatNumber(source, 'distance') != null ||
        lowerSource.contains('score') ||
        lowerSource.contains('points');
  }

  Future<void> _copyChallengeLink(String gameName, String challengeLink) async {
    await Clipboard.setData(ClipboardData(text: challengeLink));
    if (!mounted) return;
    ToastService.showToast(
      context,
      backgroundColor: Theme.of(context).cardColor,
      shadowColor: Colors.transparent,
      leading: const Icon(Icons.link, color: Colors.greenAccent),
      message: 'Challenge link copied for $gameName',
    );
  }

  Future<void> _shareChallengeLink(
    GameData game,
    String challengeLink,
    String? gameOverText,
  ) async {
    final text = _buildChallengeShareText(game, challengeLink, gameOverText);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Challenge me on ${game.name}',
      ),
    );
  }

  Future<void> _showChallengeOptions(
    BuildContext parentContext,
    GameData game,
    String? gameOverText,
  ) async {
    final challengeLink = _buildMiniGameChallengeLink(game.id);

    await showModalBottomSheet<void>(
      context: parentContext,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.copy, color: theme.iconTheme.color),
                title: const Text('Copy link'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _copyChallengeLink(game.name, challengeLink);
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: theme.iconTheme.color),
                title: const Text('Native share'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _shareChallengeLink(game, challengeLink, gameOverText);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGameEndDialog(
    BuildContext parentContext,
    MiniGameCompletion completion,
  ) {
    Future.microtask(() {
      final selectedGame = completion.game ?? _lastCompletedMiniGame;
      final resolvedGameOverText =
          completion.gameOverText ?? _lastCompletedMiniGameOverText;

      if (!completion.playedLikely ||
          !_hasDerivableMiniGameResult(
              selectedGame?.name, resolvedGameOverText)) {
        return;
      }

      final gameName = selectedGame?.name ?? 'this game';
      final gameId = selectedGame?.id ?? 'minigame';
      final gameIcon = selectedGame?.iconUrl ?? '';
      final accomplishmentLink = selectedGame != null
          ? AppsFlyerService()
              .generateMinigameAccomplishmentLink(selectedGame.id)
          : null;
      final prefilledText = selectedGame != null
          ? _buildShareProgressText(selectedGame, resolvedGameOverText,
              accomplishmentLink: accomplishmentLink)
          : 'Just completed a run on $gameName — can you beat this?';

      if (!parentContext.mounted) return;
      showDialog(
        context: parentContext,
        barrierDismissible: true,
        builder: (dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gradient header with game icon
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14CFEE), Color(0xFF2196F3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          // Game icon or trophy emoji
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: gameIcon.isNotEmpty
                                ? ClipOval(
                                    child: Image(
                                      image:
                                          CachedNetworkImageProvider(gameIcon),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                        child: Text(
                                          '🏆',
                                          style: TextStyle(fontSize: 32),
                                        ),
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Text(
                                      '🏆',
                                      style: TextStyle(fontSize: 32),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Game Over',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            gameName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Celebratory status text (non-interactive)
                          Column(
                            children: [
                              const Text(
                                '🎮',
                                style: TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _buildGameCelebrationMessage(selectedGame),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2196F3),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Challenge button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF14CFEE),
                                    Color(0xFF2196F3)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2196F3)
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    await _showChallengeOptions(
                                        parentContext,
                                        GameData(
                                          id: gameId,
                                          name: gameName,
                                          iconUrl: gameIcon,
                                          description:
                                              selectedGame?.description ?? '',
                                          iconFallback:
                                              selectedGame?.iconFallback,
                                        ),
                                        resolvedGameOverText);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sports_esports,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Challenge a Friend',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Share button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      const Color(0xFF2196F3).withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (!mounted) return;
                                    parentContext.push(Routes.postChat, extra: {
                                      'name': gameName,
                                      'profileImageURL': gameIcon,
                                      'chat': 'Completed a level in $gameName.',
                                      'avatarID': gameId,
                                      'initialText': prefilledText,
                                      'minigameLink': accomplishmentLink,
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.share,
                                        color: Color(0xFF2196F3),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Share Progress',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2196F3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Close button
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const systemUiOverlayStyle = SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    // viewInsetsOf only subscribes to inset changes (keyboard), not every
    // MediaQuery change like size/padding.
    _isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    // Check if current route is one of the main tab routes
    final String location = GoRouterState.of(context).matchedLocation;
    final bool isMainTabRoute = _routes.contains(location);

    return Stack(
      children: [
        Scaffold(
          key: _key,
          backgroundColor: Theme.of(context).canvasColor,
          extendBody: true,
          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              if (_isExpanded) {
                _toggleExpanded();
              }
            },
            // Use IndexedStack for main tab routes, otherwise use the provided child for nested routes
            child: Stack(
                children: [
                  isMainTabRoute
                      ? IndexedStack(
                          index: _currentPage,
                          children: _screens,
                        )
                      : widget
                          .child, // Use the provided child for non-tab routes

                  // Full screen semi-transparent overlay
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _isExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: _isExpanded ? Curves.easeOut : Curves.easeIn,
                      child: IgnorePointer(
                        ignoring: !_isExpanded,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleExpanded,
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Option buttons (absolute top layer)
                  Positioned(
                    bottom: 135,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _isExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: _isExpanded ? Curves.easeOut : Curves.easeIn,
                      child: IgnorePointer(
                        ignoring: !_isExpanded,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // _buildAnimatedOptionButton(
                            //   'Create 3D Avatar',
                            //   Icons.person,
                            //   () {
                            //     print("Create 3D Avatar button tapped");
                            //     _toggleExpanded();
                            //     context.push(Routes.create3dModelIntro);
                            //   },
                            //   0,
                            // ),
                            // const SizedBox(height: 16),
                            _buildAnimatedOptionButton(
                              'Create AI Character',
                              Icons.face,
                              () {
                                print("Create AI Character button tapped");
                                _toggleExpanded();
                                context.push(Routes.createAICharacter);
                              },
                              1,
                            ),
                            const SizedBox(height: 16),
                            _buildAnimatedOptionButton(
                              'Create Post',
                              Icons.post_add,
                              () {
                                print("Create Post button tapped");
                                _toggleExpanded();
                                context.push(Routes.post);
                              },
                              2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: (_isKeyboardVisible || _miniGameMenuOpen)
              ? null
              : AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: _isNavBarVisible ? Offset.zero : const Offset(0, 2),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isNavBarVisible ? 1.0 : 0.0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        print("Main FAB button tapped");
                        _toggleExpanded();
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF14CFEE),
                              Color(0xFF2196F3),
                            ],
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value * 2.0 * 3.14159,
                              child: const Icon(
                                Icons.add,
                                size: 28,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
          bottomNavigationBar: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: (_isKeyboardVisible || _miniGameMenuOpen)
                ? const SizedBox.shrink(key: ValueKey('navBarHidden'))
                : AnimatedSlide(
                    duration: const Duration(milliseconds: 200),
                    offset: _isNavBarVisible ? Offset.zero : const Offset(0, 1),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isNavBarVisible ? 1.0 : 0.0,
                      child: SafeArea(
                        bottom: false,
                        child: AnimatedBottomNavigationBar.builder(
                          key: const ValueKey('navBar'),
                          itemCount: _bottomNavBarTitles.length,
                          tabBuilder: (int index, bool isActive) {
                            return Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      isActive
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .unselectedWidgetColor,
                                      BlendMode.srcIn,
                                    ),
                                    child: Iconify(
                                      _iconifyPaths[index],
                                      size: 100,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          activeIndex: _currentPage,
                          splashSpeedInMilliseconds: 0,
                          gapLocation: GapLocation.center,
                          notchSmoothness: NotchSmoothness.softEdge,
                          leftCornerRadius: 32,
                          rightCornerRadius: 32,
                          onTap: _onItemTapped,
                          backgroundColor: Theme.of(context).cardColor,
                          splashColor: Colors.transparent,
                          splashRadius: 0,
                          shadow: const BoxShadow(
                            color: Colors.transparent,
                            blurRadius: 0,
                            spreadRadius: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ), // end Scaffold
        // Simula MiniGameMenu overlay — outside Scaffold so it covers bottom bar
        Builder(
          builder: (context) {
            final activeCharacter = context.watch<ActiveCharacterNotifier>();
            final resolvedCharImage = (activeCharacter.charImage != null &&
                    activeCharacter.charImage!.trim().isNotEmpty)
                ? activeCharacter.charImage!
                : _fallbackMiniGameImage(context);

            return MiniGameMenu(
              isOpen: _miniGameMenuOpen,
              onClose: () {
                setState(() {
                  _miniGameMenuOpen = false;
                  _pendingMiniGameDeepLinkGameId = null;
                });
              },
              onGameEnd: (completion) async {
                final handoffSource =
                    _normalizeGameOverTextForParsing(completion.gameOverText);
                final isChess =
                    (completion.game?.id ?? '').toLowerCase().contains('chess');
                if (isChess) {
                  final chessFields = _extractChessResultFields(handoffSource);
                  final handoffDifficulty = _extractDifficulty(handoffSource);
                  debugPrint(
                    '[MiniGameCompletionHandoff] game=${completion.game?.id ?? 'unknown'} playedLikely=${completion.playedLikely} title=${chessFields['title'] ?? 'n/a'} moves=${chessFields['moves'] ?? 'n/a'} captures=${chessFields['captures'] ?? 'n/a'} difficulty=${handoffDifficulty ?? 'n/a'} raw=${handoffSource.isEmpty ? 'null' : handoffSource}',
                  );
                } else {
                  debugPrint(
                    '[MiniGameCompletionHandoff] game=${completion.game?.id ?? 'unknown'} playedLikely=${completion.playedLikely} gameOverText=${completion.gameOverText ?? 'null'}',
                  );
                }
                if (_miniGameMenuOpen) {
                  setState(() {
                    _miniGameMenuOpen = false;
                    _pendingMiniGameDeepLinkGameId = null;
                  });
                }

                _lastCompletedMiniGame = completion.game;
                _lastCompletedMiniGameOverText = completion.gameOverText;

                await Future.delayed(const Duration(milliseconds: 220));
                if (!mounted || !context.mounted) return;

                _showGameEndDialog(context, completion);
              },
              onCharacterTap: _openMiniGameWithCharacterPicker,
              charName: activeCharacter.charName,
              charID: activeCharacter.charID,
              charImage: resolvedCharImage,
              charDesc: activeCharacter.charDesc,
              messages: _miniGameMessages,
              delegateChar: true,
              maxGamesToShow: 6,
              initialGameId: _pendingMiniGameDeepLinkGameId,
              theme: MiniGameTheme(
                backgroundColor: Theme.of(context).cardColor,
                headerColor: Theme.of(context).canvasColor,
                borderColor: const Color(0xFF2196F3).withValues(alpha: 0.15),
                titleFontColor: Theme.of(context).textTheme.bodyLarge?.color,
                secondaryFontColor: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
                accentColor: const Color(0xFF14CFEE),
                iconCornerRadius: 16.0,
                playableHeight: 0.95, // 95% of screen to avoid dynamic island
                playableBorderColor: const Color(0xFF2196F3),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedOptionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    int index,
  ) {
    return AnimatedOpacity(
      opacity: _isExpanded ? 1.0 : 0.0,
      duration: Duration(milliseconds: _isExpanded ? 300 + (index * 100) : 200),
      curve: _isExpanded ? Curves.easeOutBack : Curves.easeIn,
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          top: _isExpanded ? 0 : 20,
        ),
        duration:
            Duration(milliseconds: _isExpanded ? 300 + (index * 100) : 200),
        curve: _isExpanded ? Curves.easeOutBack : Curves.easeIn,
        child: Center(
          child: IntrinsicWidth(
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                padding: const EdgeInsets.only(
                    left: 5, right: 15, top: 10, bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show a feedback popup dialog
  Future<void> showFeedbackPopup(BuildContext context) async {
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (BuildContext dialogContext) {
        // Create controllers inside the builder to tie them to the widget lifecycle
        final TextEditingController feedbackController =
            TextEditingController();
        final TextEditingController emailController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 5,
              backgroundColor: Theme.of(context).cardColor,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title
                    Center(
                      child: Text(
                        'We Value Your Feedback',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.titleLarge?.color,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Help us improve your experience',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email input
                    Text(
                      'Your Email',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                        color: Theme.of(context).cardColor,
                      ),
                      child: TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Enter your email address',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Feedback input
                    Text(
                      'Your Feedback',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                        color: Theme.of(context).cardColor,
                      ),
                      child: TextField(
                        controller: feedbackController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Let us know your thoughts...',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        enabled: !isSubmitting,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Cancel button
                        TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  Navigator.of(dialogContext).pop();
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Submit button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: isSubmitting
                                ? LinearGradient(
                                    colors: [
                                      Colors.grey.shade400,
                                      Colors.grey.shade500,
                                    ],
                                  )
                                : const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF14CFEE),
                                      Color(0xFF2196F3),
                                    ],
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (feedbackController.text.isEmpty) {
                                      ToastService.showToast(
                                        context,
                                        backgroundColor:
                                            Theme.of(context).canvasColor,
                                        shadowColor: Colors.transparent,
                                        leading: const Icon(
                                          FeatherIcons.xCircle,
                                          color: Colors.redAccent,
                                        ),
                                        message: "Please enter your feedback'",
                                      );
                                      return;
                                    }

                                    setState(() {
                                      isSubmitting = true;
                                    });

                                    // Capture values before potential disposal
                                    final String email = emailController.text;
                                    final String feedback =
                                        feedbackController.text;

                                    // Send feedback to server
                                    final bool feedbackSent =
                                        await _sendFeedbackToServer(
                                      email,
                                      feedback,
                                    );

                                    // Only navigate if the dialog is still showing
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();

                                      ToastService.showToast(
                                        context,
                                        backgroundColor:
                                            Theme.of(context).canvasColor,
                                        shadowColor: Colors.transparent,
                                        leading: Icon(
                                          feedbackSent
                                              ? FeatherIcons.checkCircle
                                              : FeatherIcons.xCircle,
                                          color: feedbackSent
                                              ? Colors.green
                                              : Colors.redAccent,
                                        ),
                                        message: feedbackSent
                                            ? 'Thank you for your feedback!'
                                            : 'Could not send feedback. Please try again later.',
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Submit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Send feedback to server
  Future<bool> _sendFeedbackToServer(String userEmail, String feedback) async {
    try {
      const String apiUrl =
          'https://inzoneapi-912424781531.us-central1.run.app/feedback';

      final Map<String, dynamic> payload = {
        "email": userEmail.isEmpty ? "anonymous_user" : userEmail,
        "Feedback": feedback
      };

      print('Sending feedback to server: $payload');

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Server response: $responseData');
        return responseData['success'] ?? false;
      } else {
        print('Server error: ${response.statusCode}, ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending feedback to server: $e');
      return false;
    }
  }

  Future<void> _checkAndRequestReview() async {
    final prefs = await SharedPreferences.getInstance();

    appOpenCounter = prefs.getInt('appOpenCounter') ?? 0;
    appOpenCounter++;
    await prefs.setInt('appOpenCounter', appOpenCounter);

    print('App opened $appOpenCounter times');

    // Fixed condition - only show at specific counts
    if (appOpenCounter == 10 || appOpenCounter == 33) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        showFeedbackPopup(context);
      });
    }
    // Show app review at 3rd and 21st app opens
    else if (appOpenCounter == 3 || appOpenCounter == 21) {
      Future.delayed(const Duration(seconds: 2), () async {
        if (await inAppReview.isAvailable()) {
          inAppReview.requestReview();
        }
      });
    }
  }
}
