import 'package:flutter/foundation.dart';

/// Holds the latest score the game reported, so the social overlay's share
/// flows (send challenge / open chat / message a friend / share to InZone) can
/// include it in their prewritten messages.
///
/// A game can surface its score through several paths, and this bridge captures
/// all of them (see `_handleSocialLoopAction` in community_game_screen.dart):
///
///  * the `InZoneSDK.postScore({ score })` bridge method — the request payload
///    and the backend response are both teed in;
///  * `InZoneSDK.sendChallenge({ score })` / `openChat({ context: { score } })`;
///  * games that bypass the SDK and call the REST endpoints directly with
///    `fetch`/`XMLHttpRequest` — an injected interceptor forwards the request
///    body and response of `/post-score`, `/send-challenge`, `/progress/share`
///    and `/open-chat` here via the `notifyScore` action.
///
/// Extraction is deliberately forgiving: scores arrive under many key names
/// (`score`, `value`, `points`, `best`…), sometimes nested inside `score`,
/// `metadata`, `context` or `data`, sometimes as strings, and sometimes only
/// inside a human "I scored 1,234 …" share title. Games that never report a
/// score simply produce score-less messages — every overlay flow handles
/// `latestScore == null`.
class SocialBridge extends ChangeNotifier {
  SocialBridge({this.keepMaxScore = true});

  /// If true, only a higher score replaces the current one (so the share
  /// message reflects the player's best run this session, like the in-game
  /// "Best Score").
  final bool keepMaxScore;

  int? _latestScore;
  int? get latestScore => _latestScore;
  bool get hasScore => _latestScore != null;

  /// Keys that commonly hold a numeric score across community games.
  static const List<String> _scoreKeys = <String>[
    'score',
    'value',
    'points',
    'point',
    'best',
    'bestScore',
    'best_score',
    'highScore',
    'high_score',
    'highscore',
    'finalScore',
    'final_score',
    'total',
    'result',
  ];

  /// Containers a score is commonly nested inside of.
  static const List<String> _nestedKeys = <String>[
    'score',
    'data',
    'metadata',
    'context',
    'payload',
    'stats',
    'detail',
  ];

  // -------------------------------------------------------------------
  // Public recording API
  // -------------------------------------------------------------------

  /// Back-compat alias used by the bridge `postScore` action: tees the request
  /// payload a game passed to `InZoneSDK.postScore(...)`.
  void recordPostScore(Map<String, dynamic> payload) =>
      recordScoreFromMap(payload);

  /// Tee a score out of an arbitrary request payload (post-score,
  /// send-challenge, open-chat context, progress-share…).
  void recordScoreFromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return;
    _record(_extractScore(map));
  }

  /// Tee the canonical score out of a backend response. `post-score` returns
  /// `score: { value, best }` (optionally under `data`), and the share
  /// endpoints return a `share: { title, message }` whose text contains the
  /// number.
  void recordScoreFromResponse(Map<dynamic, dynamic>? map) {
    if (map == null) return;
    final dynamic dataNode = map['data'];
    final Map<dynamic, dynamic> data =
        dataNode is Map ? dataNode : map;

    final dynamic score = data['score'];
    if (score is Map) {
      _record(_toInt(score['best']) ?? _toInt(score['value']));
    } else {
      _record(_toInt(score));
    }

    final dynamic share = data['share'];
    if (share is Map) {
      _record(_scoreFromText(share['title']?.toString()));
      _record(_scoreFromText(share['message']?.toString()));
    }

    // Last resort: dig anywhere in the response for a numeric score.
    _record(_extractScore(data));
  }

  /// Call when a new game session starts (e.g. when the feed page changes).
  void reset() {
    if (_latestScore == null) return;
    _latestScore = null;
    notifyListeners();
  }

  // -------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------

  void _record(int? value) {
    if (value == null) return;
    if (keepMaxScore && _latestScore != null && value <= _latestScore!) return;
    if (_latestScore == value) return;
    _latestScore = value;
    notifyListeners();
  }

  static int? _toInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.round();
    return int.tryParse(raw.toString().trim());
  }

  /// Depth-limited search for a score under the known flat keys, then inside
  /// the known nested containers.
  static int? _extractScore(dynamic node, [int depth = 0]) {
    if (node == null || depth > 4) return null;
    if (node is num) return node.round();
    if (node is Map) {
      for (final String k in _scoreKeys) {
        if (node.containsKey(k)) {
          final int? v = _toInt(node[k]);
          if (v != null) return v;
        }
      }
      for (final String k in _nestedKeys) {
        if (node[k] is Map) {
          final int? nested = _extractScore(node[k], depth + 1);
          if (nested != null) return nested;
        }
      }
    }
    return null;
  }

  /// Pull the first number out of a human string like "I scored 1,234 in …".
  static int? _scoreFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final RegExpMatch? m = RegExp(r'(\d[\d,]*)').firstMatch(text);
    if (m == null) return null;
    return int.tryParse(m.group(1)!.replaceAll(',', ''));
  }
}
