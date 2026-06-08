import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/data/community_game.dart';

class CommunityGameService {
  static const String _collection = 'html_games';
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _gameRef(String gameId) {
    return _db.collection(_collection).doc(gameId);
  }

  static DocumentReference<Map<String, dynamic>> _sessionRef(
    String gameId,
    String sessionId,
  ) {
    return _gameRef(gameId).collection('sessions').doc(sessionId);
  }

  static Future<List<CommunityGame>> fetchAll({int limit = 50}) async {
    final snapshot = await _db
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

  /// How many people are playing this game right now — the count of its open
  /// sessions (`html_games/<id>/sessions` where status == 'open'), the same
  /// live signal the dashboard uses. Uses a server-side aggregate count (no doc
  /// payloads) and is best-effort: a missing subcollection or denied read
  /// resolves to 0.
  static Future<int> fetchLivePlayerCount(String gameId) async {
    if (gameId.isEmpty) return 0;
    try {
      final snapshot = await _gameRef(gameId)
          .collection('sessions')
          .where('status', isEqualTo: 'open')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> recordSessionStart({
    required String gameId,
    required String sessionId,
    required String userId,
    required DateTime openedAt,
    String? gameName,
  }) async {
    await _sessionRef(gameId, sessionId).set({
      'session_id': sessionId,
      'game_id': gameId,
      'game_name': gameName,
      'user_id': userId,
      'opened_at': Timestamp.fromDate(openedAt),
      'coins_spent': 0,
      'status': 'open',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> recordSessionCoinSpend({
    required String gameId,
    required String sessionId,
    required int coins,
  }) async {
    if (coins <= 0) return;

    await _sessionRef(gameId, sessionId).set({
      'coins_spent': FieldValue.increment(coins),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> recordSessionEnd({
    required String gameId,
    required String sessionId,
    required String userId,
    required DateTime openedAt,
    required DateTime closedAt,
    required int coinsSpent,
    String? gameName,
  }) async {
    final duration = closedAt.difference(openedAt);

    await _sessionRef(gameId, sessionId).set({
      'session_id': sessionId,
      'game_id': gameId,
      'game_name': gameName,
      'user_id': userId,
      'opened_at': Timestamp.fromDate(openedAt),
      'closed_at': Timestamp.fromDate(closedAt),
      'duration_ms': duration.inMilliseconds,
      'duration_seconds': duration.inSeconds,
      'coins_spent': coinsSpent,
      'status': 'closed',
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String? buildShareTextFromSendChallenge(
      Map<String, dynamic> response) {
    final share = _asMap(response['share']);
    final shareCard = _asMap(response['shareCard']);

    final direct = _stringify(share?['text']);
    if (direct.isNotEmpty) {
      return direct;
    }

    final title = _firstNonEmpty([
      _stringify(share?['title']),
      _stringify(shareCard?['title']),
    ]);
    final message = _firstNonEmpty([
      _stringify(share?['message']),
      _stringify(shareCard?['message']),
    ]);
    final url = _firstNonEmpty([
      _stringify(share?['url']),
      _stringify(shareCard?['url']),
    ]);

    final parts = <String>[];
    if (title.isNotEmpty) parts.add(title);
    if (message.isNotEmpty) parts.add(message);
    if (url.isNotEmpty) parts.add(url);

    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  static String? buildShareSubjectFromSendChallenge(
      Map<String, dynamic> response) {
    final share = _asMap(response['share']);
    final shareCard = _asMap(response['shareCard']);
    final subject = _firstNonEmpty([
      _stringify(share?['subject']),
      _stringify(share?['title']),
      _stringify(shareCard?['title']),
    ]);
    return subject.isEmpty ? null : subject;
  }

  static String? extractShareKeyFromSendChallenge(
      Map<String, dynamic> response) {
    final challenge = _asMap(response['challenge']);
    final shareCard = _asMap(response['shareCard']);
    final challengeId = _stringify(challenge?['challengeId']);
    if (challengeId.isNotEmpty) return challengeId;
    final shareCardId = _stringify(shareCard?['shareCardId']);
    if (shareCardId.isNotEmpty) return shareCardId;
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String _stringify(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}
