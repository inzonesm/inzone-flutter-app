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

class GroupsExploreScreen extends StatefulWidget {
  const GroupsExploreScreen({super.key});

  @override
  State<GroupsExploreScreen> createState() => _GroupsExploreScreenState();
}

class _GroupsExploreScreenState extends State<GroupsExploreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<GroupData> _defaultGroups = [];

  @override
  void initState() {
    super.initState();
    _loadDefaultGroups();
  }

  // Load some default groups as a fallback
  Future<void> _loadDefaultGroups() async {
    _defaultGroups = [
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
  }

  // Convert Firestore documents to GroupData objects
  List<GroupData> _convertFirestoreDataToGroups(List<DocumentSnapshot> documents) {
    List<GroupData> groups = [];
    
    for (var doc in documents) {
      try {
        // Convert to GroupChatData first
        GroupChatData chatData = GroupChatData.fromSnapshot(doc);
        
        // Then convert to GroupData for display
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
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: FutureBuilder<String>(
            future: _getUserName(),
            builder: (context, snapshot) {
              String username = snapshot.data ?? "User";
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('groupChats').snapshots(),
                builder: (context, groupsSnapshot) {
                  int groupCount = 0;
                  
                  if (groupsSnapshot.hasData) {
                    groupCount = groupsSnapshot.data!.docs.length;
                  }
                  
                  return CustomAppBar(
                    isHome: true,
                    title: "Groups",
                    userName: username,
                    subtitle: "$groupCount ${groupCount == 1 ? 'group' : 'groups'}",
                    userPoints: "100",
                    profileImageUrl: null,
                    onSearchTap: () {},
                    onProfileTap: () {},
                    onPointsTap: () {},
                  );
                }
              );
            }
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('groupChats').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            print('Error loading groups: ${snapshot.error}');
            return Center(
              child: Text('Error loading groups: ${snapshot.error}'),
            );
          }
          
          // Convert Firestore documents to GroupData objects
          List<GroupData> groups = [];
          
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            groups = _convertFirestoreDataToGroups(snapshot.data!.docs);
            print('Loaded ${groups.length} groups from Firestore');
          }
          
          // If no groups from Firestore, use default groups
          if (groups.isEmpty) {
            groups = _defaultGroups;
            print('Using ${groups.length} default groups');
            
            // Make sure we have at least the Culers' Corner group
            // Create it if it doesn't exist
            GroupChatService.ensureDefaultGroupExists();
          }
          
          return SafeArea(
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
                      children: groups.isEmpty
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
                              ...groups.map((group) => GroupCard(group: group)),
                              const SizedBox(height: 16),
                            ],
                    ),
                  ),
                );
              },
            ),
          );
        }
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

  // Show dialog to create a new group
  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController imageUrlController = TextEditingController(
      // Default to Barcelona image as an example
      text: "https://upload.wikimedia.org/wikipedia/sco/4/47/FC_Barcelona_%28crest%29.svg"
    );
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
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
                // Check if name is provided
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a group name')),
                  );
                  return;
                }
                
                try {
                  // Create the group
                  final groupId = await GroupChatService.createNewGroup(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    imageUrlController.text.trim(),
                  );
                  
                  print('Created new group with ID: $groupId');
                  
                  // Close the dialog
                  Navigator.of(dialogContext).pop();
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Group "${nameController.text}" created successfully')),
                  );
                } catch (e) {
                  print('Error creating group: $e');
                  
                  // Show error message
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
