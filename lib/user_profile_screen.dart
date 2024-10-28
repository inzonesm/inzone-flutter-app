import 'package:flutter/material.dart';
import 'package:inzone/components/avatar_card.dart';
import 'package:inzone/components/inzone_searchbar.dart';
import 'package:inzone/components/post_card.dart';
import 'package:inzone/data/inzone_avatar.dart';
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
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // Focus node to manage focus on TextField

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
    await InZoneDatabase.getFollowers(uid);
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
        userList: const {"followers": [], "following": []},
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
        title: const Text("Profile",
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
                            style: const TextStyle(
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
                                          text);
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

class PersonalFeedScreen extends StatefulWidget {
   const PersonalFeedScreen({super.key});

  @override
  State<PersonalFeedScreen> createState() => _PersonalFeedScreenState();
}

class _PersonalFeedScreenState extends State<PersonalFeedScreen> {
  List<PostCard> posts = [];

  List<AvatarCard> avatarCards = [];

  Future<void> getFeed({bool isRefresh = false}) async {

    final response = await InZoneDatabase.getFeed();
    // Ensure the response contains the expected structure
    if (response != null &&
        response.containsKey('posts') &&
        response.containsKey('characters')) {
      // Parse the posts and avatars
      List<dynamic> fetchedPosts = response['posts'];
      List<dynamic> fetchedCharacters = response['characters'];

      for (var characterJson in fetchedCharacters) {
        InZoneAvatar avatar = InZoneAvatar.fromJson(characterJson);
        avatarCards.add(AvatarCard(avatar: avatar));
      }

      _addPostsToScreen(fetchedPosts);



    } else {
      throw Exception('Invalid response structure');
    }
  }

  void _addPostsToScreen(List<dynamic> fetchedPosts) async {
    for (var postJson in fetchedPosts) {
      InZonePost post = InZonePost.fromJson(postJson);
      posts.add(PostCard(
        post: post,
        onTap: (postId) {
          print('You tapped on post with ID: $postId');
        },
      ));


      // Add unique categories to the list

    }
    setState(() {
      posts.shuffle();

    });
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  getFeed();
  }


  @override
  Widget build(BuildContext context) {


    return Expanded(
      child: SingleChildScrollView(
        child: Column(children: posts),
      ),
    );
  }
}

class LikedScreen extends StatefulWidget {
  const LikedScreen({super.key});

  @override
  State<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends State<LikedScreen> {
  List<PostCard> posts = [];

  List<AvatarCard> avatarCards = [];

  Future<void> getFeed({bool isRefresh = false}) async {

    final response = await InZoneDatabase.getFeed();
    // Ensure the response contains the expected structure
    if (response != null &&
        response.containsKey('posts') &&
        response.containsKey('characters')) {
      // Parse the posts and avatars
      List<dynamic> fetchedPosts = response['posts'];
      List<dynamic> fetchedCharacters = response['characters'];

      for (var characterJson in fetchedCharacters) {
        InZoneAvatar avatar = InZoneAvatar.fromJson(characterJson);
        avatarCards.add(AvatarCard(avatar: avatar));
      }

      _addPostsToScreen(fetchedPosts);



    } else {
      throw Exception('Invalid response structure');
    }
  }

  void _addPostsToScreen(List<dynamic> fetchedPosts) async {
    for (var postJson in fetchedPosts) {
      InZonePost post = InZonePost.fromJson(postJson);
      posts.add(PostCard(
        post: post,
        onTap: (postId) {
          print('You tapped on post with ID: $postId');
        },
      ));


      // Add unique categories to the list

    }
    setState(() {
      posts.shuffle();

    });
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getFeed();
  }


  @override
  Widget build(BuildContext context) {


    return Expanded(
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10, // Horizontal space between items
          runSpacing: 10, // Vertical space between rows
          children: avatarCards, // Use your avatar cards list here
        ),
      ),
    )
;
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
              child:  Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${widget.userList["following"]!.length}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    " Following ",
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(
                    "${widget.userList["followers"]!.length}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
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
