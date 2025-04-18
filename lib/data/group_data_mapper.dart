import 'package:inzone/data/group_data.dart';
import 'package:inzone/data/group_chat_data.dart';

class GroupDataMapper {
  /// Convert GroupChatData to GroupData for display in the group card
  static GroupData fromGroupChatData(GroupChatData chatData) {
    return GroupData(
      id: chatData.id,
      name: chatData.name,
      description: chatData.description,
      memberCount: chatData.participants.length,
      messageCount: chatData.messages.length,
      avatars: _extractAvatarTokens(chatData.participants),
      isMember: true, // If we're viewing it, we're a member
    );
  }
  
  /// Extract avatar tokens from participants
  static List<String> _extractAvatarTokens(List<Participant> participants) {
    // We'll use up to 4 participant UIDs as avatar tokens
    List<String> avatars = [];
    
    for (var i = 0; i < participants.length && i < 4; i++) {
      avatars.add(participants[i].uid);
    }
    
    return avatars;
  }
  
  /// Creates a dummy GroupData based on the GroupChatData for testing or defaults
  static GroupData createDummyGroupData() {
    return GroupData(
      id: 'group_chat_20250410191513',
      name: "Culers' Corner",
      description: "A special group chat for the biggest Culers. Join us for exclusive content and discussions!",
      memberCount: 2,
      messageCount: 2,
      avatars: [],
      isMember: true,
    );
  }

  /// Creates a dummy GroupData with a specific ID
  static GroupData createDummyGroupWithId(String id) {
    return GroupData(
      id: id,
      name: "Culers' Corner",
      description: "A special group chat for the biggest Culers. Join us for exclusive content and discussions!",
      memberCount: 2,
      messageCount: 2,
      avatars: [],
      isMember: true,
    );
  }
} 