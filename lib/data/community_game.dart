import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityGame {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final String gameUrl;
  final String uploaderId;
  final String? gameKey;
  final DateTime? createdAt;

  CommunityGame({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.gameUrl,
    required this.uploaderId,
    this.gameKey,
    this.createdAt,
  });

  factory CommunityGame.fromSnapshot(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    final ts = data['createdAt'];
    return CommunityGame(
      id: doc.id,
      name: (data['name'] as String? ?? '').trim(),
      description: (data['description'] as String? ?? '').trim(),
      iconUrl: (data['iconUrl'] as String? ?? '').trim(),
      gameUrl: (data['gameUrl'] as String? ?? '').trim(),
      uploaderId: (data['uploaderId'] as String? ?? '').trim(),
      gameKey: (() {
        final value = (data['gameKey'] as String? ?? data['game_key'] as String? ?? '').trim();
        return value.isEmpty ? null : value;
      })(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
