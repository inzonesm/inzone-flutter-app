import 'package:cloud_firestore/cloud_firestore.dart';

class GroupChatData {
  final String id;
  final String name;
  final String accessTier;
  final int entryFee;
  final String description;
  final String imageUrl;
  final String groupChatType;
  final String groupChatStatus;
  final String groupChatCategory;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Participant> participants;
  final List<ChatMessage> messages;
  final String lastProcessedMessageId;

  GroupChatData({
    required this.id,
    required this.name,
    required this.accessTier,
    required this.entryFee,
    required this.description,
    required this.imageUrl,
    required this.groupChatType,
    required this.groupChatStatus,
    required this.groupChatCategory,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
    required this.messages,
    required this.lastProcessedMessageId,
  });

  factory GroupChatData.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    
    return GroupChatData(
      id: snapshot.id,
      name: data['name'] ?? '',
      accessTier: data['accessTier'] ?? '',
      entryFee: data['entryFee'] ?? 0,
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      groupChatType: data['groupChatType'] ?? '',
      groupChatStatus: data['groupChatStatus'] ?? '',
      groupChatCategory: data['groupChatCategory'] ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      participants: _parseParticipants(data['participants'] ?? []),
      messages: _parseMessages(data['messages'] ?? []),
      lastProcessedMessageId: data['lastProcessedMessageId'] ?? '',
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else {
      return DateTime.now();
    }
  }

  static List<Participant> _parseParticipants(List<dynamic> participantsData) {
    return participantsData.map((participant) => Participant.fromMap(participant)).toList();
  }

  static List<ChatMessage> _parseMessages(List<dynamic> messagesData) {
    try {
      print('Parsing ${messagesData.length} messages');
      
      List<ChatMessage> messages = [];
      for (var i = 0; i < messagesData.length; i++) {
        try {
          final messageData = messagesData[i];
          // Debug data type
          print('Message $i type: ${messageData.runtimeType}');
          
          // Handle if it's already a Map
          final map = messageData is Map ? 
                      (messageData).cast<String, dynamic>() :
                      messageData as Map<String, dynamic>;
          
          print('Message $i data: $map');
          
          // First check if we have the required fields
          if (!map.containsKey('id') || 
              !map.containsKey('sender') || 
              !map.containsKey('content')) {
            print('Message $i missing required fields, skipping');
            continue;
          }
          
          final message = ChatMessage.fromMap(map);
          messages.add(message);
          print('Successfully parsed message $i');
        } catch (e) {
          print('Error parsing message at index $i: $e');
          // Continue to next message instead of failing the whole list
          continue;
        }
      }
      
      print('Successfully parsed ${messages.length} out of ${messagesData.length} messages');
      return messages;
    } catch (e) {
      print('Error in _parseMessages: $e');
      return [];
    }
  }
}

class Participant {
  final String uid;
  final String type;
  final String name;

  Participant({
    required this.uid,
    required this.type,
    required this.name,
  });

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      uid: map['uid'] ?? '',
      type: map['type'] ?? '',
      name: map['name'] ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String content;
  final bool isProcessed;
  final DateTime? timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.isProcessed,
    this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    try {
      // Ensure sender is a Map before parsing
      Map<String, dynamic> senderMap;
      if (map['sender'] is Map) {
        senderMap = (map['sender'] as Map).cast<String, dynamic>();
      } else {
        print('Sender is not a Map: ${map['sender']}');
        senderMap = {};
      }
    
      return ChatMessage(
        id: map['id']?.toString() ?? '',
        sender: MessageSender.fromMap(senderMap),
        content: map['content']?.toString() ?? '',
        isProcessed: map['isProcessed'] == true,
        timestamp: map['timestamp'] != null 
            ? GroupChatData._parseTimestamp(map['timestamp'])
            : null,
      );
    } catch (e) {
      print('Error parsing ChatMessage: $e');
      print('Message data was: $map');
      
      // Return a placeholder message instead of failing
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender(uid: '', type: 'error', name: 'Error'),
        content: 'Error parsing message: $e',
        isProcessed: true,
        timestamp: DateTime.now(),
      );
    }
  }
}

class MessageSender {
  final String uid;
  final String type;
  final String name;

  MessageSender({
    required this.uid,
    required this.type,
    required this.name,
  });

  factory MessageSender.fromMap(Map<String, dynamic> map) {
    try {
      return MessageSender(
        uid: map['uid'] ?? '',
        type: map['type'] ?? '',
        name: map['name'] ?? '',
      );
    } catch (e) {
      print('Error parsing MessageSender: $e');
      return MessageSender(
        uid: '',
        type: 'unknown',
        name: 'Unknown',
      );
    }
  }
} 