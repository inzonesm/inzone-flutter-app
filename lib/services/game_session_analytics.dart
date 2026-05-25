import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:simula_ads/simula_ads.dart';
 
class GameSessionAnalytics {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _userRef(String userId) {
    return _db.collection('gameFeedback').doc(userId);
  }

  static DocumentReference<Map<String, dynamic>> _sessionRef(
    String userId,
    String sessionId,
  ) {
    return _userRef(userId).collection('gameSessions').doc(sessionId);
  }

  static Future<void> recordSessionStart(MiniGameSessionStart session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final gameId = session.game?.id ?? 'unknown';
    final gameName = session.game?.name ?? '';

    await _sessionRef(user.uid, session.sessionId).set({
      'session_id': session.sessionId,
      'user_id': user.uid,
      'game_id': gameId,
      'game_name': gameName,
      'opened_at': Timestamp.fromDate(session.openedAt),
      'coins_used': 0,
      'status': 'open',
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _userRef(user.uid).set({
      'user_id': user.uid,
      'last_game_id': gameId,
      'last_game_name': gameName,
      'last_opened_at': Timestamp.fromDate(session.openedAt),
      'gameCount': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> recordSessionCoinSpend(
    MiniGameSessionCoinSpend spend,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _sessionRef(user.uid, spend.sessionId).set({
      'coins_used': FieldValue.increment(spend.coins),
      'last_coin_at': Timestamp.fromDate(spend.recordedAt),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> recordSessionEnd(MiniGameSessionEnd session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _sessionRef(user.uid, session.sessionId).set({
      'closed_at': Timestamp.fromDate(session.closedAt),
      'duration_ms': session.durationMs,
      'duration_seconds': session.durationSeconds,
      'coins_used': session.coinsUsed,
      'played_likely': session.playedLikely,
      'game_over_text': session.gameOverText,
      'status': 'closed',
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _userRef(user.uid).set({
      'last_closed_at': Timestamp.fromDate(session.closedAt),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
