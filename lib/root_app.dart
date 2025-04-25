import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/explore/groups_explore_screen.dart';
import 'package:inzone/screen/common/home_screen.dart';
import 'package:inzone/screen/post/post_screen.dart';
import 'package:inzone/screen/profile/user_profile_screen.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/cupertino.dart';

class RootApp extends StatefulWidget {
  const RootApp({super.key});

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

  final List<String> _bottomNavBarTitles = [
    'Home',
    'Groups',
    'Chats',
    'Profile',
  ];

  @override
  void initState() {
    _pages = [
      HomeScreen(
          controller:
              _homeScrollController), // Assign the GlobalKey to HomeScreen
      const GroupsExploreScreen(),
      const AllChatsScreen(),
      const UserProfileScreen(),
    ];
    super.initState();
  }

  late List<Widget> _pages;
  void _onItemTapped(int index) {
    if (_currentPage == index) {
      // Reload the HomeScreen when it's already active
      if (index == 0) {
        // If Home is tapped and is already selected, scroll to the top
        _homeScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        setState(() {
          _currentPage = index;
        });
        // _homeScreenKey.currentState?.getFeed(isRefresh: true);
      }
    } else {
      setState(() {
        _currentPage = index;
      });
    }
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _rootFocusNode.dispose();
    super.dispose();
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
    void showPostScreen(BuildContext context,
        {Curve curve = Curves.easeInOut}) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) {
            return const PostScreen();
          },
          fullscreenDialog: true, // This makes the page come up from the bottom
        ),
      );
    }

    // Check if keyboard is visible
    _isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside of input fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: _key,
        backgroundColor: Theme.of(context).canvasColor,
        extendBody: true, // 바텀 네비게이션 바 아래 영역까지 content가 확장됨
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _isKeyboardVisible
            ? null // Hide FAB when keyboard is visible
            : FloatingActionButton(
                heroTag: null,
                elevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: () {
                  showPostScreen(context,
                      curve: Curves.fastEaseInToSlowEaseOut);
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
              setState(() {
                isUserScrolling = true;
              });
            } else if (notification is ScrollEndNotification) {
              setState(() {
                isUserScrolling = false;
              });
            }
            return false;
          },
          child: Column(
            children: <Widget>[
              Expanded(
                child: IndexedStack(index: _currentPage, children: _pages),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isKeyboardVisible
              ? const SizedBox.shrink()
              : AnimatedBottomNavigationBar.builder(
                  key: const ValueKey('navBar'), // 항상 같은 위젯인지 판별할 수 있게 key 부여
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
    );
  }
}
