import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/ui/profile_appbar.dart';
import 'package:inzone/components/profile/profile_tabs.dart';
import 'package:inzone/services/inzone_database.dart';

abstract class BaseProfileScreen extends StatefulWidget {
  const BaseProfileScreen({super.key});
}

abstract class BaseProfileScreenState<T extends BaseProfileScreen>
    extends State<T> with SingleTickerProviderStateMixin {
  // Common state variables
  int currentPage = 0;
  String name = "Loading";
  String bio = 'Loading';
  String username = 'Loading';
  String profileImageUrl = "";

  int postCount = 0;
  int followingCount = 0;
  int followersCount = 0;
  late TabController _tabController;
  bool isLoading = true;

  // Abstract methods to be implemented by subclasses
  String getUserId();
  List<String> getTabLabels();
  List<Widget> getTabViews();
  Widget buildActionButtons();
  PreferredSizeWidget? buildAppBar();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: getTabLabels().length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        currentPage = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Common methods for fetching user data
  Future<void> fetchUserProfile() async {
    String userId = getUserId();
    if (userId.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    Map<String, dynamic>? userProfile =
        await InZoneDatabase.getUserProfile(userId);

    if (userProfile != null) {
      print(
          "✅ userProfile fetched: $userProfile"); // ✅ 여기 추가 (Firestore에서 받아온 raw 데이터 프린트)

      setState(() {
        name = userProfile["name"] ?? "Unknown"; // 🔥 문제 원인 확인 가능
        bio = userProfile["bio"] ?? "";
        username = userProfile["username"] ?? "Unknown";
        profileImageUrl = userProfile["profilePicture"] ?? "";
        List<dynamic> followers = userProfile["followers"] ?? [];
        List<dynamic> following = userProfile["following"] ?? [];

        followersCount = followers.length;
        followingCount = following.length;
      });
    } else {
      print("❌ userProfile is null"); // ✅ null이면 이것도 출력
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchUserStats([bool isAi = false]) async {
    String userId = getUserId();
    if (userId.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Fetch post count from user posts
    List? posts = [];
    if (isAi) {
      posts = await InZoneDatabase.getAIUserPosts(userId);
    } else {
      posts = await InZoneDatabase.getUserPosts(userId);
    }
    if (posts != null) {
      setState(() {
        postCount = posts!.length;
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the app's background color from the theme
    final backgroundColor = Theme.of(context).cardColor;

    // Set status bar color
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: backgroundColor,
    ));

    return ColorfulSafeArea(
      topColor: Theme.of(context).canvasColor,
      left: false,
      right: false,
      top: true,
      bottom: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: buildAppBar(),
        body: Column(
          children: [
            // Profile header with curved bottom including tab bar
            Container(
              decoration: BoxDecoration(
                color: backgroundColor,
              ),
              child: Column(
                children: [
                  // Profile info section
                  ProfileAppbar(
                    name: name,
                    bio: bio,
                    profileImageUrl: profileImageUrl,
                    username: username,
                    postCount: postCount,
                    followingCount: followingCount,
                    followersCount: followersCount,
                    actionButtons: buildActionButtons(),
                    isProfilePage: true,
                  ),

                  // Tab bar
                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: ProfileTabs(
                      tabController: _tabController,
                      tabLabels: getTabLabels(),
                    ),
                  ),
                ],
              ),
            ),

            // Add some space between the header and tab content
            const SizedBox(height: 5),

            // Tab content
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: getTabViews(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
