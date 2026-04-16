import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Unity game/experience available in the hub.
///
/// Firestore collection: `unityGames`
/// Each document maps to one downloadable Unity Addressable content pack.
class UnityGame {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String bannerUrl;
  final String bundleUrl;
  final String sceneName;
  final String category;
  final String bundleFile;
  final int bundleSizeBytes;
  final int sizeMb;
  final String version;
  final DateTime createdAt;
  final bool isActive;

  UnityGame({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.bannerUrl,
    required this.bundleUrl,
    required this.sceneName,
    required this.category,
    this.bundleFile = '',
    this.bundleSizeBytes = 0,
    required this.sizeMb,
    required this.version,
    required this.createdAt,
    this.isActive = true,
  });

  factory UnityGame.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UnityGame(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      bannerUrl: data['bannerUrl'] ?? '',
      bundleUrl: data['bundleUrl'] ?? '',
      sceneName: data['sceneName'] ?? '',
      category: data['category'] ?? 'General',
      bundleFile: data['bundleFile'] ?? '',
      bundleSizeBytes: data['bundleSizeBytes'] ?? 0,
      sizeMb: data['sizeMb'] ?? 0,
      version: data['version'] ?? '1.0',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'bannerUrl': bannerUrl,
      'bundleUrl': bundleUrl,
      'sceneName': sceneName,
      'category': category,
      'bundleFile': bundleFile,
      'bundleSizeBytes': bundleSizeBytes,
      'sizeMb': sizeMb,
      'version': version,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}
