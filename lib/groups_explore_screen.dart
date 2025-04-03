import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    
    setState(() {
      _groups = [
        GroupData(
          id: '1',
          name: 'Hogwarts',
          description: 'Hogwarts. Enchanted halls, secret passages, and a slight risk of death—but totally worth it.',
          memberCount: 3490,
          messageCount: 760,
          avatars: [], // Empty list since we're using placeholder icons
          isMember: false
        ),
        GroupData(
          id: '2',
          name: 'Assemble',
          description: 'The Avengers. Earth\'s mightiest heroes, assembling chaos into victory.',
          memberCount: 5900,
          messageCount: 1760,
          avatars: [], // Empty list since we're using placeholder icons
          isMember: false
        ),
        GroupData(
          id: '3',
          name: 'Superstars',
          description: 'Athletes. Limits shattered, legends, greatness chased.',
          memberCount: 4560,
          messageCount: 460,
          avatars: [], // Empty list since we're using placeholder icons
          isMember: false
        ),
        GroupData(
          id: '4',
          name: 'Anime',
          description: 'Anime. Emotions unleashed, worlds explored.',
          memberCount: 5160,
          messageCount: 960,
          avatars: [], // Empty list since we're using placeholder icons
          isMember: false
        ),
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
                                  ..._groups.map((group) => GroupCard(group: group)),
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

class GroupData {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final int messageCount;
  final List<String> avatars;
  final bool isMember;

  GroupData({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.messageCount,
    required this.avatars,
    required this.isMember,
  });
}

class GroupCard extends StatelessWidget {
  final GroupData group;

  const GroupCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: group.isMember ? const Color(0xFFEAF7FB) : Theme.of(context).canvasColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'icons/nav_bar_icons/groups_selected.png',
                        width: 18,
                        height: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(group.memberCount/1000).toStringAsFixed(1)}k',
                        style: const TextStyle(
                          color: Colors.black,
                         
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        'icons/incoin.png',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group.messageCount}',
                        style: const TextStyle(
                          color: Colors.black,
                          
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                group.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // group.description.contains('—but totally worth it')
              //     ? const Row(
              //         mainAxisSize: MainAxisSize.min,
              //         children: [
              //           Text(
              //             'More',
              //             style: TextStyle(
              //               fontSize: 14,
              //               color: Color(0xFF333333),
              //               decoration: TextDecoration.underline,
              //             ),
              //           ),
              //         ],
              //       )
              //     : const SizedBox(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Avatar stack
                  SizedBox(
                    height: 40,
                    width: 120,
                    child: Stack(
                      children: List.generate(
                        4,
                        (index) => Positioned(
                          left: index * 28.0,
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.primaries[index % Colors.primaries.length],
                              child: Icon(
                                [Icons.person, Icons.face, Icons.face_retouching_natural, Icons.person_outline][index % 4],
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Join/Open button
                  ElevatedButton(
                    onPressed: () {
                      // Handle join/open action
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF14CFEE),
                            Color(0xFF2196F3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text(
                          group.isMember ? 'Open' : 'Join',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 