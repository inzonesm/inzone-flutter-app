import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/data/group_chat_data.dart';
import 'package:inzone/data/group_data_mapper.dart';
import 'package:inzone/components/cards/group_card.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/group_chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/components/posts/shimmering.dart';

class GroupsExploreScreen extends StatefulWidget {
  const GroupsExploreScreen({super.key});

  @override
  State<GroupsExploreScreen> createState() => _GroupsExploreScreenState();
}

class _GroupsExploreScreenState extends State<GroupsExploreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<GroupData> _defaultGroups = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDefaultGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultGroups() async {
    _defaultGroups = [
      GroupData(
        id: '1',
        name: 'Hogwarts',
        description:
            'Hogwarts. Enchanted halls, secret passages, and a slight risk of death—but totally worth it.',
        memberCount: 3490,
        messageCount: 760,
        avatars: ['Harry', 'Hermione', 'Ron', 'Dumbledore'],
        isMember: false,
      ),
      GroupData(
        id: '2',
        name: 'Assemble',
        description:
            'The Avengers. Earth\'s mightiest heroes, assembling chaos into victory.',
        memberCount: 5900,
        messageCount: 1760,
        avatars: ['Tony', 'Steve', 'Thor', 'Natasha'],
        isMember: false,
      ),
      GroupData(
        id: '3',
        name: 'Superstars',
        description: 'Athletes. Limits shattered, legends, greatness chased.',
        memberCount: 4560,
        messageCount: 460,
        avatars: ['Lebron', 'Messi', 'Serena', 'Ronaldo'],
        isMember: false,
      ),
      GroupData(
        id: '4',
        name: 'Anime',
        description: 'Anime. Emotions unleashed, worlds explored.',
        memberCount: 5160,
        messageCount: 960,
        avatars: ['Naruto', 'Goku', 'Luffy', 'Eren'],
        isMember: false,
      ),
    ];
  }

  List<GroupData> _convertFirestoreDataToGroups(
      List<DocumentSnapshot> documents) {
    List<GroupData> groups = [];
    for (var doc in documents) {
      try {
        GroupChatData chatData = GroupChatData.fromSnapshot(doc);
        groups.add(GroupDataMapper.fromGroupChatData(chatData));
        print('Converted group: ${chatData.name}');
      } catch (e) {
        print('Error converting group data: $e');
      }
    }
    return groups;
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
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('groupChats').snapshots(),
          builder: (context, snapshot) {
            // Common top UI elements (appbar and search)
            List<Widget> commonSlivers = [
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
                  onSearchTap: () {
                    _showCreateGroupDialog(context);
                  },
                  onProfileTap: () {},
                  onPointsTap: () {},
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverSearchBarDelegate(
                  child: Container(
                    color: Theme.of(context).canvasColor,
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          FocusScope.of(context).unfocus();
                        },
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase().trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search groups...',
                          prefixIcon: Icon(Icons.search,
                              color: Theme.of(context).iconTheme.color),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.clear,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                      FocusScope.of(context).unfocus();
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: false,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),
                  ),
                  minHeight: 80.0,
                  maxHeight: 80.0,
                ),
              ),
            ];

            if (snapshot.connectionState == ConnectionState.waiting) {
              return CustomScrollView(
                slivers: [
                  ...commonSlivers,
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        mainAxisSpacing: 0.0,
                        crossAxisSpacing: 0.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return GroupCardLoading(context);
                        },
                        childCount: 8, // Show 8 loading cards
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 130)),
                ],
              );
            }

            if (snapshot.hasError) {
              print('Error loading groups: ${snapshot.error}');
              return CustomScrollView(
                slivers: [
                  ...commonSlivers,
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading groups',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Using default groups instead',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            List<GroupData> groups = [];

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              groups = _convertFirestoreDataToGroups(snapshot.data!.docs);
            }

            if (groups.isEmpty) {
              groups = _defaultGroups;
              GroupChatService.ensureDefaultGroupExists();
            }

            // 검색 필터
            if (_searchQuery.isNotEmpty) {
              groups = groups
                  .where((group) =>
                      group.name.toLowerCase().contains(_searchQuery))
                  .toList();
            }

            return CustomScrollView(
              slivers: [
                ...commonSlivers,
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: groups.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(child: Text('No groups available')),
                        )
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            mainAxisSpacing: 0.0,
                            crossAxisSpacing: 0.0,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return GroupCard(group: groups[index]);
                            },
                            childCount: groups.length,
                          ),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 130)),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController imageUrlController = TextEditingController(
      text:
          "https://upload.wikimedia.org/wikipedia/sco/4/47/FC_Barcelona_%28crest%29.svg",
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Enter a name for your group',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter a description for your group',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'Enter an image URL for your group',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a group name')),
                  );
                  return;
                }

                try {
                  final groupId = await GroupChatService.createNewGroup(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    imageUrlController.text.trim(),
                  );

                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Group "${nameController.text}" created successfully')),
                  );
                } catch (e) {
                  print('Error creating group: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating group: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

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
    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
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
