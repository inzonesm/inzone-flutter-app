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

  // Factory method for the new AI characters endpoint
  factory InZoneAvatar.fromAICharacter(Map<String, dynamic> json) {
    // Helper function to safely convert values to string
    String safeString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is List) return value.join(', ');
      return value.toString();
    }

    // Check for both possible profile picture field names
    String profilePicUrl = '';
    if (json.containsKey('profilePicture')) {
      profilePicUrl = safeString(json['profilePicture']);
    } else if (json.containsKey('profile_picture_url')) {
      profilePicUrl = safeString(json['profile_picture_url']);
    }

    return InZoneAvatar(
      id: safeString(json['id']),
      name: safeString(json['name']),
      bio: safeString(json['bio']),
      username: safeString(json['name']),
      profilePicture: profilePicUrl,
      personality: safeString(json['personality']),
      gender: safeString(json['gender']) != ''
          ? safeString(json['gender'])
          : 'not specified',
      subCategory: safeString(json['category']) != ''
          ? safeString(json['category'])
          : 'not specified',
      age: json['age'] is int ? json['age'] : 0,
      greeting: safeString(json['greeting']),
    );
  }

  // Method to parse a list of InZoneAvatar objects from JSON
  static List<InZoneAvatar> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => InZoneAvatar.fromJson(json)).toList();
  }
}
