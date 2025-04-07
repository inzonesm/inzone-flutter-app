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
}