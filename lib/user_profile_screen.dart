import 'package:flutter/material.dart';
import 'package:inzone/components/inzone_searchbar.dart';
import 'package:inzone/components/post_card.dart';
import 'package:inzone/inzone_database.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/inzone_post.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  int currentPage = 0;
  String name = "Error";
  String? _bio;
  List<String> userNames = [];
  TextEditingController _bioController = TextEditingController();
  FocusNode _focusNode = FocusNode(); // Focus node to manage focus on TextField

  void fetchUserProfile() async {
    Map<String, dynamic>? userProfile =
        await InZoneDatabase.getCurrentUserProfile();
    print("Printing user profile");
    print(userProfile);
    if (userProfile != null) {
      setState(() {
        name = userProfile["name"];
      });
    }
    if (userProfile != null) {
      print('User profile fetched: $userProfile');
    } else {
      print('Failed to fetch user profile.');
    }
  }

  bool _isEditing = false; // Track if the user is editing

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    _loadBio();
  }

  _loadBio() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _bio = prefs.getString('userBio');
      if (_bio != null) {
        _bioController.text = _bio!;
      }
    });
  }

  _saveBio(String bio) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('userBio', bio);
    setState(() {
      _bio = bio;
    });
  }

  backgroundTasks()async {

    //TODO getFollowers()
    String uid = "Error";
    await InZoneDatabase.getCurrentUserUid().then((value){
      if(value != null){
        uid = value;
      }
    });
    print("Getting followers for $uid");
    await InZoneDatabase.getFollowers('4zQrT4Zd1oMFjlaPDEz3wWcJSOv2');
    //TODO getFollowing()
    //TODO Make them into the required format of FollowersFOllowingScreen
  }

  Widget getScreen()  {
    if (currentPage == 0) {
      return const PersonalFeedScreen();
    } else if (currentPage == 1) {
      return const LikedScreen();
    } else {
      backgroundTasks();
      return FollowersFollowingScreen(
        userList: {"followers": [], "following": []},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).canvasColor,
        title: Text("Profile",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(10.0),
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
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        Flexible(
                          child: _bio == null || _bio!.isEmpty || _isEditing
                              ? Expanded(
                                  child: TextField(
                                    controller: _bioController,
                                    focusNode:
                                        _focusNode, // Attach focus node to TextField

                                    decoration: const InputDecoration(
                                      labelText: 'Tap to enter bio',
                                      border: InputBorder.none, // No border
                                    ),
                                    onChanged: (text) {
                                      _saveBio(
                                          text); // Automatically save bio as the user types
                                    },
                                    onSubmitted: (text) {
                                      _saveBio(text); // Save on submission
                                      setState(() {
                                        _isEditing =
                                            false; // Switch to display mode after submission
                                      });
                                    },
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isEditing =
                                          true; // Switch to editing mode when tapped
                                      _focusNode
                                          .requestFocus(); // Focus the TextField
                                    });
                                  },
                                  child: ListTile(
                                    title: Text(_bio!),
                                  ),
                                ),
                        ),
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
                  child: Text("Feed",
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
                  child: Text("Likes",
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

class PersonalFeedScreen extends StatelessWidget {
  const PersonalFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> posts = [];
    List temp_list = [
      InZonePost(
          userName: "Ella.Sanders",
          id: "Bf7TyQpKsd9Xa3WvErZ1",
          textContent:
              "Who knew knitting could be so relaxing? I've just finished my first scarf, and it feels like magic seeing it all come together stitch by stitch.",
          category: "knitting",
          mainCategory: "crafts",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Ella.Sanders/",
          likes: 345),
      InZonePost(
          userName: "Jake.Ramirez",
          id: "S8fPQiTXdyWo5MmNvKoP",
          textContent:
              "Exploring the trails is where I feel alive. Nothing beats the rush of the wind and the beauty of untouched landscapes.",
          category: "hiking",
          mainCategory: "outdoor",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Jake.Ramirez/",
          likes: 612),
      InZonePost(
          userName: "Natalie.Chen",
          id: "Xm94TlRyRa9RvVrUtVpL",
          textContent:
              "There's something so satisfying about completing a puzzle. 1000 pieces later and I've got a stunning landscape to show for it!",
          category: "puzzles",
          mainCategory: "indoor",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Natalie.Chen/",
          likes: 289),
      InZonePost(
          userName: "Sam.Michaels",
          id: "Wq5KeYTz8hWmPdTyXcZ2",
          textContent:
              "Just completed my first marathon! The training was tough, but crossing that finish line made it all worth it.",
          category: "running",
          mainCategory: "fitness",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Sam.Michaels/",
          likes: 750),
      InZonePost(
          userName: "Lily.Turner",
          id: "Vo5ExKr9Rz2WqPpJtYuT",
          textContent:
              "There's nothing like baking cookies from scratch. The smell of fresh chocolate chip cookies just fills the house with warmth and happiness.",
          category: "baking",
          mainCategory: "food",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Lily.Turner/",
          likes: 530),
      InZonePost(
          userName: "Oliver.Brooks",
          id: "Hf3KeLpXb8TfUtVrGpKw",
          textContent:
              "I just repaired my old guitar and it sounds better than ever! Can’t wait to jam with it again.",
          category: "music",
          mainCategory: "instruments",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Oliver.Brooks/",
          likes: 402),
      InZonePost(
          userName: "Sophia.Moore",
          id: "Nt8PeVkTxd7Xa9QqNf9O",
          textContent:
              "Finally mastered the art of sourdough bread! The crust is crispy, the inside is soft, and I can’t wait to share it with my family.",
          category: "baking",
          mainCategory: "food",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Sophia.Moore/",
          likes: 485),
      InZonePost(
          userName: "Max.Bennett",
          id: "Yf7KeVpQd6Wo5YtLkBrV",
          textContent:
              "Just finished a woodworking project – a custom shelf for my living room. It was challenging, but so rewarding to build something with my own hands.",
          category: "woodworking",
          mainCategory: "crafts",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Max.Bennett/",
          likes: 521),
      InZonePost(
          userName: "Grace.Johnson",
          id: "Op9SeWtLbc2ZpWmRhEtK",
          textContent:
              "I've been experimenting with photography and captured some amazing sunset shots. Nature really knows how to put on a show!",
          category: "photography",
          mainCategory: "art",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Grace.Johnson/",
          likes: 698),
      InZonePost(
          userName: "Ethan.Martin",
          id: "Tq8XfUiPa5TrWkYhNpGj",
          textContent:
              "I’ve been learning how to play chess, and I finally won my first match! It's such a strategic and mentally engaging game.",
          category: "chess",
          mainCategory: "games",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Ethan.Martin/",
          likes: 610)
    ];

    for (var element in temp_list) {
      // Add each post to the posts list with a PostCard widget
      posts.add(
        PostCard(
          post: element,
          onTap: (postId) {
            print('You tapped on post with ID: $postId');
          },
        ),
      );
    }

    return Expanded(
      child: SingleChildScrollView(
        child: Column(children: posts),
      ),
    );
  }
}

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> posts = [];
    List temp_list = [
      InZonePost(
          userName: "Sam.Michaels",
          id: "Wq5KeYTz8hWmPdTyXcZ2",
          textContent:
              "Just completed my first marathon! The training was tough, but crossing that finish line made it all worth it.",
          category: "running",
          mainCategory: "fitness",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Sam.Michaels/",
          likes: 750),
      InZonePost(
          userName: "Lily.Turner",
          id: "Vo5ExKr9Rz2WqPpJtYuT",
          textContent:
              "There's nothing like baking cookies from scratch. The smell of fresh chocolate chip cookies just fills the house with warmth and happiness.",
          category: "baking",
          mainCategory: "food",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Lily.Turner/",
          likes: 530),
      InZonePost(
          userName: "Oliver.Brooks",
          id: "Hf3KeLpXb8TfUtVrGpKw",
          textContent:
              "I just repaired my old guitar and it sounds better than ever! Can’t wait to jam with it again.",
          category: "music",
          mainCategory: "instruments",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Oliver.Brooks/",
          likes: 402),
      InZonePost(
          userName: "Sophia.Moore",
          id: "Nt8PeVkTxd7Xa9QqNf9O",
          textContent:
              "Finally mastered the art of sourdough bread! The crust is crispy, the inside is soft, and I can’t wait to share it with my family.",
          category: "baking",
          mainCategory: "food",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Sophia.Moore/",
          likes: 485),
      InZonePost(
          userName: "Max.Bennett",
          id: "Yf7KeVpQd6Wo5YtLkBrV",
          textContent:
              "Just finished a woodworking project – a custom shelf for my living room. It was challenging, but so rewarding to build something with my own hands.",
          category: "woodworking",
          mainCategory: "crafts",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Max.Bennett/",
          likes: 521),
      InZonePost(
          userName: "Grace.Johnson",
          id: "Op9SeWtLbc2ZpWmRhEtK",
          textContent:
              "I've been experimenting with photography and captured some amazing sunset shots. Nature really knows how to put on a show!",
          category: "photography",
          mainCategory: "art",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Grace.Johnson/",
          likes: 698),
      InZonePost(
          userName: "Ethan.Martin",
          id: "Tq8XfUiPa5TrWkYhNpGj",
          textContent:
              "I’ve been learning how to play chess, and I finally won my first match! It's such a strategic and mentally engaging game.",
          category: "chess",
          mainCategory: "games",
          comments: [],
          datePosted: DateTime.now(),
          imageContent: [],
          videoContent: [],
          userReference: "aiUsers/Ethan.Martin/",
          likes: 610)
    ];

    for (var element in temp_list) {
      // Add each post to the posts list with a PostCard widget
      posts.add(
        PostCard(
          post: element,
          onTap: (postId) {
            print('You tapped on post with ID: $postId');
          },
        ),
      );
    }

    return Expanded(
      child: SingleChildScrollView(
        child: Column(children: posts),
      ),
    );
  }
}

class FollowersFollowingScreen extends StatefulWidget {
  Map<String, List<Map<String, dynamic>>> userList;
  FollowersFollowingScreen({super.key, required this.userList});

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  bool followersSelected = true;
  bool messageShown = false;
  initProcess() {
    if (followersSelected) {
      messageShown = widget.userList["followers"]!.isEmpty;
    } else {
      messageShown = widget.userList["following"]!.isEmpty;
    }
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initProcess();

  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Flexible(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              width: MediaQuery.of(context).size.width - 10,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100)),
              child: Row(children: [
                Expanded(
                  child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          followersSelected = true;
                        });
                      },
                      style: ButtonStyle(
                          elevation: WidgetStateProperty.all(0),
                          backgroundColor: followersSelected
                              ? WidgetStateProperty.all(Colors.blue)
                              : WidgetStateProperty.all(Colors.white),
                          foregroundColor:
                              WidgetStateProperty.all(Colors.black),
                          shape:
                              WidgetStateProperty.all<RoundedRectangleBorder>(
                                  RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100.0),
                          ))),
                      child: const Text("Followers")),
                ),
                Expanded(
                  child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          followersSelected = false;
                        });
                      },
                      style: ButtonStyle(
                          elevation: WidgetStateProperty.all(0),
                          backgroundColor: followersSelected
                              ? WidgetStateProperty.all(Colors.white)
                              : WidgetStateProperty.all(Colors.blue),
                          foregroundColor:
                              WidgetStateProperty.all(Colors.black),
                          shape:
                              WidgetStateProperty.all<RoundedRectangleBorder>(
                                  RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100.0),
                          ))),
                      child: const Text("Following")),
                ),
              ]),
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          const Flexible(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: InZoneSearchBar(
                backgroundColor: Color(0xffA8D7E9),
              ),
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Flexible(
              flex: 7,
              child: messageShown ?  Center(child: Text("No ${followersSelected ? "Followers" : "Following"} yet"),):ListView.builder(
                  itemCount: followersSelected
                      ? widget.userList["followers"]!.length
                      : widget.userList["following"]!.length,
                  itemBuilder: (context, index) {
                    if (followersSelected) {
                      return ListTile(
                          leading: RandomAvatar("Renny Dedws",
                              height: 50, width: 30),
                          title: const Text("_.david_"),
                          subtitle: const Text("David Morel"),
                          trailing: FollowButton(
                              otherUserId: widget.userList['followers']!
                                  .elementAt(index)['uid']));
                    } else {
                      return ListTile(
                          leading: RandomAvatar("Renny Dedws",
                              height: 50, width: 30),
                          title: const Text("_.david_"),
                          subtitle: const Text("David Morel"),
                          trailing: FollowButton(
                              otherUserId: widget.userList['following']!
                                  .elementAt(index)['uid']));
                    }
                  })),
          Flexible(
            flex: 1,
            child: Container(
              height: 90,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).canvasColor,
                    spreadRadius: 40,
                    blurRadius: 40,
                    offset: const Offset(0, 6), // changes position of shadow
                  ),
                ],
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "121",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    " Following ",
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Text(
                    "250",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    " Followers",
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class FollowButton extends StatefulWidget {
  String otherUserId;
  FollowButton({super.key, required this.otherUserId});
  @override
  _FollowButtonState createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool isFollowing = true; // Initial state is "Following"
  toggleChange(bool follow) {
    if (follow) {
      InZoneDatabase.followUser(widget.otherUserId);
      setState(() {
        isFollowing = true;
      });
    } else {
      //TODO UNFOLLOW SHOULD HAPPEN HERE
      InZoneDatabase.followUser(widget.otherUserId);
      setState(() {
        isFollowing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all<Color>(
          isFollowing
              ? Colors.blue
              : Colors
                  .transparent, // Filled when following, transparent when not
        ),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100.0),
            side: const BorderSide(
                color: Colors.blue), // Always outlined with blue
          ),
        ),
      ),
      onPressed: () {
        toggleChange(!isFollowing);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Text(
          isFollowing ? "Following" : "Follow", // Change text based on state
          style: TextStyle(
            color: isFollowing
                ? Colors.white
                : Colors.blue, // White text for filled, blue for outlined
          ),
        ),
      ),
    );
  }
}
