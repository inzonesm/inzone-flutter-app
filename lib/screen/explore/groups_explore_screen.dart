import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/components/cards/group_card.dart';

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
            avatars: [], // Empty list since we're using placeholder icons
            isMember: false),
        GroupData(
            id: '2',
            name: 'Assemble',
            description:
                'The Avengers. Earth\'s mightiest heroes, assembling chaos into victory.',
            memberCount: 5900,
            messageCount: 1760,
            avatars: [], // Empty list since we're using placeholder icons
            isMember: false),
        GroupData(
            id: '3',
            name: 'Superstars',
            description:
                'Athletes. Limits shattered, legends, greatness chased.',
            memberCount: 4560,
            messageCount: 460,
            avatars: [], // Empty list since we're using placeholder icons
            isMember: false),
        GroupData(
            id: '4',
            name: 'Anime',
            description: 'Anime. Emotions unleashed, worlds explored.',
            memberCount: 5160,
            messageCount: 960,
            avatars: [], // Empty list since we're using placeholder icons
            isMember: false),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0), // Minimize the app bar height
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          automaticallyImplyLeading: false,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        style: BorderStyle.solid,
                        width: 10.0,
                      ),
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(30),
                        topLeft: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
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
                    ),
                  );
                },
              ),
            ),
    );
  }
}
