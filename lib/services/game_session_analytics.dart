import 'package:inzone/services/community_game_service.dart';

class GameSessionAnalytics {
  static Future<void> recordSessionStart({
    required String gameId,
    required String sessionId,
    required String userId,
    required DateTime openedAt,
    String? gameName,
  }) {
    return CommunityGameService.recordSessionStart(
      gameId: gameId,
      sessionId: sessionId,
      userId: userId,
      openedAt: openedAt,
      gameName: gameName,
    );
  }

  static Future<void> recordSessionCoinSpend({
    required String gameId,
    required String sessionId,
    required int coins,
  }) {
    return CommunityGameService.recordSessionCoinSpend(
      gameId: gameId,
      sessionId: sessionId,
      coins: coins,
    );
  }

  static Future<void> recordSessionEnd({
    required String gameId,
    required String sessionId,
    required String userId,
    required DateTime openedAt,
    required DateTime closedAt,
    required int coinsSpent,
    String? gameName,
  }) {
    return CommunityGameService.recordSessionEnd(
      gameId: gameId,
      sessionId: sessionId,
      userId: userId,
      openedAt: openedAt,
      closedAt: closedAt,
      coinsSpent: coinsSpent,
      gameName: gameName,
    );
  }
}
