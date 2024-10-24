class InZoneAvatar {
  final String id;
  final String name;
  final String bio;
  final String username;
  final String profilePicture;
  final String personality;
  final String gender;
  final String subCategory;
  final int age;

  InZoneAvatar({
    required this.id,
    required this.name,
    required this.bio,
    required this.username,
    required this.profilePicture,
    required this.personality,
    required this.gender,
    required this.subCategory,
    required this.age,
  });

  // Factory method to create an instance of InZoneAvatar from a JSON object
  factory InZoneAvatar.fromJson(Map<String, dynamic> json) {
    return InZoneAvatar(
      id: json['id'] ?? '',
      name: json['character']['name'] ?? '',
      bio: json['character']['bio'] ?? '',
      username: json['character']['username'] ?? '',
      profilePicture: json['character']['profilePicture'] ?? '',
      personality: json['character']['personality'] ?? '',
      gender: json['character']['gender'] ?? '',
      subCategory: json['character']['sub_category'] ?? '',
      age: json['character']['age'] ?? 0,
    );
  }

  // Method to parse a list of InZoneAvatar objects from JSON
  static List<InZoneAvatar> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => InZoneAvatar.fromJson(json)).toList();
  }
}
