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
            avatars: ['Harry', 'Hermione', 'Ron', 'Dumbledore'], // Harry Potter themed avatars
            isMember: false),
        GroupData(
            id: '2',
            name: 'Assemble',
            description:
                'The Avengers. Earth\'s mightiest heroes, assembling chaos into victory.',
            memberCount: 5900,
            messageCount: 1760,
            avatars: ['Tony', 'Steve', 'Thor', 'Natasha'], // Avengers themed avatars
            isMember: false),
        GroupData(
            id: '3',
            name: 'Superstars',
            description:
                'Athletes. Limits shattered, legends, greatness chased.',
            memberCount: 4560,
            messageCount: 460,
            avatars: ['Lebron', 'Messi', 'Serena', 'Ronaldo'], // Sports themed avatars
            isMember: false),
        GroupData(
            id: '4',
            name: 'Anime',
            description: 'Anime. Emotions unleashed, worlds explored.',
            memberCount: 5160,
            messageCount: 960,
            avatars: ['Naruto', 'Goku', 'Luffy', 'Eren'], // Anime themed avatars
            isMember: false),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: FutureBuilder<String>(
            future: _getUserName(),
            builder: (context, snapshot) {
              String username = snapshot.data ?? "User";
              return CustomAppBar(
                isHome: true,
                title: "Groups",
                userName: username,
                subtitle: "${_groups.length} ${_groups.length == 1 ? 'group' : 'groups'}",
                userPoints: "100",
                profileImageUrl: null,
                onSearchTap: () {},
                onProfileTap: () {},
                onPointsTap: () {},
              );
            }
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        minWidth: constraints.maxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: _groups.isEmpty
                            ? [
                                SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: const Center(
                                    child: Text('No groups available'),
                                  ),
                                ),
                              ]
                            : [
                                const SizedBox(height: 12),
                                ..._groups
                                    .map((group) => GroupCard(group: group)),
                                const SizedBox(height: 16),
                              ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  // Helper method to get the current user's name
  Future<String> _getUserName() async {
    try {
      Map<String, dynamic>? userProfile = await InZoneDatabase.getCurrentUserProfile();
      if (userProfile != null) {
        return userProfile["Name"] ?? userProfile["name"] ?? "User";
      }
    } catch (e) {
      print('Error getting user name: $e');
    }
    return "User";
  }
}
