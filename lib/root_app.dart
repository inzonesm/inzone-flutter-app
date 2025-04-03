import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:inzone/all_chats_screen.dart';
import 'package:inzone/groups_explore_screen.dart';
import 'package:inzone/home_screen.dart';
import 'package:inzone/post_screen.dart';
import 'package:inzone/settings_screen.dart';
import 'package:sliding_sheet2/sliding_sheet2.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  _RootAppState createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> with SingleTickerProviderStateMixin {
  final bool _isDrawerOpen = false;
  int _currentPage = 0; // Track selected tab index
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey(); // Key to access HomeScreen state
  final ScrollController _homeScrollController = ScrollController();

  final _key = GlobalKey<ExpandableFabState>();

  final List<String> titleList = [
    'Home',
    'Groups',
    'Chats',
    'Profile',
  ];

  @override
  void initState() {
    _pages = [
      HomeScreen( controller: _homeScrollController), // Assign the GlobalKey to HomeScreen
      const GroupsExploreScreen(),
      const AllChatsScreen(),
      const SettingsScreen(),
    ];
    super.initState();
  }

  late List<Widget>_pages ;
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
    return titleList[page];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(
          elevation: 0,

          automaticallyImplyLeading: false,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).canvasColor,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      floatingActionButton: FloatingActionButton(
        heroTag: null,
        foregroundColor: Colors.white,
        elevation: 8,
        backgroundColor: Colors.transparent,
        onPressed: () {
          showSlidingBottomSheet(context,
              builder: (context) => SlidingSheetDialog(
                cornerRadius: 30,
                backdropColor:
                Theme.of(context).canvasColor.withOpacity(0.6),
                duration: const Duration(seconds: 1),
                snapSpec: const SnapSpec(snappings: [0.9]),
                builder: (context, state) {
                  return const PostScreen();
                },
              ));
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
      backgroundColor: Theme.of(context).canvasColor,
      body:
      NotificationListener<ScrollNotification>(
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


        child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  // toolbarHeight: 30,
                  // collapsedHeight: 30,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    surfaceTintColor: Colors.transparent,
                    backgroundColor:  Theme.of(context).canvasColor,
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getPageTitle(_currentPage),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(fontSize: 30),
                        ),
                        const Spacer(),
                        // _currentPage == 0
                        //     ? GestureDetector(
                        //         onTap: () {
                        //           Navigator.push(
                        //               context,
                        //               MaterialPageRoute(
                        //                   builder: (context) =>
                        //                       const ExploreScreen()));
                        //         },
                        //         child: const Icon(
                        //           Icons.search,
                        //           color: Colors.black,
                        //           size: 22,
                        //         ))
                        //     : SizedBox(),
                        const SizedBox(
                          width: 10,
                        ),
                        _currentPage == 0
                            ? GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                      const AllChatsScreen()));
                            },
                            child: const SizedBox(
                                height: 16,
                                width: 16,
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.black,
                                  size: 21,
                                )))
                            : const SizedBox(),
                      ],
                    ))
              ];
            },
            body: _pages[_currentPage]

        ),
      ),

      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: titleList.length,
        tabBuilder: (int index, bool isActive) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                isActive
                    ? 'icons/nav_bar_icons/${titleList[index].toLowerCase()}_selected.png'
                    : 'icons/nav_bar_icons/${titleList[index].toLowerCase()}_unselected.png',
                width: 24,
                height: 24,
              ),
              const SizedBox(height: 4),
              Text(
                titleList[index],
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

