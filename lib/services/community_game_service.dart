import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/data/community_game.dart';

class CommunityGameService {
  static const String _collection = 'html_games';

  static Future<List<CommunityGame>> fetchAll({int limit = 50}) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_collection)
        .where('status', isEqualTo: 'approved')
        .limit(limit)
        .get();

    final games = snapshot.docs
        .map(CommunityGame.fromSnapshot)
        .where((g) => g.gameUrl.isNotEmpty && g.name.isNotEmpty)
        .toList();

    games.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return games;
  }
}
