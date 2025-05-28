import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _key = GlobalKey<ScaffoldState>();
  bool _isKeyboardVisible = false;
  bool _isExpanded = false;
  bool _isNavBarVisible = true; // Track visibility of navigation bar
  double _lastScrollPosition = 0; // Keep track of the last scroll position

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
    _homeScrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _homeScrollController.removeListener(_handleScroll);
    _homeScrollController.dispose();
    _rootFocusNode.dispose();
    _rotationController.dispose();
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

    return Scaffold(
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
                        //     context.push(Routes.create3dModel);
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
      floatingActionButton: _isKeyboardVisible
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
        child: _isKeyboardVisible
            ? const SizedBox.shrink()
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
      ),
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
}
