import 'package:flutter/material.dart';
import 'package:inzone/user_profile_screen.dart';
import 'package:random_avatar/random_avatar.dart';

import 'inzone_database.dart';

class ProfileScreen extends StatefulWidget {
  String uid;
   ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  int currentPage = 0;
  String name = "Loading";
  String bio =
  'Loading';
  List<String> userNames = [];
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // Focus node to manage focus on TextField


  void fetchUserProfile() async {
    Map<String, dynamic>? userProfile = await InZoneDatabase.getUserProfile(widget.uid);
    print("Printing user profile");
    print(userProfile);
    if (userProfile!=null){
      setState(() {
        name = userProfile["name"];
        bio = userProfile["bio"];
      });
    }
    if (userProfile != null) {
      print('User profile fetched: $userProfile');
    } else {
      print('Failed to fetch user profile.');
    }
  }
  final bool _isEditing = false; // Track if the user is editing

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Widget getScreen() {
    if (currentPage == 0) {
      return  const PersonalFeedScreen();
    } else if (currentPage == 1) {
      return const LikedScreen();
    } else {
      return FollowersFollowingScreen( userList: const {"followers": [], "following": []},);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).canvasColor, title: const Text(
          "Profile",style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)


      ), ),
      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all( 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                SizedBox(
                  height: 80,
                  //width: screenWidth!,
                  child: Row(
                    children: [
                      // CircleAvatar(
                      //   radius: 30,
                      //   child:
                      //       RandomAvatar("Renny Dedws", height: 100, width: 100),
                      // ),

                      Padding(
                        padding: const EdgeInsets.only(left: 10.0, right: 10),
                        child: RandomAvatar(name, height: 60, width: 30),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(child:   Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),),
                            Flexible(
                              child: SingleChildScrollView(
                                child: Text(bio)
                              ),
                            )

                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                //const Divider(),
                const SizedBox(
                  height: 30,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          currentPage = 0;
                        });
                      },
                      child: Text("Posts",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: currentPage == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                    // const Text(" | ",
                    //     style: TextStyle(color: Colors.black54, fontSize: 20)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          currentPage = 1;
                        });
                      },
                      child: Text("Characters",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: currentPage == 1
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                    // const Text(" | ",
                    //     style: TextStyle(color: Colors.black, fontSize: 20)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          currentPage = 2;
                        });
                      },
                      child: Text("Community",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: currentPage == 2
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    )
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                getScreen()
              ],
            ),
          )),
    );
  }
}