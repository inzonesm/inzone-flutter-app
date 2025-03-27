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
  final String? greeting;

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
    this.greeting,
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
      greeting: null,
    );
  }
  factory InZoneAvatar.fromRepostJson(Map<String, dynamic> json) {
    return InZoneAvatar(
      id: json['ai_id'] ?? '2',
      name: json['ai_name'] ?? '2',
      bio: "bio",
      username: json['ai_name'] ?? '2',
      profilePicture: json['ai_profile_image_url'] ?? '2',
      personality: "personality",
      gender: "male",
      subCategory: "category",
      age: 0,
      greeting: null,
    );
  }

  // New factory for direct format from getCarouselCharacters()
  factory InZoneAvatar.fromDirectJson(Map<String, dynamic> json) {
    return InZoneAvatar(
      id: json['name'] ?? '',
      name: json['name'] ?? '',
      bio: json['personality'] ?? '',
      username: json['name'] ?? '',
      profilePicture: json['profile_picture_url'] ?? '',
      personality: json['personality'] ?? '',
      gender: 'not specified',
      subCategory: 'not specified',
      age: 0,
      greeting: json['greeting'],
    );
  }

  // Method to parse a list of InZoneAvatar objects from JSON
  static List<InZoneAvatar> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => InZoneAvatar.fromJson(json)).toList();
  }
}
