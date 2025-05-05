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
  final List<Widget> _screens = [
    const HomeScreen(),
    const GroupsExploreScreen(),
    const AllChatsScreen(),
    const UserProfileScreen(),
  ];

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
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_currentPage == index) {
      // If same tab is tapped again, do any special handling here
      if (index == 0) {
        // For home tab, could implement scroll to top functionality
        // or other refresh logic
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
                      final String iconName =
                          _bottomNavBarTitles[index].toLowerCase();
                      return Center(
                        child: Image.asset(
                          isActive
                              ? 'icons/nav_bar_icons/${iconName}_selected.png'
                              : 'icons/nav_bar_icons/${iconName}_unselected.png',
                          width: 24,
                          height: 24,
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
