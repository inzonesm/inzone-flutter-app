import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:inzone/screen/common/home_screen.dart';
import 'package:inzone/screen/explore/groups_explore_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/profile/user_profile_screen.dart';
import 'package:inzone/components/video/video_widget.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart';
import 'package:iconify_flutter/icons/mdi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/heroicons_solid.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:simula_ads/simula_ads.dart';
import 'package:provider/provider.dart';
import 'package:inzone/services/active_character_notifier.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _RootAppState extends State<RootApp> with SingleTickerProviderStateMixin {
  static const String _defaultMiniGameCharacterId = 'inzone-default';
  int _currentPage = 0; // Track selected tab index
  final ScrollController _homeScrollController = ScrollController();
  final _key = GlobalKey<ScaffoldState>();
  bool _isKeyboardVisible = false;
  bool _isExpanded = false;
  bool _isNavBarVisible = true; // Track visibility of navigation bar
  double _lastScrollPosition = 0; // Keep track of the last scroll position
  bool _miniGameMenuOpen = false;
  bool _isLoadingPopularCharacters = false;
  List<_PopularCharacterOption> _popularCharacters = const [];
  List<Message> _miniGameMessages = const [];

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
    'Groups',
    'Chats',
    'Profile',
  ];

  final List<String> _routes = [
    Routes.home,
    Routes.groups,
    Routes.chats,
    Routes.profile_tab,
  ];

  @override
  void initState() {
    super.initState();

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
      const GroupsExploreScreen(),
      AllChatsScreen(key: allChatsScreenKey),
      const UserProfileScreen(),
    ];

    // Add scroll listener to handle navbar visibility
    // _homeScrollController.addListener(_handleScroll);

    // Check app open count and request review if needed
    _checkAndRequestReview();
  }

  @override
  void dispose() {
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

    // Gamepad tab (index 3) opens MiniGameMenu instead of navigating
    if (index == 3) {
      if (!_miniGameMenuOpen) {
        setState(() {
          _miniGameMenuOpen = true;
        });
      }
      _loadPopularCharacters();
      final activeCharacter = context.read<ActiveCharacterNotifier>();
      _refreshMiniGameMessages(
        charID: activeCharacter.charID,
        charName: activeCharacter.charName,
        charDesc: activeCharacter.charDesc,
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? 'https://firebasestorage.googleapis.com/v0/b/inzone-app.appspot.com/o/app_assets%2Finzone_icon_white.png?alt=media'
        : 'https://firebasestorage.googleapis.com/v0/b/inzone-app.appspot.com/o/app_assets%2Finzone_icon_dark.png?alt=media';
  }

  Future<void> _loadPopularCharacters() async {
    if (_isLoadingPopularCharacters) return;

    setState(() {
      _isLoadingPopularCharacters = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('popularCharacters')
          .orderBy('numberOfChats', descending: true)
          .limit(30)
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
    await _loadPopularCharacters();
    if (!mounted) return;

    final activeCharacter = context.read<ActiveCharacterNotifier>();
    final selected = await showModalBottomSheet<_PopularCharacterOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.62,
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
                        final isActive = activeCharacter.charID == character.id;

                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isActive
                                  ? const Color(0xFF14CFEE)
                                  : theme.dividerColor.withValues(alpha: 0.35),
                            ),
                          ),
                          tileColor: theme.canvasColor,
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.cardColor,
                            backgroundImage: (character.imageUrl != null &&
                                    character.imageUrl!.isNotEmpty)
                                ? NetworkImage(character.imageUrl!)
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
    _updateCurrentPageFromRoute(context);
  }

  bool isUserScrolling = false;

  // Function to return the title based on the current page
  String _getPageTitle(int page) {
    if (page == 1) {
      return 'Explore Groups';
    }
    return _bottomNavBarTitles[page];
  }

  final List<String> _iconifyPaths = [
    Ri.home_5_fill,
    Mdi.account_group,
    HeroiconsSolid.chat_bubble_oval_left_ellipsis,
    // Ri.gamepad_fill
    Mdi.gamepad_variant
    // Ph.user,
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

  @override
  Widget build(BuildContext context) {
    const systemUiOverlayStyle = SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

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
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification is ScrollStartNotification) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    isUserScrolling = true;
                  });
                }
              });
            } else if (notification is ScrollEndNotification) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    isUserScrolling = false;
                  });
                }
              });
            }
            return false; // false: allow scroll event to continue propagating
          },
          // Use IndexedStack for main tab routes, otherwise use the provided child for nested routes
          child: Stack(
            children: [
              isMainTabRoute
                  ? IndexedStack(
                      index: _currentPage,
                      children: _screens,
                    )
                  : widget.child, // Use the provided child for non-tab routes

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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).unselectedWidgetColor,
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
            final resolvedCharImage =
                (activeCharacter.charImage != null &&
                        activeCharacter.charImage!.trim().isNotEmpty)
                    ? activeCharacter.charImage!
                    : _fallbackMiniGameImage(context);

            return MiniGameMenu(
              isOpen: _miniGameMenuOpen,
              onClose: () => setState(() => _miniGameMenuOpen = false),
              onCharacterTap: _openMiniGameWithCharacterPicker,
              charName: activeCharacter.charName,
              charID: activeCharacter.charID,
              charImage: resolvedCharImage,
              charDesc: activeCharacter.charDesc,
              messages: _miniGameMessages,
              delegateChar:
                  activeCharacter.charID == _defaultMiniGameCharacterId,
              maxGamesToShow: 6,
              theme: MiniGameTheme(
                backgroundColor: Theme.of(context).cardColor,
                headerColor: Theme.of(context).canvasColor,
                borderColor: const Color(0xFF2196F3).withValues(alpha: 0.15),
                titleFontColor:
                    Theme.of(context).textTheme.bodyLarge?.color,
                secondaryFontColor: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
                accentColor: const Color(0xFF14CFEE),
                iconCornerRadius: 16.0,
                playableHeight: null, // full screen mode
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
