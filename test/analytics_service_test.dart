import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzone/services/analytics_service.dart';

Future<AnalyticsService> _buildService(
  List<Map<String, Object?>> capturedEvents,
) async {
  return AnalyticsService(
    sharedPreferences: await SharedPreferences.getInstance(),
    firebaseLogger: (eventName, parameters) async {
      capturedEvents.add({
        'eventName': eventName,
        'parameters': Map<String, Object?>.from(parameters),
      });
    },
  );
}

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

  group('AnalyticsService phase 3 product events', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('social_action includes action and optional identifiers', () async {
      final capturedEvents = <Map<String, Object?>>[];
      final service = await _buildService(capturedEvents);

      await service.logSocialAction(
        actionType: 'invite_sent',
        gameId: 'game-1',
        creatorId: 'creator-1',
        sessionId: 'session-1',
      );

      final event = capturedEvents.single;
      final payload = event['parameters']! as Map<String, Object?>;

      expect(event['eventName'], equals(AnalyticsService.eventSocialAction));
      expect(payload[AnalyticsService.fieldActionType], equals('invite_sent'));
      expect(payload[AnalyticsService.fieldGameId], equals('game-1'));
      expect(payload[AnalyticsService.fieldCreatorId], equals('creator-1'));
      expect(payload[AnalyticsService.fieldSessionId], equals('session-1'));
    });

    test('purchase_completed sends product payload', () async {
      final capturedEvents = <Map<String, Object?>>[];
      final service = await _buildService(capturedEvents);

      await service.logPurchaseCompleted(
        productId: 'premium_pack',
        price: 4.99,
        currency: 'USD',
      );

      final event = capturedEvents.single;
      final payload = event['parameters']! as Map<String, Object?>;

      expect(
          event['eventName'], equals(AnalyticsService.eventPurchaseCompleted));
      expect(payload[AnalyticsService.fieldProductId], equals('premium_pack'));
      expect(payload[AnalyticsService.fieldPrice], equals(4.99));
      expect(payload[AnalyticsService.fieldCurrency], equals('USD'));
    });

    test('creator_link_opened includes creator and source', () async {
      final capturedEvents = <Map<String, Object?>>[];
      final service = await _buildService(capturedEvents);

      await service.logCreatorLinkOpened(
        creatorId: 'creator-99',
        source: 'feed',
      );

      final event = capturedEvents.single;
      final payload = event['parameters']! as Map<String, Object?>;

      expect(
        event['eventName'],
        equals(AnalyticsService.eventCreatorLinkOpened),
      );
      expect(payload[AnalyticsService.fieldCreatorId], equals('creator-99'));
      expect(payload[AnalyticsService.fieldSource], equals('feed'));
    });

    test('cta event names map to cta_name parameter', () async {
      final capturedEvents = <Map<String, Object?>>[];
      final service = await _buildService(capturedEvents);

      const ctaNames = <String>[
        'download_game',
        'play_now',
        'join_group',
        'follow_creator',
        'share_game',
        'invite_friend',
      ];

      for (final ctaName in ctaNames) {
        await service.logAppCtaClicked(ctaName: ctaName);
      }

      expect(capturedEvents.length, equals(ctaNames.length));
      for (var index = 0; index < ctaNames.length; index++) {
        final event = capturedEvents[index];
        final payload = event['parameters']! as Map<String, Object?>;
        expect(event['eventName'], equals(AnalyticsService.eventAppCtaClicked));
        expect(payload[AnalyticsService.fieldCtaName], equals(ctaNames[index]));
      }
    });
  });
}
