import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/data/community_game.dart';

class CommunityGameService {
  static const String _collection = 'html_games';
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Games uploaded by this account display an inflated, synthetic "playing"
  /// count instead of their real open-session total.
  static const String _inflatedPlayerUploaderId =
      'stleyc71xUZJTmcx88A6Mv9dyYs2';

  /// How long an inflated count holds steady before it rolls to a new value.
  /// Both clients bucket wall-clock time by this window, so the Flutter app and
  /// the inzone-games website derive the SAME number for a game within the same
  /// window (device clocks only need to be roughly in sync).
  static const int _inflatedWindowMs = 60000;

  /// Deterministic 32-bit FNV-1a hash of a string. Mirrors `fnv1a32` in the
  /// website's lib/games.ts so both platforms map a given seed to the same
  /// number.
  static int _fnv1a32(String seed) {
    int h = 0x811c9dc5;
    for (final c in seed.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  /// A "playing" count in the inclusive range 999–9999, derived from the game
  /// id and the current time window. Same inputs → same output on every device,
  /// so the app and the website always show the same number for a game.
  static int _inflatedPlayerCount(String gameId) {
    final windowIndex =
        DateTime.now().millisecondsSinceEpoch ~/ _inflatedWindowMs;
    final hash = _fnv1a32('$gameId:$windowIndex');
    return 999 + (hash % 9001); // 9999 − 999 + 1 = 9001 possible values
  }

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
  ///
  /// Exception: games owned by [_inflatedPlayerUploaderId] skip the query and
  /// return a synthetic count in 999–9999 that is identical on the app and the
  /// website for the same game + time window. Pass the game's [uploaderId]
  /// (already loaded with the hub list) so this needs no extra read.
  static Future<int> fetchLivePlayerCount(
    String gameId, {
    String? uploaderId,
  }) async {
    if (gameId.isEmpty) return 0;
    if (uploaderId == _inflatedPlayerUploaderId) {
      return _inflatedPlayerCount(gameId);
    }
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

  /// Returns the gameKey for a game, creating one if it doesn't exist yet.
  /// Format: gk_live_{gameId}_{uploaderId}
  /// Only writes to Firestore when the field is absent — never overwrites.
  static Future<String> ensureGameKey({
    required String gameId,
    required String uploaderId,
  }) async {
    final docRef = _db.collection(_collection).doc(gameId);
    final snap = await docRef.get();
    if (snap.exists) {
      final data = snap.data() ?? {};
      final existing = ((data['gameKey'] as String?) ??
              (data['game_key'] as String?) ??
              '')
          .trim();
      if (existing.isNotEmpty) return existing;
    }
    final generated = 'gk_live_${gameId}_$uploaderId';
    await docRef.set({'gameKey': generated}, SetOptions(merge: true));
    return generated;
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
