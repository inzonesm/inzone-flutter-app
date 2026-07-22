import 'package:flutter_test/flutter_test.dart';
import 'package:inzone/services/analytics_service.dart';
import 'package:inzone/services/game_session_analytics.dart';

class _FakeClock {
  _FakeClock(this.current);

  DateTime current;

  DateTime call() => current;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}

class _FakeTimerHandle implements GameSessionTimerHandle {
  _FakeTimerHandle(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  void cancel() {
    _active = false;
  }

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }
}

class _FakeTimerScheduler {
  final List<_FakeTimerHandle> timers = <_FakeTimerHandle>[];

  GameSessionTimerHandle create(Duration duration, void Function() callback) {
    final timer = _FakeTimerHandle(duration, callback);
    timers.add(timer);
    return timer;
  }

  _FakeTimerHandle? get lastTimer => timers.isEmpty ? null : timers.last;

  int get activeTimers => timers.where((timer) => timer.isActive).length;
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('GameSessionLifecycleCoordinator', () {
    late _FakeClock clock;
    late _FakeTimerScheduler scheduler;
    late List<Map<String, Object?>> events;
    late int idCounter;

    late GameSessionLifecycleCoordinator coordinator;

    setUp(() {
      clock = _FakeClock(DateTime.utc(2026, 7, 22, 12, 0, 0));
      scheduler = _FakeTimerScheduler();
      events = <Map<String, Object?>>[];
      idCounter = 0;

      coordinator = GameSessionLifecycleCoordinator(
        gameId: 'game-1',
        gameName: 'Game One',
        now: clock.call,
        timerFactory: scheduler.create,
        sessionIdFactory: () => 'session-${++idCounter}',
        trackEvent: (
          String eventName, {
          Map<String, Object?>? parameters,
          String? gameId,
          String? gameName,
          String? sessionId,
        }) async {
          events.add({
            'event': eventName,
            'parameters': parameters ?? <String, Object?>{},
            'game_id': gameId,
            'game_name': gameName,
            'session_id': sessionId,
          });
        },
      );
    });

    test('keeps one session ID across a complete session', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();
      await coordinator.endSession(endReason: 'dispose');

      final opened = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameOpened);
      final loaded = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameLoaded);
      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);

      expect(opened['session_id'], equals('session-1'));
      expect(loaded['session_id'], equals('session-1'));
      expect(ended['session_id'], equals('session-1'));
    });

    test('creates a new session ID for the next session', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.endSession(endReason: 'navigation');

      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.endSession(endReason: 'dispose');

      final openedEvents = events
          .where((event) => event['event'] == AnalyticsService.eventGameOpened)
          .toList();
      expect(openedEvents.length, 2);
      expect(openedEvents[0]['session_id'], equals('session-1'));
      expect(openedEvents[1]['session_id'], equals('session-2'));
    });

    test('qualifies after 30 seconds from game_loaded', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      final timer = scheduler.lastTimer;
      expect(timer, isNotNull);
      expect(timer!.delay, const Duration(seconds: 30));

      clock.advance(const Duration(seconds: 30));
      timer.fire();
      await _flushMicrotasks();

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        1,
      );
    });

    test('qualifies on score submission', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();
      await coordinator.trackScoreSubmitted(score: 42, scoreType: 'best');

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventScoreSubmitted)
            .length,
        1,
      );
      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        1,
      );
    });

    test('qualifies on coin spend', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();
      await coordinator.markCoinSpend(coins: 25);

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        1,
      );
    });

    test('qualified_play emits only once with multiple triggers', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();
      await coordinator.trackScoreSubmitted(score: 7);
      await coordinator.markCoinSpend(coins: 10);

      final timer = scheduler.lastTimer;
      expect(timer, isNotNull);
      timer!.fire();
      await _flushMicrotasks();

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        1,
      );
    });

    test('game_ended includes duration and active session ID', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      clock.advance(const Duration(seconds: 12));
      await coordinator.endSession(endReason: 'user_close');

      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final parameters = ended['parameters']! as Map<String, Object?>;

      expect(ended['session_id'], equals('session-1'));
      expect(parameters['duration_seconds'], equals(12));
      expect(parameters['end_reason'], equals('user_close'));
    });

    test('score_submitted includes active session ID', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.trackScoreSubmitted(score: 123);

      final scoreEvent = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventScoreSubmitted);
      final parameters = scoreEvent['parameters']! as Map<String, Object?>;

      expect(scoreEvent['session_id'], equals('session-1'));
      expect(parameters['score'], equals(123));
    });

    test('repeated load callbacks emit game_loaded once', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();
      await coordinator.markGameLoaded();

      expect(
        events
            .where(
                (event) => event['event'] == AnalyticsService.eventGameLoaded)
            .length,
        1,
      );
    });

    test('repeated end paths emit game_ended once', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.endSession(endReason: 'navigation');
      await coordinator.endSession(endReason: 'dispose');

      expect(
        events
            .where((event) => event['event'] == AnalyticsService.eventGameEnded)
            .length,
        1,
      );
    });

    test('qualified timer is cancelled after session end', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      expect(coordinator.isQualifiedTimerActive, isTrue);
      await coordinator.endSession(endReason: 'dispose');
      expect(coordinator.isQualifiedTimerActive, isFalse);

      final timer = scheduler.lastTimer;
      expect(timer, isNotNull);
      timer!.fire();
      await _flushMicrotasks();

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        0,
      );
    });
  });
}
