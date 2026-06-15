import 'package:flutter/foundation.dart';

/// Holds the latest score the game reported through the **existing**
/// `InZoneSDK` socialLoop bridge — no new JS channel is needed, because
/// `_CommunityGamePage` already injects `window.InZoneSDK.postScore(...)`
/// into every community game.
///
/// Wire-up: in `_handleSocialLoopAction` (community_game_screen.dart),
/// the payload is teed into the bridge before forwarding to the backend:
/// ```dart
/// case 'postScore':
///   _socialBridge.recordPostScore(payload);
///   return client.postScore(mergePayload({}));
/// ```
///
/// Games that never call `postScore` simply produce score-less share
/// messages — every overlay flow handles `latestScore == null`.
class SocialBridge extends ChangeNotifier {
  SocialBridge({this.keepMaxScore = true});

  /// If true, only a higher score replaces the current one.
  final bool keepMaxScore;

  int? _latestScore;
  int? get latestScore => _latestScore;
  bool get hasScore => _latestScore != null;

  void recordPostScore(Map<String, dynamic> payload) {
    final raw = payload['score'] ?? payload['value'] ?? payload['points'];
    final int? value =
        raw is num ? raw.round() : int.tryParse(raw?.toString() ?? '');
    if (value == null) return;
    if (keepMaxScore && _latestScore != null && value <= _latestScore!) {
      return;
    }
    _latestScore = value;
    notifyListeners();
  }

  /// Call when a new game session starts (e.g. when the feed page changes).
  void reset() {
    _latestScore = null;
    notifyListeners();
  }
}
