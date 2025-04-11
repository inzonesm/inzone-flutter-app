import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/explore/groups_explore_screen.dart';
import 'package:inzone/screen/common/home_screen.dart';
import 'package:inzone/screen/post/post_screen.dart';
import 'package:inzone/screen/profile/user_profile_screen.dart';
import 'package:inzone/screen/settings/settings_screen.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  _RootAppState createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> with SingleTickerProviderStateMixin {
  int _currentPage = 0; // Track selected tab index
// Key to access HomeScreen state
  final ScrollController _homeScrollController = ScrollController();

  final _key = GlobalKey<ExpandableFabState>();

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
       UserProfileScreen(),
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
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent, // 외곽 투명하게
        builder: (context) {
          return _AnimatedBottomSheetContent(curve: curve);
        },
      );
    }

    return Scaffold(
      key: _key,
      backgroundColor: Theme.of(context).canvasColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        foregroundColor: Colors.white,
        elevation: 8,
        backgroundColor: Colors.transparent,
        onPressed: () {
          showPostScreen(context, curve: Curves.fastEaseInToSlowEaseOut);
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF14CFEE),
                Color(0xFF2196F3),
              ],
            ),
          ),
          child: const Icon(Icons.add, size: 28),
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
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: _bottomNavBarTitles.length,
        tabBuilder: (int index, bool isActive) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                isActive
                    ? 'icons/nav_bar_icons/${_bottomNavBarTitles[index].toLowerCase()}_selected.png'
                    : 'icons/nav_bar_icons/${_bottomNavBarTitles[index].toLowerCase()}_unselected.png',
                width: 24,
                height: 24,
              ),
              const SizedBox(height: 4),
              Text(
                _bottomNavBarTitles[index],
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.blue : Colors.grey,
                ),
              )
            ],
          );
        },
        activeIndex: _currentPage,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.defaultEdge,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        leftCornerRadius: 0,
        rightCornerRadius: 0,
        elevation: 8,
      ),
    );
  }
}

class _AnimatedBottomSheetContent extends StatefulWidget {
  final Curve curve;
  const _AnimatedBottomSheetContent({required this.curve});

  @override
  State<_AnimatedBottomSheetContent> createState() =>
      _AnimatedBottomSheetContentState();
}

class _AnimatedBottomSheetContentState
    extends State<_AnimatedBottomSheetContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: const PostScreen(),
      ),
    );
  }
}
