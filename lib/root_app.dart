


import 'package:flutter/cupertino.dart';
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
  const RootApp({Key? key}) : super(key: key);

  @override
  _RootAppState createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> with SingleTickerProviderStateMixin {
  final _advancedDrawerController = AdvancedDrawerController();
  bool _isDrawerOpen = false;
int _currentPage = 0;

  final _key = GlobalKey<ExpandableFabState>();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _advancedDrawerController.addListener(() {
      if (!_advancedDrawerController.value.visible) {
        // Drawer is closed
        Future.delayed(const Duration(milliseconds: 200), () {
          // Set state after 2 seconds
          setState(() {
            _isDrawerOpen = false;
          });
        });
      } else {
        // Drawer is open
        Future.delayed(const Duration(milliseconds: 200), () {
          // Set state after 2 seconds
          setState(() {
            _isDrawerOpen = true;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
     _advancedDrawerController.removeListener(() {});

    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _key,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: AppBar(
              elevation: 0,
              automaticallyImplyLeading: false,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Theme.of(context).canvasColor,
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   Text("InZone",
                      style:
                      Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: 30)),


                  const Spacer(),

                  GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ExploreScreen()));
                      },
                      child: const  Icon(
                        Icons.search,
                        color: Colors.black,
                      )),
                  const SizedBox(
                    width: 10,
                  ),
                  GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AllChatsScreen()));
                      },
                      child: const SizedBox(height: 20, width: 20, child: Icon(
                        Icons.bubble_chart_outlined,
                        color: Colors.black,
                      ))),

                ],
              )),
        ),
        floatingActionButtonLocation: ExpandableFab.location,
        floatingActionButton: ExpandableFab(
          openButtonBuilder: RotateFloatingActionButtonBuilder(
            child: SvgPicture.asset('icons/post.svg'),
            fabSize: ExpandableFabSize.regular,
            foregroundColor: Colors.black,
            backgroundColor: Theme.of(context).canvasColor,
          ),
          overlayStyle: ExpandableFabOverlayStyle(
            color: Colors.black.withOpacity(0.5),
            blur: 5,
          ),
          onOpen: () {

          },
          afterOpen: () {

            final state = _key.currentState;
            if (state != null) {

              state.toggle();
            }
          },
          onClose: () {

          },
          afterClose: () {

          },
          children: [
            FloatingActionButton.small(
              // shape: const CircleBorder(),
              heroTag: null,
              child: const Icon(Icons.person_add),
              foregroundColor: Colors.black,
              backgroundColor: Theme.of(context).canvasColor,
              onPressed: () {
                showSlidingBottomSheet(context,
                    builder: (context) => SlidingSheetDialog(
                      cornerRadius: 30,
                      backdropColor: Theme.of(context).canvasColor.withOpacity(0.6),
                      duration: const Duration(seconds: 1),
                      snapSpec: const SnapSpec(snappings: [0.9]),
                      builder: (context, state) {
                        return CharacterCreationScreen();
                      },
                    ));
              },
            ),
            FloatingActionButton.small(
              // shape: const CircleBorder(),
              heroTag: null,
              child: const Icon(Icons.add),
              foregroundColor: Colors.black,
              backgroundColor: Theme.of(context).canvasColor,
              onPressed: () {
                // const SnackBar snackBar = SnackBar(
                //   content: Text("SnackBar"),
                // );
                showSlidingBottomSheet(context,
                    builder: (context) => SlidingSheetDialog(
                      cornerRadius: 30,
                      backdropColor: Theme.of(context).canvasColor.withOpacity(0.6),
                      duration: const Duration(seconds: 1),
                      snapSpec: const SnapSpec(snappings: [0.9]),
                      builder: (context, state) {
                        return const PostScreen();
                      },
                    ));
              },
            ),

          ],
        ),
        backgroundColor: Theme.of(context).canvasColor,
        body: AdvancedDrawer(
            drawer:  SafeArea(
              child:  Container(
                child: ListTileTheme(

                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [

                      ListTile(
                        onTap: () {

                        },
                        title: Text('Home', style: TextStyle(color: _isDrawerOpen ? Colors.black : Theme.of(context).canvasColor, fontWeight: _currentPage == 0 ? FontWeight.bold : FontWeight.normal),
                      )),
                      ListTile(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const UserProfileScreen()));
                        },

                        title: Text('Profile',style: TextStyle(color: _isDrawerOpen ? Colors.black : Theme.of(context).canvasColor, fontWeight: _currentPage == 1 ? FontWeight.bold : FontWeight.normal),),
                      ),
                      ListTile(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SavedScreen()));
                        },
                        title: Text('Favorites',style: TextStyle(color: _isDrawerOpen ? Colors.black : Theme.of(context).canvasColor, fontWeight: _currentPage == 2 ? FontWeight.bold : FontWeight.normal),),
                      ),
                      ListTile(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SettingsScreen()));
                        },
                        title: Text('Settings', style: TextStyle(color: _isDrawerOpen ? Colors.black : Theme.of(context).canvasColor, fontWeight: _currentPage == 3 ? FontWeight.bold : FontWeight.normal),),
                      ),
                    ],
                  ),
                ),
              ),
            ) ,
         
            controller: _advancedDrawerController,
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 300),
            animateChildDecoration: true,
            rtlOpening: false,
            // openScale: 1.0,
            disabledGestures: false,
            childDecoration: const BoxDecoration(
              // NOTICE: Uncomment if you want to add shadow behind the page.
              // Keep in mind that it may cause animation jerks.
              // boxShadow: <BoxShadow>[
              //   BoxShadow(
              //     color: Colors.black12,
              //     blurRadius: 0.0,
              //   ),
              // ],
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: const HomeScreen()));
  }
}