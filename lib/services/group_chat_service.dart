import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/notification_event_service.dart';
// import 'package:inzone/services/notification_service.dart';

class GroupChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the document ID that we're using for all group chats
  static const String defaultGroupChatDocId = 'group_chat_20250410191513';

  static Future<String> _resolveUsername(String uid) async {
    try {
      final userProfile = await InZoneDatabase.getUserProfile(uid);
      final fromProfile = userProfile?['username']?.toString().trim() ?? '';
      if (fromProfile.isNotEmpty) return fromProfile;
    } catch (_) {}

    final usersDoc = await _firestore.collection('users').doc(uid).get();
    if (usersDoc.exists) {
      final fromUsers = usersDoc.data()?['username']?.toString().trim() ?? '';
      if (fromUsers.isNotEmpty) return fromUsers;
    }

    final humanUsersDoc = await _firestore.collection('humanUsers').doc(uid).get();
    if (humanUsersDoc.exists) {
      final fromHumanUsers =
          humanUsersDoc.data()?['username']?.toString().trim() ?? '';
      if (fromHumanUsers.isNotEmpty) return fromHumanUsers;
    }

    return '';
  }

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
        final timestamp = Timestamp.fromDate(DateTime.now().toUtc());
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
  static Future<void> sendMessageToGroup(String groupId, String content, {String? imageUrl, String? videoUrl, String? videoThumbnailUrl}) async {
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
      if (displayName.length < 2) {
        try {
          // Try to get user profile from Firebase
          Map<String, dynamic>? userProfile =
              await InZoneDatabase.getUserProfile(currentUser.uid);
          if (userProfile != null) {
            displayName = userProfile["Name"] ?? userProfile["name"] ?? 'User';
            // currentUser.updateDisplayName(displayName);
          }
        } catch (e) {
          print('Error fetching user name from database: $e');
        }
      }

      final username = await _resolveUsername(currentUser.uid);

      final currentParticipant = {
        'uid': currentUser.uid,
        'type': 'user',
        'name': displayName,
        'username': username,
      };

      // Create the message with Timestamp instead of DateTime for Firestore compatibility
      final timestamp = Timestamp.fromDate(DateTime.now().toUtc());
      final message = {
        'id': DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
        'sender': currentParticipant,
        'content': content,
        'isProcessed': false,
        'timestamp': timestamp,
      };
      
      // Add media URLs if provided
      if (imageUrl != null) {
        message['imageUrl'] = imageUrl;
      }
      if (videoUrl != null) {
        message['videoUrl'] = videoUrl;
      }
      if (videoThumbnailUrl != null) {
        message['videoThumbnailUrl'] = videoThumbnailUrl;
      }

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

              // Add timestamp only from legacy date fields when missing.
              // Do not backfill with "now" because it corrupts historical ordering.
              if (!msgMap.containsKey('timestamp') || msgMap['timestamp'] == null) {
                final legacyCreatedAt = msgMap['createdAt'];
                final legacyUpdatedAt = msgMap['updatedAt'];
                if (legacyCreatedAt != null) {
                  msgMap['timestamp'] = legacyCreatedAt;
                  existingMessages[i] = msgMap;
                  updatedExistingMessages = true;
                } else if (legacyUpdatedAt != null) {
                  msgMap['timestamp'] = legacyUpdatedAt;
                  existingMessages[i] = msgMap;
                  updatedExistingMessages = true;
                }
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

        // Trigger notification event for group message
        await NotificationEventService.onGroupMessage(
          groupId,
          content,
          currentUser.uid,
        // Trigger notification for group message
        // await NotificationService.sendGroupMessageNotification(
        //   groupId: groupId,
        //   content: content,
        //   senderId: currentUser.uid,
        );

        // Check for mentions in the message and trigger mention notifications
        // Pass the message id so we can deduplicate mention notifications.
        final String? messageId = message['id'] as String?;
        await _checkForMentions(content, groupId, currentUser.uid, messageId: messageId);
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

    final username = await _resolveUsername(currentUser.uid);

    final currentParticipant = {
      'uid': currentUser.uid,
      'type': 'user',
      'name': displayName,
      'username': username,
    };

    // Create a default Messi AI participant
    final messiParticipant = {
      'uid': 'fpO9prUW8ZKdDC8OzuSq',
      'type': 'ai',
      'name': 'Lionel Messi',
    };


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
      'createdAt': Timestamp.fromDate(DateTime.now().toUtc()),
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
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
      final timestamp = DateTime.now().toUtc();
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

      final username = await _resolveUsername(currentUser.uid);

      final currentParticipant = {
        'uid': currentUser.uid,
        'type': 'user',
        'name': displayName,
        'username': username,
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
        'createdAt': Timestamp.fromDate(DateTime.now().toUtc()),
        'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
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

  /// Check for mentions in message content and trigger notifications
  static Future<void> _checkForMentions(String content, String groupId, String senderId, {String? messageId}) async {
    try {
      // Mention detection - support @username (alphanumeric, underscore, dot, dash)
      // and explicit uid mentions like <@uid> or @<uid>
      final mentionRegex = RegExp(r'<@([A-Za-z0-9_-]+)>|@([A-Za-z0-9_.\-]+)');
      final mentions = mentionRegex.allMatches(content);
      
      if (mentions.isEmpty) return;
      
      // Get group participants to validate mentions
      final groupDoc = await _firestore.collection('groupChats').doc(groupId).get();
      if (!groupDoc.exists) return;
      
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final participants = groupData['participants'] as List<dynamic>? ?? [];
      
      for (final match in mentions) {
        // match.group(1) -> uid-style (<@uid>), group(2) -> @username
        final mentionedUidLike = match.group(1);
        final mentionedUsernameLike = match.group(2);
        String? targetUid;
        String targetNameSnippet = '';

        // Try to resolve mentioned user either by uid-like mention or by username
        if (mentionedUidLike != null && mentionedUidLike.isNotEmpty) {
          // If the mention looks like a UID, try to find participant with that uid
          for (final participant in participants) {
            if (participant is Map<String, dynamic>) {
              final participantUid = participant['uid'] as String? ?? '';
              if (participantUid == mentionedUidLike && participantUid != senderId) {
                targetUid = participantUid;
                targetNameSnippet = participant['name'] as String? ?? participantUid;
                break;
              }
            }
          }
        }

        if (targetUid == null && mentionedUsernameLike != null && mentionedUsernameLike.isNotEmpty) {
          // Match case-insensitive against participant name or username fields
          for (final participant in participants) {
            if (participant is Map<String, dynamic>) {
              final participantName = participant['name'] as String? ?? '';
              final participantUsername = (participant['username'] as String?) ?? participantName;
              final participantUid = participant['uid'] as String? ?? '';

              if ((participantName.toLowerCase() == mentionedUsernameLike.toLowerCase() ||
                      participantUsername.toLowerCase() == mentionedUsernameLike.toLowerCase()) &&
                  participantUid != senderId) {
                targetUid = participantUid;
                targetNameSnippet = participantName.isNotEmpty ? participantName : participantUsername;
                break;
              }
            }
          }
        }

        if (targetUid == null) {
          // Could not resolve mention to a participant in the group, skip
          continue;
        }

        try {
          // Fire server-side mention pipeline (best-effort)
          await NotificationEventService.onGroupMention(
            groupId,
            targetUid,
            content,
            senderId,
          // await NotificationService.sendGroupMentionNotification(
          //   groupId: groupId,
          //   mentionedUserId: targetUid,
          //   content: content,
          //   senderId: senderId,
          );
        } catch (e) {
          // swallow and continue to fallback
          print('Error calling onGroupMention endpoint: $e');
          // print('Error calling sendGroupMentionNotification: $e');
        }

        // Client-side fallback: ensure a notification doc exists so the FE shows
        // the mention even if the server pipeline fails or is delayed.
        try {
          final notifRef = _firestore.collection('notifications');

          // Resolve canonical humanUsers uid if participant might not be a humanUsers doc
          String? resolvedUid = targetUid;
          try {
            final humanUsersRef = _firestore.collection('humanUsers');
            DocumentSnapshot? resolvedDoc;
            final byId = await humanUsersRef.doc(targetUid).get();
            if (byId.exists) {
              resolvedDoc = byId;
            } else {
              final q1 = await humanUsersRef.where('username', isEqualTo: targetUid).limit(1).get();
              if (q1.docs.isNotEmpty) resolvedDoc = q1.docs.first;
            }

            if (resolvedDoc != null && resolvedDoc.exists) {
              final data = resolvedDoc.data() as Map<String, dynamic>;
              resolvedUid = data['uid'] ?? resolvedDoc.id;
            }
          } catch (e) {
            print('Error resolving humanUsers for mention fallback: $e');
          }

          if (resolvedUid == null) continue;

          // Deduplicate by msgId when available
          QuerySnapshot existingQuery;
          if (messageId != null && messageId.isNotEmpty) {
            existingQuery = await notifRef
                .where('userId', isEqualTo: resolvedUid)
                .where('data.msgId', isEqualTo: messageId)
                .limit(1)
                .get();
          } else {
            // fallback dedupe by group+sender+snippet
            existingQuery = await notifRef
                .where('userId', isEqualTo: resolvedUid)
                .where('data.groupId', isEqualTo: groupId)
                .where('data.senderId', isEqualTo: senderId)
                .limit(1)
                .get();
          }

          if (existingQuery.docs.isEmpty) {
            final snippet = (content.length > 100) ? '${content.substring(0, 100)}...' : content;
            final added = await notifRef.add({
              'userId': resolvedUid,
              'type': 'mention',
              'title': 'You were mentioned',
              'body': '$targetNameSnippet mentioned you: $snippet',
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
              'data': {
                'groupId': groupId,
                if (messageId != null) 'msgId': messageId,
                'senderId': senderId,
                'snippet': snippet,
              },
              // 'deeplink': 'inzone://group/$groupId${messageId != null ? '?msg=$messageId' : ''}', // deeplink disabled
            });

            print('Wrote fallback group mention notification ${added.id} for $resolvedUid');
          }
        } catch (e) {
          print('Error writing fallback mention notification: $e');
        }
      }
    } catch (e) {
      print('Error checking for mentions: $e');
    }
  }
}
