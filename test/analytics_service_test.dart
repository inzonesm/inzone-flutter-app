import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzone/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService anonymous identity', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('creates and persists an anonymous id when none exists', () async {
      final service = AnalyticsService(
          sharedPreferences: await SharedPreferences.getInstance());
      final id = await service.getAnonymousId();
      expect(id, isNotEmpty);
      final persisted = (await SharedPreferences.getInstance())
          .getString(AnalyticsService.anonymousIdPrefsKey);
      expect(persisted, equals(id));
    });

    test('reuses an existing compatible guest id', () async {
      SharedPreferences.setMockInitialValues({
        AnalyticsService.legacyGuestIdPrefsKey: 'existing-guest-id',
      });
      final service = AnalyticsService(
          sharedPreferences: await SharedPreferences.getInstance());
      final id = await service.getAnonymousId();
      expect(id, equals('existing-guest-id'));
    });

    test('includes both anonymous_id and user_id when signed in', () async {
      final service = AnalyticsService(
          sharedPreferences: await SharedPreferences.getInstance());
      await service.setAuthenticatedUser('user-123');
      final identity = await service.resolveIdentity();
      expect(identity.anonymousId, isNotEmpty);
      expect(identity.userId, equals('user-123'));
      expect(identity.isAuthenticated, isTrue);
    });
  });

  group('AnalyticsService event payloads', () {
    test('adds common event parameters and filters null values', () async {
      final captured = <String, Object?>{};
      final service = AnalyticsService(
        sharedPreferences: await SharedPreferences.getInstance(),
        firebaseLogger: (eventName, parameters) async {
          captured['firebase'] = parameters;
        },
        appsFlyerLogger: (eventName, parameters) async {
          captured['appsflyer'] = parameters;
        },
      );
      await service.trackProductEvent(
        AnalyticsService.eventGameOpened,
        parameters: {'comment': 'hello', 'score': 12, 'empty': null},
        surface: 'home',
        entrySource: 'feed',
        gameId: 'game-1',
        gameName: 'Game 1',
      );
      final payload = captured['firebase'] as Map<String, Object?>;
      expect(payload[AnalyticsService.fieldAnonymousId], isNotNull);
      expect(payload[AnalyticsService.fieldEventId], isNotNull);
      expect(payload[AnalyticsService.fieldOccurredAt], isNotNull);
      expect(payload[AnalyticsService.fieldSurface], equals('home'));
      expect(payload[AnalyticsService.fieldEntrySource], equals('feed'));
      expect(payload[AnalyticsService.fieldGameId], equals('game-1'));
      expect(payload[AnalyticsService.fieldGameName], equals('Game 1'));
      expect(payload['comment'], isNull);
      expect(payload['score'], equals(12));
      expect(payload['empty'], isNull);
    });

    test('routes only allowlisted events to AppsFlyer', () async {
      final seen = <String>[];
      final service = AnalyticsService(
        sharedPreferences: await SharedPreferences.getInstance(),
        firebaseLogger: (eventName, parameters) async {},
        appsFlyerLogger: (eventName, parameters) async {
          seen.add(eventName);
        },
      );
      await service.trackProductEvent(AnalyticsService.eventGameOpened);
      await service.trackProductEvent(AnalyticsService.eventGameViewed);
      await service.trackProductEvent(AnalyticsService.eventPurchaseCompleted);
      expect(seen, contains(AnalyticsService.eventGameOpened));
      expect(seen, isNot(contains(AnalyticsService.eventGameViewed)));
      expect(seen, contains(AnalyticsService.eventPurchaseCompleted));
    });

    test('swallows analytics failures so app flow is not interrupted',
        () async {
      final service = AnalyticsService(
        sharedPreferences: await SharedPreferences.getInstance(),
        firebaseLogger: (eventName, parameters) async {
          throw StateError('boom');
        },
        appsFlyerLogger: (eventName, parameters) async {},
      );
      await expectLater(
        service.trackProductEvent(AnalyticsService.eventGameOpened),
        completes,
      );
    });
  });
}
