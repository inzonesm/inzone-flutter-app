import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/components/cards/group_card.dart';
import 'package:inzone/services/inzone_database.dart';

class GroupsExploreScreen extends StatefulWidget {
  const GroupsExploreScreen({super.key});

  @override
  State<GroupsExploreScreen> createState() => _GroupsExploreScreenState();
}

class _GroupsExploreScreenState extends State<GroupsExploreScreen> {
  bool _isLoading = true;
  List<GroupData> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    // In a real app, this would load from your database
    // For now, we'll use sample data based on the image
    await Future.delayed(
        const Duration(milliseconds: 500)); // Simulate network delay

    setState(() {
      _groups = [
        GroupData(
            id: '1',
            name: 'Hogwarts',
            description:
                'Hogwarts. Enchanted halls, secret passages, and a slight risk of death—but totally worth it.',
            memberCount: 3490,
            messageCount: 760,
            avatars: [
              'Harry',
              'Hermione',
              'Ron',
              'Dumbledore'
            ], // Harry Potter themed avatars
            isMember: false),
        GroupData(
            id: '2',
            name: 'Assemble',
            description:
                'The Avengers. Earth\'s mightiest heroes, assembling chaos into victory.',
            memberCount: 5900,
            messageCount: 1760,
            avatars: [
              'Tony',
              'Steve',
              'Thor',
              'Natasha'
            ], // Avengers themed avatars
            isMember: false),
        GroupData(
            id: '3',
            name: 'Superstars',
            description:
                'Athletes. Limits shattered, legends, greatness chased.',
            memberCount: 4560,
            messageCount: 460,
            avatars: [
              'Lebron',
              'Messi',
              'Serena',
              'Ronaldo'
            ], // Sports themed avatars
            isMember: false),
        GroupData(
            id: '4',
            name: 'Anime',
            description: 'Anime. Emotions unleashed, worlds explored.',
            memberCount: 5160,
            messageCount: 960,
            avatars: [
              'Naruto',
              'Goku',
              'Luffy',
              'Eren'
            ], // Anime themed avatars
            isMember: false),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      topColor: Theme.of(context).canvasColor,
      left: false,
      right: false,
      top: true,
      bottom: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // 스크롤 시 숨겨지는 AppBar
                  SliverAppBar(
                    pinned: false,
                    floating: true,
                    snap: true,
                    toolbarHeight: 70,
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: CustomAppBar(
                      isHome: true,
                      isGroup: true,
                      userPoints: "100",
                      profileImageUrl: null,
                      onSearchTap: () {},
                      onProfileTap: () {},
                      onPointsTap: () {},
                    ),
                  ),

                  // 고정된 검색 바
                  SliverPersistentHeader(
                    pinned: true, // 항상 고정
                    delegate: _SliverSearchBarDelegate(
                      child: Container(
                        color: Theme.of(context).canvasColor,
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search groups...',
                            prefixIcon: Icon(Icons.search,
                                color: Theme.of(context).iconTheme.color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                      minHeight: 80.0,
                      maxHeight: 80.0,
                    ),
                  ),

                  // 그룹 목록
                  _groups.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(child: Text('No groups available')),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.0,
                              mainAxisSpacing: 0.0,
                              crossAxisSpacing: 0.0,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return GroupCard(group: _groups[index]);
                              },
                              childCount: _groups.length,
                            ),
                          ),
                        ),

                  // 바닥 여백
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
      ),
    );
  }

  // Helper method to get the current user's name
  Future<String> _getUserName() async {
    try {
      Map<String, dynamic>? userProfile =
          await InZoneDatabase.getCurrentUserProfile();
      if (userProfile != null) {
        return userProfile["Name"] ?? userProfile["name"] ?? "User";
      }
    } catch (e) {
      print('Error getting user name: $e');
    }
    return "User";
  }
}

// 고정된 검색바를 위한 SliverPersistentHeaderDelegate
class _SliverSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _SliverSearchBarDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  bool shouldRebuild(_SliverSearchBarDelegate oldDelegate) {
    return child != oldDelegate.child ||
        minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight;
  }
}
