import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';

class GroupDiscoveryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Discover Groups')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groupChats')
            .where('archived', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final groups = snapshot.data!.docs;
          // Categorize groups
          Map<String, List<DocumentSnapshot>> categorized = {};
          for (var doc in groups) {
            String category = doc['groupChatCategory'] ?? 'Other';
            categorized.putIfAbsent(category, () => []).add(doc);
          }
          return ListView(
            children: categorized.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: Text(entry.key,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  ...entry.value.map((doc) => Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (doc['avatars'] != null &&
                                    doc['avatars'] is List &&
                                    doc['avatars'].isNotEmpty)
                                ? Image.network(
                                    doc['avatars'][0],
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(Icons.group, size: 48),
                          ),
                          title: Text(doc['name']),
                          subtitle: Text(doc['description']),
                          onTap: () {
                            // Convert Firestore doc to GroupData and navigate to GroupChatScreen
                            final group = GroupData(
                              id: doc.id,
                              name: doc['name'] ?? '',
                              description: doc['description'] ?? '',
                              memberCount: doc['memberCount'] ?? 0,
                              messageCount: doc['messageCount'] ?? 0,
                              avatars: (doc['avatars'] is List)
                                  ? List<String>.from(doc['avatars'])
                                  : [],
                              imageUrl: doc['imageUrl'] ?? '',
                              category: doc['groupChatCategory'] ?? '',
                              isMember: doc['isMember'] ?? false,
                              showRandomCharacters:
                                  doc['showRandomCharacters'] ?? true,
                              showFirst: doc['showFirst'] ?? false,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    GroupChatScreen(group: group),
                              ),
                            );
                          },
                        ),
                      )),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
