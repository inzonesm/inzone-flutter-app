class GroupData {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final int messageCount;
  final List<String> avatars;
  bool isMember;
  final bool showRandomCharacters;
  final bool showFirst;

  GroupData({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.messageCount,
    required this.avatars,
    required this.isMember,
    this.showRandomCharacters = true,
    this.showFirst = false,
  });

  GroupData copyWith({bool? isMember, bool? showRandomCharacters, bool? showFirst}) {
    return GroupData(
      id: id,
      name: name,
      description: description,
      memberCount: memberCount,
      messageCount: messageCount,
      avatars: avatars,
      isMember: isMember ?? this.isMember,
      showRandomCharacters: showRandomCharacters ?? this.showRandomCharacters,
      showFirst: showFirst ?? this.showFirst,
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
      'showRandomCharacters': showRandomCharacters,
      'showFirst': showFirst,
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
      showRandomCharacters: json['showRandomCharacters'] as bool? ?? true,
      showFirst: json['showFirst'] as bool? ?? false,
    );
  }
}
