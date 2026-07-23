import 'dart:async';

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

  void fireEvenIfCancelled() {
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

  _FakeTimerHandle? takeLastActive() {
    final active = timers.where((timer) => timer.isActive).toList();
    if (active.isEmpty) return null;
    return active.last;
  }
}

class _FakeStopwatch implements GameSessionStopwatch {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  @override
  Duration get elapsed => _elapsed;

  @override
  bool get isRunning => _running;

  @override
  void reset() {
    _running = false;
    _elapsed = Duration.zero;
  }

  @override
  void start() {
    _running = true;
  }

  @override
  void stop() {
    _running = false;
  }

  void advance(Duration duration) {
    if (_running) {
      _elapsed += duration;
    }
  }
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('GameSessionLifecycleCoordinator', () {
    late _FakeClock clock;
    late _FakeTimerScheduler scheduler;
    late _FakeStopwatch stopwatch;
    late List<Map<String, Object?>> events;
    late int idCounter;

    late GameSessionLifecycleCoordinator coordinator;

    setUp(() {
      clock = _FakeClock(DateTime.utc(2026, 7, 22, 12, 0, 0));
      scheduler = _FakeTimerScheduler();
      stopwatch = _FakeStopwatch();
      events = <Map<String, Object?>>[];
      idCounter = 0;

      coordinator = GameSessionLifecycleCoordinator(
        gameId: 'game-1',
        gameName: 'Game One',
        now: clock.call,
        timerFactory: scheduler.create,
        stopwatchFactory: () => stopwatch,
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

      stopwatch.advance(const Duration(seconds: 30));
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
      await coordinator.markGameLoaded();
      clock.advance(const Duration(seconds: 12));
      stopwatch.advance(const Duration(seconds: 8));
      await coordinator.endSession(endReason: 'user_close');

      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final parameters = ended['parameters']! as Map<String, Object?>;

      expect(ended['session_id'], equals('session-1'));
      expect(parameters['duration_seconds'], equals(12));
      expect(parameters['active_duration_seconds'], equals(8));
      expect(parameters['heartbeat_count'], equals(0));
      expect(parameters['qualified_play'], isFalse);
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

    test('no heartbeat before game_loaded', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      stopwatch.advance(const Duration(seconds: 30));

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventGameHeartbeat)
            .isEmpty,
        isTrue,
      );
    });

    test('first heartbeat emits after 30 seconds of active play', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final heartbeats = events
          .where(
              (event) => event['event'] == AnalyticsService.eventGameHeartbeat)
          .toList();
      expect(heartbeats.length, 1);
      final payload = heartbeats.single['parameters']! as Map<String, Object?>;
      expect(payload['elapsed_seconds'], equals(30));
      expect(payload['heartbeat_index'], equals(1));
    });

    test('heartbeats recur every 30 active seconds', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final heartbeats = events
          .where(
              (event) => event['event'] == AnalyticsService.eventGameHeartbeat)
          .toList();
      expect(heartbeats.length, 2);
      expect(
        heartbeats
            .map((event) => (event['parameters']!
                as Map<String, Object?>)['elapsed_seconds'])
            .toList(),
        equals([30, 60]),
      );
      expect(
        heartbeats
            .map((event) => (event['parameters']!
                as Map<String, Object?>)['heartbeat_index'])
            .toList(),
        equals([1, 2]),
      );
    });

    test('background time does not count toward heartbeats', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 10));
      coordinator.setAppActive(false);
      stopwatch.advance(const Duration(seconds: 60));

      coordinator.setAppActive(true);
      stopwatch.advance(const Duration(seconds: 20));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final heartbeat = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameHeartbeat);
      final payload = heartbeat['parameters']! as Map<String, Object?>;
      expect(payload['elapsed_seconds'], equals(30));
      expect(payload['heartbeat_index'], equals(1));
    });

    test('screen invisibility time does not count toward heartbeats', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 10));
      coordinator.setScreenVisible(false);
      stopwatch.advance(const Duration(seconds: 120));

      coordinator.setScreenVisible(true);
      stopwatch.advance(const Duration(seconds: 20));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final heartbeat = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameHeartbeat);
      final payload = heartbeat['parameters']! as Map<String, Object?>;
      expect(payload['elapsed_seconds'], equals(30));
      expect(payload['heartbeat_index'], equals(1));
    });

    test('heartbeat resumes after foregrounding same active session', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      coordinator.setAppActive(false);
      stopwatch.advance(const Duration(seconds: 45));
      coordinator.setAppActive(true);
      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final heartbeats = events
          .where(
              (event) => event['event'] == AnalyticsService.eventGameHeartbeat)
          .toList();
      expect(heartbeats.length, 2);
      final second = heartbeats[1]['parameters']! as Map<String, Object?>;
      expect(second['elapsed_seconds'], equals(60));
      expect(second['heartbeat_index'], equals(2));
    });

    test('session end stops future heartbeats', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 29));
      await coordinator.endSession(endReason: 'user_close');

      final activeTimer = scheduler.takeLastActive();
      if (activeTimer != null) {
        activeTimer.fire();
      }
      await _flushMicrotasks();

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventGameHeartbeat)
            .isEmpty,
        isTrue,
      );
    });

    test('heartbeat index increments monotonically without duplicates',
        () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      for (var i = 0; i < 3; i++) {
        stopwatch.advance(const Duration(seconds: 30));
        scheduler.takeLastActive()!.fire();
        await _flushMicrotasks();
      }

      final indexes = events
          .where(
              (event) => event['event'] == AnalyticsService.eventGameHeartbeat)
          .map((event) =>
              (event['parameters']! as Map<String, Object?>)['heartbeat_index'])
          .toList();

      expect(indexes, equals([1, 2, 3]));
    });

    test('single delayed callback catches up only active elapsed boundaries',
        () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 95));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final heartbeats = events
          .where(
              (event) => event['event'] == AnalyticsService.eventGameHeartbeat)
          .toList();
      expect(heartbeats.length, 3);
      expect(
        heartbeats
            .map((event) => (event['parameters']!
                as Map<String, Object?>)['elapsed_seconds'])
            .toList(),
        equals([30, 60, 90]),
      );
      expect(
        heartbeats
            .map((event) => (event['parameters']!
                as Map<String, Object?>)['heartbeat_index'])
            .toList(),
        equals([1, 2, 3]),
      );

      final endedBefore = events
          .where((event) => event['event'] == AnalyticsService.eventGameEnded)
          .length;
      expect(endedBefore, 0);

      await coordinator.endSession(endReason: 'user_close');
      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final endedPayload = ended['parameters']! as Map<String, Object?>;
      expect(endedPayload['heartbeat_count'], equals(3));
      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        1,
      );
    });

    test('30 active seconds qualifies exactly once', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final qualifiedEvents = events
          .where(
              (event) => event['event'] == AnalyticsService.eventQualifiedPlay)
          .toList();
      expect(qualifiedEvents.length, 1);

      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        1,
      );
    });

    test('score qualification still works before 30 seconds', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 5));
      await coordinator.trackScoreSubmitted(score: 22, scoreType: 'best');
      await _flushMicrotasks();

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        1,
      );
    });

    test('coin-spend qualification still works before 30 seconds', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 7));
      await coordinator.markCoinSpend(coins: 3);
      await _flushMicrotasks();

      expect(
        events
            .where((event) =>
                event['event'] == AnalyticsService.eventQualifiedPlay)
            .length,
        1,
      );
    });

    test('new session resets active timer and heartbeat index', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();
      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();
      await coordinator.endSession(endReason: 'navigation');

      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();
      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final openedSessions = events
          .where((event) => event['event'] == AnalyticsService.eventGameOpened)
          .map((event) => event['session_id'])
          .toList();
      expect(openedSessions, equals(['session-1', 'session-2']));

      final secondSessionHeartbeat = events.firstWhere((event) {
        return event['event'] == AnalyticsService.eventGameHeartbeat &&
            event['session_id'] == 'session-2';
      });
      final payload =
          secondSessionHeartbeat['parameters']! as Map<String, Object?>;
      expect(payload['heartbeat_index'], equals(1));
      expect(payload['elapsed_seconds'], equals(30));
    });

    test('old queued callback cannot affect replacement session', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 95));
      final oldTimer = scheduler.takeLastActive();
      expect(oldTimer, isNotNull);

      await coordinator.endSession(endReason: 'navigation');

      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      oldTimer!.fireEvenIfCancelled();
      await _flushMicrotasks();

      final staleHeartbeats = events.where((event) {
        return event['event'] == AnalyticsService.eventGameHeartbeat &&
            event['session_id'] == 'session-1';
      }).toList();
      expect(staleHeartbeats, isEmpty);

      final staleQualified = events.where((event) {
        return event['event'] == AnalyticsService.eventQualifiedPlay &&
            event['session_id'] == 'session-1';
      }).toList();
      expect(staleQualified, isEmpty);

      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      final newSessionHeartbeats = events.where((event) {
        return event['event'] == AnalyticsService.eventGameHeartbeat &&
            event['session_id'] == 'session-2';
      }).toList();
      expect(newSessionHeartbeats.length, 1);
      final payload =
          newSessionHeartbeats.single['parameters']! as Map<String, Object?>;
      expect(payload['elapsed_seconds'], equals(30));
      expect(payload['heartbeat_index'], equals(1));
    });

    test('queued timer callback after endSession emits no heartbeat', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 60));
      final queued = scheduler.takeLastActive();
      expect(queued, isNotNull);

      await coordinator.endSession(endReason: 'user_close');
      queued!.fireEvenIfCancelled();
      await _flushMicrotasks();

      final heartbeatEvents = events
          .where(
              (event) => event['event'] == AnalyticsService.eventGameHeartbeat)
          .toList();
      expect(heartbeatEvents, isEmpty);

      final endedEvents = events
          .where((event) => event['event'] == AnalyticsService.eventGameEnded)
          .toList();
      expect(endedEvents.length, 1);
    });

    test('end during loading emits game_ended and leaves no active timers',
        () async {
      coordinator.startSession();
      await _flushMicrotasks();

      await coordinator.endSession(endReason: 'navigation');

      expect(coordinator.isQualifiedTimerActive, isFalse);
      expect(coordinator.isHeartbeatTimerActive, isFalse);
      expect(scheduler.activeTimers, 0);

      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final payload = ended['parameters']! as Map<String, Object?>;
      expect(payload['heartbeat_count'], equals(0));
      expect(payload['active_duration_seconds'], equals(0));
    });

    test('multiple pause resume cycles accumulate active duration correctly',
        () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 10));
      coordinator.setAppActive(false);
      stopwatch.advance(const Duration(seconds: 999));

      coordinator.setAppActive(true);
      stopwatch.advance(const Duration(seconds: 8));
      coordinator.setScreenVisible(false);
      stopwatch.advance(const Duration(seconds: 999));

      coordinator.setScreenVisible(true);
      stopwatch.advance(const Duration(seconds: 12));

      await coordinator.endSession(endReason: 'user_close');

      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final payload = ended['parameters']! as Map<String, Object?>;
      expect(payload['active_duration_seconds'], equals(30));
    });

    test('ending while paused keeps accumulated active duration', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 20));
      coordinator.setScreenVisible(false);
      stopwatch.advance(const Duration(seconds: 500));

      await coordinator.endSession(endReason: 'navigation');

      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final payload = ended['parameters']! as Map<String, Object?>;
      expect(payload['active_duration_seconds'], equals(20));
    });

    test('active duration is truncated to whole seconds', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(milliseconds: 29900));
      await coordinator.endSession(endReason: 'user_close');

      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final payload = ended['parameters']! as Map<String, Object?>;
      expect(payload['active_duration_seconds'], equals(29));
    });

    test('heartbeat and end payloads use firebase-compatible scalar types',
        () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 30));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();
      await coordinator.endSession(endReason: 'user_close');

      final heartbeat = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameHeartbeat);
      final heartbeatPayload = heartbeat['parameters']! as Map<String, Object?>;
      expect(heartbeatPayload['game_id'], isA<String>());
      expect(heartbeatPayload['session_id'], isA<String>());
      expect(heartbeatPayload['elapsed_seconds'], isA<int>());
      expect(heartbeatPayload['heartbeat_index'], isA<int>());
      expect(heartbeatPayload['qualified_play'], isA<bool>());

      final ended = events.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final endedPayload = ended['parameters']! as Map<String, Object?>;
      expect(endedPayload['active_duration_seconds'], isA<int>());
      expect(endedPayload['heartbeat_count'], isA<int>());
      expect(endedPayload['qualified_play'], isA<bool>());
    });

    test('heartbeat completion after cleanup cannot mutate session state',
        () async {
      final heartbeatCompleter = Completer<void>();
      final blockedEvents = <Map<String, Object?>>[];

      final blockedCoordinator = GameSessionLifecycleCoordinator(
        gameId: 'game-1',
        gameName: 'Game One',
        now: clock.call,
        timerFactory: scheduler.create,
        stopwatchFactory: () => stopwatch,
        sessionIdFactory: () => 'session-1',
        trackEvent: (
          String eventName, {
          Map<String, Object?>? parameters,
          String? gameId,
          String? gameName,
          String? sessionId,
        }) async {
          if (eventName == AnalyticsService.eventGameHeartbeat) {
            await heartbeatCompleter.future;
          }
          blockedEvents.add({
            'event': eventName,
            'parameters': parameters ?? <String, Object?>{},
            'session_id': sessionId,
          });
        },
      );

      blockedCoordinator.startSession();
      await _flushMicrotasks();
      await blockedCoordinator.markGameLoaded();

      stopwatch.advance(const Duration(seconds: 60));
      scheduler.takeLastActive()!.fire();
      await _flushMicrotasks();

      await blockedCoordinator.endSession(endReason: 'user_close');

      heartbeatCompleter.complete();
      await _flushMicrotasks();

      final ended = blockedEvents.firstWhere(
          (event) => event['event'] == AnalyticsService.eventGameEnded);
      final payload = ended['parameters']! as Map<String, Object?>;
      expect(payload['heartbeat_count'], equals(0));
    });

    test('dispose cleans up timers and listeners', () async {
      coordinator.startSession();
      await _flushMicrotasks();
      await coordinator.markGameLoaded();

      expect(coordinator.isQualifiedTimerActive, isTrue);
      expect(coordinator.isHeartbeatTimerActive, isTrue);

      coordinator.dispose();

      expect(coordinator.isQualifiedTimerActive, isFalse);
      expect(coordinator.isHeartbeatTimerActive, isFalse);
      expect(scheduler.activeTimers, 0);
    });

    test('analytics failure does not interrupt session cleanup', () async {
      final failingCoordinator = GameSessionLifecycleCoordinator(
        gameId: 'game-1',
        gameName: 'Game One',
        now: clock.call,
        timerFactory: scheduler.create,
        stopwatchFactory: () => stopwatch,
        sessionIdFactory: () => 'session-fail',
        trackEvent: (
          String eventName, {
          Map<String, Object?>? parameters,
          String? gameId,
          String? gameName,
          String? sessionId,
        }) async {
          throw StateError('analytics down');
        },
      );

      failingCoordinator.startSession();
      await _flushMicrotasks();
      await failingCoordinator.markGameLoaded();
      await failingCoordinator.endSession(endReason: 'dispose');

      expect(failingCoordinator.isHeartbeatTimerActive, isFalse);
      expect(failingCoordinator.isQualifiedTimerActive, isFalse);
    });
  });
}
