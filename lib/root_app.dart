import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:inzone/screen/common/home_screen.dart';
import 'package:inzone/screen/explore/groups_explore_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/profile/user_profile_screen.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart';
import 'package:iconify_flutter/icons/mdi.dart';
import 'package:iconify_flutter/icons/heroicons_outline.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/heroicons_solid.dart';

class RootApp extends StatefulWidget {
  final Widget child;

  const RootApp({super.key, required this.child});

  @override
  _RootAppState createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> with SingleTickerProviderStateMixin {
  int _currentPage = 0; // Track selected tab index
  final ScrollController _homeScrollController = ScrollController();
  final _key = GlobalKey<ExpandableFabState>();
  bool _isKeyboardVisible = false;
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

    // Initialize screens with the controller
    _screens = [
      HomeScreen(controller: _homeScrollController),
      const GroupsExploreScreen(),
      AllChatsScreen(key: allChatsScreenKey),
      const UserProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();

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
        }
      }
    }

    // Update the current page index
    setState(() {
      _currentPage = index;
    });

    // Update the URL without rebuilding the page
    context.go(_routes[index], extra: {'skipRebuild': true});
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
    Ph.user,
  ];

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

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: _key,
        backgroundColor: Theme.of(context).canvasColor,
        extendBody: true,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _isKeyboardVisible
            ? null
            : FloatingActionButton(
                heroTag: null,
                elevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: () {
                  context.push(Routes.post);
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
                  child: const Icon(Icons.add, size: 28, color: Colors.white),
                ),
              ),
        body: NotificationListener<ScrollNotification>(
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
          child: isMainTabRoute
              ? IndexedStack(
                  index: _currentPage,
                  children: _screens,
                )
              : widget.child, // Use the provided child for non-tab routes
        ),
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isKeyboardVisible
              ? const SizedBox.shrink()
              : SafeArea(
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
                                size: 100, // 실제 크기는 FittedBox가 제어함
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
    );
  }
}
