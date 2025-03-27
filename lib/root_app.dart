import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_svg/svg.dart';
import 'package:inzone/all_chats_screen.dart';
import 'package:inzone/character_creation_screen.dart';
import 'package:inzone/explore_screen.dart';
import 'package:inzone/home_screen.dart';
import 'package:inzone/post_screen.dart';
import 'package:inzone/saved_screen.dart';
import 'package:inzone/settings_screen.dart';
import 'package:inzone/user_profile_screen.dart';
import 'package:sliding_sheet2/sliding_sheet2.dart';
import 'dart:async';

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
  @override
  void initState() {
    _pages = [
      HomeScreen( controller: _homeScrollController), // Assign the GlobalKey to HomeScreen
      const UserProfileScreen(),
      const SavedScreen(),
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
    switch (page) {
      case 0:
        return "InZone";
      case 1:
        return "Profile";
      case 2:
        return "Favorites";
      // Add more cases as needed for additional pages
      default:
        return "Settings"; // Default title
    }
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      //floatingActionButtonLocation: ExpandableFab.location,
      // floatingActionButton: ExpandableFab(
      //   openButtonBuilder: RotateFloatingActionButtonBuilder(
      //     child: SvgPicture.asset('icons/post.svg'),
      //     fabSize: ExpandableFabSize.regular,
      //     foregroundColor: Colors.black,
      //     backgroundColor: Theme.of(context).canvasColor,
      //   ),
      //   overlayStyle: ExpandableFabOverlayStyle(
      //     color: Colors.black.withOpacity(0.5),
      //     blur: 5,
      //   ),
      //   onOpen: () {},
      //   afterOpen: () {
      //     final state = _key.currentState;
      //     if (state != null) {
      //       state.toggle();
      //     }
      //   },
      //   onClose: () {},
      //   afterClose: () {},
      //   children: [
      //     // FloatingActionButton.small(
      //     //   // shape: const CircleBorder(),
      //     //   heroTag: null,
      //     //   foregroundColor: Colors.black,
      //     //   backgroundColor: Theme.of(context).canvasColor,
      //     //   onPressed: () {
      //     //     showSlidingBottomSheet(context,
      //     //         builder: (context) => SlidingSheetDialog(
      //     //               cornerRadius: 30,
      //     //               backdropColor:
      //     //                   Theme.of(context).canvasColor.withOpacity(0.6),
      //     //               duration: const Duration(seconds: 1),
      //     //               snapSpec: const SnapSpec(snappings: [0.9]),
      //     //               builder: (context, state) {
      //     //                 return const CharacterCreationScreen();
      //     //               },
      //     //             ));
      //     //   },
      //     //   child: const Icon(Icons.person_add),
      //     // ),
      //     FloatingActionButton.small(
      //       // shape: const CircleBorder(),
      //       heroTag: null,
      //       foregroundColor: Colors.black,
      //       backgroundColor: Theme.of(context).canvasColor,
      //       onPressed: () {
      //         // const SnackBar snackBar = SnackBar(
      //         //   content: Text("SnackBar"),
      //         // );
      //         showSlidingBottomSheet(context,
      //             builder: (context) => SlidingSheetDialog(
      //                   cornerRadius: 30,
      //                   backdropColor:
      //                       Theme.of(context).canvasColor.withOpacity(0.6),
      //                   duration: const Duration(seconds: 1),
      //                   snapSpec: const SnapSpec(snappings: [0.9]),
      //                   builder: (context, state) {
      //                     return const PostScreen();
      //                   },
      //                 ));
      //       },
      //       child: const Icon(Icons.add),
      //     ),
      //   ],
      // ),

      floatingActionButton: FloatingActionButton(
        heroTag: null,

        foregroundColor: Colors.black,
        backgroundColor: Theme.of(context).canvasColor,
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
        child: SvgPicture.asset('icons/post.svg'),
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
      ), // Display s

      // ), // Display selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: _onItemTapped,
        elevation: 100,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      // body: AdvancedDrawer(
      //     drawer:  SafeArea(
      //       child:  Container(
      //         child: ListTileTheme(
      //
      //           child: Column(
      //             mainAxisSize: MainAxisSize.max,
      //             children: [
      //
      //               ListTile(
      //                 onTap: () {
      //
      //                 },
      //                 title: Text('Home', style: TextStyle(color: _isDrawerOpen ? Colors.black : Theme.of(context).canvasColor, fontWeight: _currentPage == 0 ? FontWeight.bold : FontWeight.normal),
      //               )),
      //               ListTile(
      //                 onTap: () {
      //                   Navigator.push(
      //                       context,
      //                       MaterialPageRoute(
      //                           builder: (context) => const UserProfileScreen()));
      //                 },
      //
      //                 title: Text('Profile',style: TextStyle(color: _isDrawerOpen ? Colors.black : Theme.of(context).canvasColor, fontWeight: _currentPage == 1 ? FontWeight.bold : FontWeight.normal),),
      //               ),
      //               ListTile(
      //                 onTap: () {
      //                   Navigator.push(
      //                       context,
      //                       MaterialPageRoute(
      //                           builder: (context) => const SavedScreen()));
      //                 },
      //                 title: Text('Favorites',style: TextStyle(color: _isDrawerOpen ? Colors.black : Theme.of(context).canvasColor, fontWeight: _currentPage == 2 ? FontWeight.bold : FontWeight.normal),),
      //               ),
      //               ListTile(
      //                 onTap: () {
      //                   Navigator.push(
      //                       context,
      //                       MaterialPageRoute(
      //                           builder: (context) => const SettingsScreen()));
      //                 },
      //                 title: Text('Settings', style: TextStyle(color: _isDrawerOpen ? Colors.black : Theme.of(context).canvasColor, fontWeight: _currentPage == 3 ? FontWeight.bold : FontWeight.normal),),
      //               ),
      //             ],
      //           ),
      //         ),
      //       ),
      //     ) ,
      //
      //     controller: _advancedDrawerController,
      //     animationCurve: Curves.easeInOut,
      //     animationDuration: const Duration(milliseconds: 300),
      //     animateChildDecoration: true,
      //     rtlOpening: false,
      //     // openScale: 1.0,
      //     disabledGestures: false,
      //     childDecoration: const BoxDecoration(
      //       // NOTICE: Uncomment if you want to add shadow behind the page.
      //       // Keep in mind that it may cause animation jerks.
      //       // boxShadow: <BoxShadow>[
      //       //   BoxShadow(
      //       //     color: Colors.black12,
      //       //     blurRadius: 0.0,
      //       //   ),
      //       // ],
      //       borderRadius: BorderRadius.all(Radius.circular(16)),
      //     ),
      //     child: const HomeScreen())
      //
    );
  }
}
