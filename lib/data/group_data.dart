class GroupData {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final int messageCount;
  final List<String> avatars;
  bool isMember;

  GroupData({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.messageCount,
    required this.avatars,
    required this.isMember,
  });

  GroupData copyWith({bool? isMember}) {
    return GroupData(
      id: id,
      name: name,
      description: description,
      memberCount: memberCount,
      messageCount: messageCount,
      avatars: avatars,
      isMember: isMember ?? this.isMember,
    );
  }

  // Add JSON serialization methods
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'memberCount': memberCount,
      'messageCount': messageCount,
      'avatars': avatars,
      'isMember': isMember,
    };
  }

  factory GroupData.fromJson(Map<String, dynamic> json) {
    return GroupData(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      memberCount: json['memberCount'] as int,
      messageCount: json['messageCount'] as int,
      avatars: List<String>.from(json['avatars'] as List),
      isMember: json['isMember'] as bool,
    );
  }
}
