import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/services/inzone_database.dart';

class GroupChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the document ID that we're using for all group chats
  static const String defaultGroupChatDocId = 'group_chat_20250410191513';

  // Get group chat data by specific ID
  static Stream<DocumentSnapshot> getGroupChatStreamById(String groupId) {
    return _firestore.collection('groupChats').doc(groupId).snapshots();
  }

  // Get group chat data for the default group
  static Stream<DocumentSnapshot> getGroupChatStream() {
    // First check if the document exists and create it if not
    _checkAndCreateDefaultDocument();

    // Return the stream
    return getGroupChatStreamById(defaultGroupChatDocId);
  }

  // Check if the default document exists and create it if not
  static Future<void> _checkAndCreateDefaultDocument() async {
    try {
      DocumentReference docRef =
          _firestore.collection('groupChats').doc(defaultGroupChatDocId);
      DocumentSnapshot docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        print('Creating default group chat document');

        // Create a new document if it doesn't exist
        final timestamp = Timestamp.now();
        // Barcelona crest image URL
        const imageUrl =
            "https://upload.wikimedia.org/wikipedia/sco/4/47/FC_Barcelona_%28crest%29.svg";

        final newGroupChat = {
          'name': "Culers' Corner",
          'accessTier': "VIP Monthly Access",
          'entryFee': 10,
          'description':
              "A special group chat for the biggest Culers. Join us for exclusive content and discussions!",
          'imageUrl': imageUrl,
          'groupChatType': "premium",
          'groupChatStatus': "active",
          'groupChatCategory': "sports",
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'participants': [],
          'messages': [],
          'lastProcessedMessageId': '',
        };

        await docRef.set(newGroupChat);
        print('Created default group chat document with image: $imageUrl');
      } else {
        print('Default group chat document already exists');
      }
    } catch (e) {
      print('Error checking/creating default document: $e');
    }
  }

  // Send a message to a specific group chat
  static Future<void> sendMessageToGroup(String groupId, String content) async {
    try {
      print('Sending message to group $groupId: $content');

      // Get current user info
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No current user found');
        return;
      }

      // Create participant object
      String displayName = currentUser.displayName ?? 't';
      if ( displayName.length < 2) {
        try {
          // Try to get user profile from Firebase
          Map<String, dynamic>? userProfile =
              await InZoneDatabase.getUserProfile(currentUser.uid);
          if (userProfile != null) {
            displayName = userProfile["Name"] ?? userProfile["name"] ?? 'User';
            currentUser.updateDisplayName(displayName);
          }
        } catch (e) {
          print('Error fetching user name from database: $e');
        }
      }

      final currentParticipant = {
        'uid': currentUser.uid,
        'type': 'user',
        'name': displayName,
      };

      // Create the message with Timestamp instead of DateTime for Firestore compatibility
      final timestamp = Timestamp.now();
      final message = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'sender': currentParticipant,
        'content': content,
        'isProcessed': false,
        'timestamp': timestamp,
      };

      print('Created message object for group $groupId: $message');

      DocumentReference docRef =
          _firestore.collection('groupChats').doc(groupId);
      DocumentSnapshot docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>?;

        if (data == null) {
          print('Document exists but data is null');
          if (groupId == defaultGroupChatDocId) {
            await _createNewGroupChat(docRef, message, timestamp, currentUser);
          } else {
            print('Cannot update non-default group with null data');
          }
          return;
        }

        print('Document exists, updating with new message');

        // Check if messages array exists
        List<dynamic> existingMessages = [];
        if (data.containsKey('messages') && data['messages'] is List) {
          existingMessages = List<dynamic>.from(data['messages']);
          print('Found ${existingMessages.length} existing messages');

          // Check if existing messages have timestamps and add them if missing
          bool updatedExistingMessages = false;
          for (int i = 0; i < existingMessages.length; i++) {
            if (existingMessages[i] is Map<String, dynamic> ||
                existingMessages[i] is Map) {
              Map<String, dynamic> msgMap;
              if (existingMessages[i] is Map<String, dynamic>) {
                msgMap = existingMessages[i] as Map<String, dynamic>;
              } else {
                msgMap = (existingMessages[i] as Map).cast<String, dynamic>();
              }

              // Add timestamp if it doesn't exist
              if (!msgMap.containsKey('timestamp')) {
                print('Adding missing timestamp to message $i');
                msgMap['timestamp'] = timestamp;
                existingMessages[i] = msgMap;
                updatedExistingMessages = true;
              }
            }
          }

          if (updatedExistingMessages) {
            print('Updated existing messages with timestamps');
          }
        } else {
          print('No messages array found, will create one');
        }

        // Add new message to the array
        existingMessages.add(message);

        // Check if participants array exists and add current user if not already there
        List<dynamic> participants = [];
        if (data.containsKey('participants') && data['participants'] is List) {
          participants = List<dynamic>.from(data['participants']);

          // Check if current user is already in participants
          bool currentUserExists = false;
          for (var participant in participants) {
            if (participant is Map &&
                participant.containsKey('uid') &&
                participant['uid'] == currentUser.uid) {
              currentUserExists = true;
              break;
            }
          }

          // Add current user if not already in participants
          if (!currentUserExists) {
            print('Adding current user to participants');
            participants.add(currentParticipant);
          }
        } else {
          // Create participants array with current user
          participants = [currentParticipant];
        }

        // Update the document
        await docRef.update({
          'messages': existingMessages,
          'participants': participants,
          'lastProcessedMessageId': message['id'],
          'updatedAt': timestamp,
        });

        print('Message sent successfully to group $groupId');
      } else {
        print('Document does not exist');
        if (groupId == defaultGroupChatDocId) {
          print('Creating default group chat');
          await _createNewGroupChat(docRef, message, timestamp, currentUser);
        } else {
          print('Cannot send message to non-existent group: $groupId');
        }
      }
    } catch (e) {
      print('Error sending message to group $groupId: $e');
    }
  }

  // Send a message to the default group chat (for backward compatibility)
  static Future<void> sendMessage(String content) async {
    return sendMessageToGroup(defaultGroupChatDocId, content);
  }

  // Create a new group chat document
  static Future<void> _createNewGroupChat(
      DocumentReference docRef,
      Map<String, dynamic> message,
      Timestamp timestamp,
      User currentUser) async {
    // Create participant object
    String displayName = currentUser.displayName ?? 'temp';
    if (currentUser.displayName == null) {
      print('Assigning user name temp');
    }

    final currentParticipant = {
      'uid': currentUser.uid,
      'type': 'user',
      'name': displayName,
    };

    // Create a default Messi AI participant
    final messiParticipant = {
      'uid': 'fpO9prUW8ZKdDC8OzuSq',
      'type': 'ai',
      'name': 'Lionel Messi',
    };

    // Get document ID as the group ID
    final groupId = docRef.id;

    // Barcelona crest image URL
    const imageUrl =
        "https://upload.wikimedia.org/wikipedia/sco/4/47/FC_Barcelona_%28crest%29.svg";

    final newGroupChat = {
      'name': "Culers' Corner",
      'accessTier': "VIP Monthly Access",
      'entryFee': 10,
      'description':
          "A special group chat for the biggest Culers. Join us for exclusive content and discussions!",
      'imageUrl': imageUrl,
      'groupChatType': "premium",
      'groupChatStatus': "active",
      'groupChatCategory': "sports",
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'participants': [currentParticipant, messiParticipant],
      'messages': [message],
      'lastProcessedMessageId': message['id'],
    };

    await docRef.set(newGroupChat);
    print('Created new group chat with initial message and image: $imageUrl');
  }

  // Public method to ensure the default group exists
  static Future<void> ensureDefaultGroupExists() async {
    await _checkAndCreateDefaultDocument();
  }

  // Create a new group with a specific ID - returns the document ID
  static Future<String> createNewGroup(
      String name, String description, String imageUrl) async {
    try {
      // Generate a unique ID with timestamp
      final timestamp = DateTime.now();
      final String docId = 'group_chat_${timestamp.millisecondsSinceEpoch}';

      // Create the group document reference
      DocumentReference docRef = _firestore.collection('groupChats').doc(docId);

      // Get current user info
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No current user found, using default document ID');
        return defaultGroupChatDocId;
      }

      // Create participant object for current user
      String displayName = currentUser.displayName ?? 'temp';
      if (currentUser.displayName == null) {
        print('Assigning user name temp');
      }

      final currentParticipant = {
        'uid': currentUser.uid,
        'type': 'user',
        'name': displayName,
      };

      // Create the group data
      final groupData = {
        'name': name,
        'accessTier': 'Free',
        'entryFee': 0,
        'description': description,
        'imageUrl': imageUrl,
        'groupChatType': 'standard',
        'groupChatStatus': 'active',
        'groupChatCategory': 'general',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'participants': [currentParticipant],
        'messages': [],
        'lastProcessedMessageId': '',
      };

      // Create the document
      await docRef.set(groupData);
      print('Created new group: $name with ID: $docId');

      return docId;
    } catch (e) {
      print('Error creating group: $e');
      return defaultGroupChatDocId;
    }
  }
}
