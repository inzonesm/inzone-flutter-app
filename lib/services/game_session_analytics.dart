import 'dart:async';
import 'dart:math';

import 'package:inzone/services/analytics_service.dart';
import 'package:inzone/services/community_game_service.dart';

typedef GameSessionEventLogger = Future<void> Function(
  String eventName, {
  Map<String, Object?>? parameters,
  String? gameId,
  String? gameName,
  String? sessionId,
});

typedef GameSessionTimerFactory = GameSessionTimerHandle Function(
  Duration duration,
  void Function() callback,
);

abstract class GameSessionTimerHandle {
  bool get isActive;
  void cancel();
}

class _DartGameSessionTimerHandle implements GameSessionTimerHandle {
  _DartGameSessionTimerHandle(this._timer);

  final Timer _timer;

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() {
    _timer.cancel();
  }
}

class GameSessionLifecycleCoordinator {
  GameSessionLifecycleCoordinator({
    required this.gameId,
    required this.trackEvent,
    this.gameName,
    DateTime Function()? now,
    GameSessionTimerFactory? timerFactory,
    String Function()? sessionIdFactory,
    Duration? qualifiedPlayThreshold,
  })  : _now = now ?? DateTime.now,
        _timerFactory = timerFactory ?? _defaultTimerFactory,
        _sessionIdFactory = sessionIdFactory ?? _generateUuidV4,
        _qualifiedPlayThreshold =
            qualifiedPlayThreshold ?? const Duration(seconds: 30);

  final String gameId;
  final String? gameName;
  final GameSessionEventLogger trackEvent;
  final DateTime Function() _now;
  final GameSessionTimerFactory _timerFactory;
  final String Function() _sessionIdFactory;
  final Duration _qualifiedPlayThreshold;

  String? _sessionId;
  DateTime? _sessionStartedAt;
  bool _sessionActive = false;

  bool _viewedEmitted = false;
  bool _loadedEmitted = false;
  bool _qualifiedEmitted = false;
  bool _endedEmitted = false;

  GameSessionTimerHandle? _qualifiedPlayTimer;

  String? get sessionId => _sessionId;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  bool get isQualifiedTimerActive => _qualifiedPlayTimer?.isActive ?? false;

  Future<void> markGameViewed() async {
    if (_viewedEmitted) return;
    _viewedEmitted = true;
    await _track(AnalyticsService.eventGameViewed);
  }

  String startSession() {
    if (_sessionActive && _sessionId != null) {
      return _sessionId!;
    }

    final startedAt = _now();
    _sessionId = _sessionIdFactory();
    _sessionStartedAt = startedAt;
    _sessionActive = true;
    _loadedEmitted = false;
    _qualifiedEmitted = false;
    _endedEmitted = false;
    _cancelQualifiedTimer();

    unawaited(_track(AnalyticsService.eventGameOpened));
    return _sessionId!;
  }

  Future<void> markGameLoaded() async {
    if (!_sessionActive || _endedEmitted || _loadedEmitted) return;
    _loadedEmitted = true;
    await _track(AnalyticsService.eventGameLoaded);
    _startQualifiedTimer();
  }

  Future<void> trackScoreSubmitted({
    required num score,
    String? scoreType,
  }) async {
    if (!_sessionActive || _endedEmitted) return;

    final parameters = <String, Object?>{'score': score};
    final normalizedScoreType = scoreType?.trim();
    if (normalizedScoreType != null && normalizedScoreType.isNotEmpty) {
      parameters['score_type'] = normalizedScoreType;
    }

    await _track(
      AnalyticsService.eventScoreSubmitted,
      parameters: parameters,
    );
    await markQualifiedPlay();
  }

  Future<void> markCoinSpend({required int coins}) async {
    if (coins <= 0 || !_sessionActive || _endedEmitted) return;
    await markQualifiedPlay();
  }

  Future<void> markQualifiedPlay() async {
    if (!_sessionActive || _endedEmitted || _qualifiedEmitted) return;
    _qualifiedEmitted = true;
    _cancelQualifiedTimer();
    await _track(AnalyticsService.eventQualifiedPlay);
  }

  Future<void> endSession({String? endReason}) async {
    if (!_sessionActive || _endedEmitted) return;

    _endedEmitted = true;
    _cancelQualifiedTimer();

    final startedAt = _sessionStartedAt;
    final endedAt = _now();
    final durationSeconds =
        startedAt == null ? 0 : max(0, endedAt.difference(startedAt).inSeconds);

    final parameters = <String, Object?>{'duration_seconds': durationSeconds};
    final normalizedEndReason = endReason?.trim();
    if (normalizedEndReason != null && normalizedEndReason.isNotEmpty) {
      parameters['end_reason'] = normalizedEndReason;
    }

    await _track(AnalyticsService.eventGameEnded, parameters: parameters);
    _sessionActive = false;
  }

  void dispose() {
    _cancelQualifiedTimer();
  }

  void _startQualifiedTimer() {
    if (_qualifiedEmitted ||
        !_sessionActive ||
        _endedEmitted ||
        _qualifiedPlayTimer != null) {
      return;
    }

    _qualifiedPlayTimer = _timerFactory(_qualifiedPlayThreshold, () {
      unawaited(markQualifiedPlay());
    });
  }

  Future<void> _track(
    String eventName, {
    Map<String, Object?>? parameters,
  }) async {
    try {
      await trackEvent(
        eventName,
        parameters: parameters,
        gameId: gameId,
        gameName: gameName,
        sessionId: _sessionId,
      );
    } catch (_) {
      // Lifecycle analytics must never block gameplay.
    }
  }

  void _cancelQualifiedTimer() {
    _qualifiedPlayTimer?.cancel();
    _qualifiedPlayTimer = null;
  }

  static GameSessionTimerHandle _defaultTimerFactory(
    Duration duration,
    void Function() callback,
  ) {
    return _DartGameSessionTimerHandle(Timer(duration, callback));
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final hex =
        values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class GameSessionAnalytics {
  static num? extractScoreValue({
    Map<String, dynamic>? primary,
    Map<String, dynamic>? secondary,
  }) {
    for (final map in [primary, secondary]) {
      final parsed = _extractScoreValueFromMap(map);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? extractScoreType({
    Map<String, dynamic>? primary,
    Map<String, dynamic>? secondary,
  }) {
    for (final map in [primary, secondary]) {
      if (map == null) continue;

      final direct = map['score_type'] ?? map['scoreType'] ?? map['type'];
      final parsed = _asNonEmptyString(direct);
      if (parsed != null) return parsed;

      final nestedScore = map['score'];
      if (nestedScore is Map) {
        final nested = Map<String, dynamic>.from(nestedScore);
        final nestedType = _asNonEmptyString(
          nested['score_type'] ?? nested['scoreType'] ?? nested['type'],
        );
        if (nestedType != null) return nestedType;
      }
    }

    return null;
  }

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

  static num? _extractScoreValueFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;

    for (final key in ['score', 'value', 'points', 'best']) {
      final parsed = _asNum(map[key]);
      if (parsed != null) return parsed;
    }

    final nestedData = map['data'];
    if (nestedData is Map) {
      final parsed =
          _extractScoreValueFromMap(Map<String, dynamic>.from(nestedData));
      if (parsed != null) return parsed;
    }

    final nestedScore = map['score'];
    if (nestedScore is Map) {
      final normalized = Map<String, dynamic>.from(nestedScore);
      final best = _asNum(normalized['best']);
      if (best != null) return best;
      final value = _asNum(normalized['value']);
      if (value != null) return value;
    }

    return null;
  }

  static num? _asNum(Object? value) {
    if (value is num) return value;
    if (value == null) return null;
    return num.tryParse(value.toString().trim());
  }

  static String? _asNonEmptyString(Object? value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }
}
