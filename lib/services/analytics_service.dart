import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inzone/services/appsflyer_service.dart';

typedef AnalyticsTransportLogger = Future<void> Function(
  String eventName,
  Map<String, Object?> parameters,
);

class AnalyticsIdentityContext {
  const AnalyticsIdentityContext({
    required this.anonymousId,
    required this.userId,
    required this.isAuthenticated,
  });

  final String anonymousId;
  final String? userId;
  final bool isAuthenticated;
}

class AnalyticsService {
  AnalyticsService._({
    FirebaseAnalytics? firebaseAnalytics,
    AppsFlyerService? appsFlyerService,
    SharedPreferences? sharedPreferences,
    AnalyticsTransportLogger? firebaseLogger,
    AnalyticsTransportLogger? appsFlyerLogger,
  })  : _firebaseAnalytics = firebaseAnalytics ?? _resolveFirebaseAnalytics(),
        _appsFlyerService = appsFlyerService ?? AppsFlyerService(),
        _sharedPreferences = sharedPreferences,
        _firebaseLogger = firebaseLogger,
        _appsFlyerLogger = appsFlyerLogger,
        _sessionId = _generateUuidV4();

  /// Production callers use the no-argument form and share a single instance,
  /// so identity, session id, and the auth-state subscription are created once
  /// per process (not once per event/screen, which previously leaked a
  /// FirebaseAuth listener and produced unstable session ids and empty
  /// anonymous ids under concurrent init).
  ///
  /// Passing any dependency (tests / DI) returns a fresh, uncached instance so
  /// tests stay isolated and never mutate the shared singleton.
  factory AnalyticsService({
    FirebaseAnalytics? firebaseAnalytics,
    AppsFlyerService? appsFlyerService,
    SharedPreferences? sharedPreferences,
    AnalyticsTransportLogger? firebaseLogger,
    AnalyticsTransportLogger? appsFlyerLogger,
  }) {
    final hasOverrides = firebaseAnalytics != null ||
        appsFlyerService != null ||
        sharedPreferences != null ||
        firebaseLogger != null ||
        appsFlyerLogger != null;
    if (hasOverrides) {
      return AnalyticsService._(
        firebaseAnalytics: firebaseAnalytics,
        appsFlyerService: appsFlyerService,
        sharedPreferences: sharedPreferences,
        firebaseLogger: firebaseLogger,
        appsFlyerLogger: appsFlyerLogger,
      );
    }
    return _instance ??= AnalyticsService._();
  }

  static AnalyticsService get instance => AnalyticsService();

  static AnalyticsService? _instance;

  static const String anonymousIdPrefsKey = 'inzone_analytics_anonymous_id';
  static const String legacyGuestIdPrefsKey = 'inzone_guest_id';

  static const String eventGameViewed = 'game_viewed';
  static const String eventGameOpened = 'game_opened';
  static const String eventGameLoaded = 'game_loaded';
  static const String eventGameHeartbeat = 'game_heartbeat';
  static const String eventQualifiedPlay = 'qualified_play';
  static const String eventGameEnded = 'game_ended';
  static const String eventScoreSubmitted = 'score_submitted';
  static const String eventSocialAction = 'social_action';
  static const String eventCreatorLinkOpened = 'creator_link_opened';
  static const String eventAppCtaClicked = 'app_cta_clicked';
  static const String eventSignupCompleted = 'signup_completed';
  static const String eventPurchaseCompleted = 'purchase_completed';

  static const String fieldEventId = 'event_id';
  static const String fieldOccurredAt = 'occurred_at';
  static const String fieldAnonymousId = 'anonymous_id';
  static const String fieldUserId = 'user_id';
  static const String fieldSessionId = 'session_id';
  static const String fieldGameId = 'game_id';
  static const String fieldGameName = 'game_name';
  static const String fieldPlatform = 'platform';
  static const String fieldSurface = 'surface';
  static const String fieldEntrySource = 'entry_source';
  static const String fieldCreatorId = 'creator_id';
  static const String fieldCampaignId = 'campaign_id';
  static const String fieldContentId = 'content_id';
  static const String fieldMediaSource = 'media_source';
  static const String fieldAppVersion = 'app_version';
  static const String fieldActionType = 'action_type';
  static const String fieldSource = 'source';
  static const String fieldCtaName = 'cta_name';
  static const String fieldSignupMethod = 'signup_method';
  static const String fieldProductId = 'product_id';
  static const String fieldPrice = 'price';
  static const String fieldCurrency = 'currency';

  static const Set<String> appFlyerAllowlist = {
    eventGameOpened,
    eventQualifiedPlay,
    eventCreatorLinkOpened,
    eventAppCtaClicked,
    eventSignupCompleted,
    eventPurchaseCompleted,
  };

  static const Set<String> disallowedParamKeys = {
    'email',
    'email_address',
    'comment',
    'comment_text',
    'chat_message',
    'message',
    'text',
    'token',
    'secret',
    'authorization',
    'access_token',
    'password',
  };

  final FirebaseAnalytics? _firebaseAnalytics;
  final AppsFlyerService? _appsFlyerService;
  final SharedPreferences? _sharedPreferences;
  final AnalyticsTransportLogger? _firebaseLogger;
  final AnalyticsTransportLogger? _appsFlyerLogger;

  final String _sessionId;
  String? _anonymousId;
  String? _userId;
  Future<void>? _initFuture;
  StreamSubscription<User?>? _authSubscription;

  /// Idempotent: concurrent callers all await the same in-flight
  /// initialization, so none proceeds with a null anonymous id.
  Future<void> initialize() {
    return _initFuture ??= _performInitialize();
  }

  Future<void> _performInitialize() async {
    try {
      final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
      _anonymousId = await _resolveAnonymousId(prefs);
      _userId = FirebaseAuth.instance.currentUser?.uid;
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().listen((user) {
        _userId = user?.uid;
      });
    } catch (_) {
      // Identity resolution is best-effort; failures must never block or
      // interrupt analytics/app flow.
    }
  }

  /// Cancels the auth-state subscription. The singleton normally lives for the
  /// whole process; this exists for explicit teardown and tests.
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  @visibleForTesting
  static Future<void> resetForTests() async {
    await _instance?.dispose();
    _instance = null;
  }

  Future<String> getAnonymousId() async {
    await initialize();
    return _anonymousId ?? '';
  }

  Future<void> setAuthenticatedUser(String? userId) async {
    await initialize();
    _userId = userId;
  }

  Future<AnalyticsIdentityContext> resolveIdentity() async {
    await initialize();
    return AnalyticsIdentityContext(
      anonymousId: _anonymousId ?? '',
      userId: _userId,
      isAuthenticated: (_userId ?? '').isNotEmpty,
    );
  }

  Future<void> trackProductEvent(
    String eventName, {
    Map<String, Object?>? parameters,
    String? surface,
    String? entrySource,
    String? gameId,
    String? gameName,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
    String? eventId,
    DateTime? occurredAt,
  }) async {
    await initialize();
    try {
      final payload = await buildEventPayload(
        eventName,
        parameters: parameters,
        surface: surface,
        entrySource: entrySource,
        gameId: gameId,
        gameName: gameName,
        creatorId: creatorId,
        campaignId: campaignId,
        contentId: contentId,
        mediaSource: mediaSource,
        sessionId: sessionId,
        userId: userId,
        eventId: eventId,
        occurredAt: occurredAt,
      );
      await _routeToFirebase(eventName, payload);
      if (shouldRouteToAppsFlyer(eventName)) {
        await _routeToAppsFlyer(eventName, payload);
      }
    } catch (_) {
      // Analytics failures must never interrupt app flows.
    }
  }

  Future<void> trackEvent(
    String eventName, {
    Map<String, Object?>? parameters,
    String? surface,
    String? entrySource,
    String? gameId,
    String? gameName,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
    String? eventId,
    DateTime? occurredAt,
  }) async {
    await trackProductEvent(
      eventName,
      parameters: parameters,
      surface: surface,
      entrySource: entrySource,
      gameId: gameId,
      gameName: gameName,
      creatorId: creatorId,
      campaignId: campaignId,
      contentId: contentId,
      mediaSource: mediaSource,
      sessionId: sessionId,
      userId: userId,
      eventId: eventId,
      occurredAt: occurredAt,
    );
  }

  Future<Map<String, Object?>> buildEventPayload(
    String eventName, {
    Map<String, Object?>? parameters,
    String? surface,
    String? entrySource,
    String? gameId,
    String? gameName,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
    String? eventId,
    DateTime? occurredAt,
  }) async {
    final identity = await resolveIdentity();
    final packageInfo = await _getPackageInfo();
    final payload = <String, Object?>{
      fieldEventId: eventId ?? _generateUuidV4(),
      fieldOccurredAt: (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
      fieldAnonymousId: identity.anonymousId,
      if ((userId ?? _userId ?? '').isNotEmpty) fieldUserId: userId ?? _userId,
      if ((sessionId ?? _sessionId).isNotEmpty)
        fieldSessionId: sessionId ?? _sessionId,
      if ((gameId ?? '').isNotEmpty) fieldGameId: gameId,
      if ((gameName ?? '').isNotEmpty) fieldGameName: gameName,
      fieldPlatform: Platform.isIOS ? 'ios' : 'android',
      fieldSurface: surface ?? 'app',
      fieldEntrySource: entrySource ?? 'unknown',
      if ((creatorId ?? '').isNotEmpty) fieldCreatorId: creatorId,
      if ((campaignId ?? '').isNotEmpty) fieldCampaignId: campaignId,
      if ((contentId ?? '').isNotEmpty) fieldContentId: contentId,
      if ((mediaSource ?? '').isNotEmpty) fieldMediaSource: mediaSource,
      fieldAppVersion: packageInfo?.version ?? 'unknown',
    };

    if (parameters != null) {
      for (final entry in parameters.entries) {
        final cleaned = _sanitizeParameterValue(entry.key, entry.value);
        if (cleaned != null) {
          payload[entry.key] = cleaned;
        }
      }
    }

    return _filterNullValues(payload);
  }

  bool shouldRouteToAppsFlyer(String eventName) {
    return appFlyerAllowlist.contains(eventName);
  }

  Future<void> logGameViewed({
    String? gameId,
    String? gameName,
    String? surface,
    String? entrySource,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
  }) async {
    await trackProductEvent(
      eventGameViewed,
      parameters: const {},
      surface: surface,
      entrySource: entrySource,
      gameId: gameId,
      gameName: gameName,
      creatorId: creatorId,
      campaignId: campaignId,
      contentId: contentId,
      mediaSource: mediaSource,
      sessionId: sessionId,
      userId: userId,
    );
  }

  Future<void> logGameOpened({
    String? gameId,
    String? gameName,
    String? surface,
    String? entrySource,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
  }) async {
    await trackProductEvent(
      eventGameOpened,
      parameters: const {},
      surface: surface,
      entrySource: entrySource,
      gameId: gameId,
      gameName: gameName,
      creatorId: creatorId,
      campaignId: campaignId,
      contentId: contentId,
      mediaSource: mediaSource,
      sessionId: sessionId,
      userId: userId,
    );
  }

  Future<void> logGameLoaded({
    String? gameId,
    String? gameName,
    String? surface,
    String? entrySource,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
  }) async {
    await trackProductEvent(
      eventGameLoaded,
      parameters: const {},
      surface: surface,
      entrySource: entrySource,
      gameId: gameId,
      gameName: gameName,
      creatorId: creatorId,
      campaignId: campaignId,
      contentId: contentId,
      mediaSource: mediaSource,
      sessionId: sessionId,
      userId: userId,
    );
  }

  Future<void> logQualifiedPlay({
    String? gameId,
    String? gameName,
    String? surface,
    String? entrySource,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
  }) async {
    await trackProductEvent(
      eventQualifiedPlay,
      parameters: const {},
      surface: surface,
      entrySource: entrySource,
      gameId: gameId,
      gameName: gameName,
      creatorId: creatorId,
      campaignId: campaignId,
      contentId: contentId,
      mediaSource: mediaSource,
      sessionId: sessionId,
      userId: userId,
    );
  }

  Future<void> logGameEnded({
    String? gameId,
    String? gameName,
    String? surface,
    String? entrySource,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
  }) async {
    await trackProductEvent(
      eventGameEnded,
      parameters: const {},
      surface: surface,
      entrySource: entrySource,
      gameId: gameId,
      gameName: gameName,
      creatorId: creatorId,
      campaignId: campaignId,
      contentId: contentId,
      mediaSource: mediaSource,
      sessionId: sessionId,
      userId: userId,
    );
  }

  Future<void> logScoreSubmitted({
    String? gameId,
    String? gameName,
    String? surface,
    String? entrySource,
    String? creatorId,
    String? campaignId,
    String? contentId,
    String? mediaSource,
    String? sessionId,
    String? userId,
  }) async {
    await trackProductEvent(
      eventScoreSubmitted,
      parameters: const {},
      surface: surface,
      entrySource: entrySource,
      gameId: gameId,
      gameName: gameName,
      creatorId: creatorId,
      campaignId: campaignId,
      contentId: contentId,
      mediaSource: mediaSource,
      sessionId: sessionId,
      userId: userId,
    );
  }

  Future<void> logSocialAction({
    required String actionType,
    String? gameId,
    String? creatorId,
    String? sessionId,
  }) async {
    await trackProductEvent(
      eventSocialAction,
      parameters: {fieldActionType: actionType},
      gameId: gameId,
      creatorId: creatorId,
      sessionId: sessionId,
    );
  }

  Future<void> logCreatorLinkOpened({
    required String creatorId,
    required String source,
    String? gameId,
    String? sessionId,
  }) async {
    await trackProductEvent(
      eventCreatorLinkOpened,
      parameters: {fieldSource: source},
      gameId: gameId,
      creatorId: creatorId,
      sessionId: sessionId,
    );
  }

  Future<void> logAppCtaClicked({
    required String ctaName,
    String? gameId,
    String? sessionId,
  }) async {
    await trackProductEvent(
      eventAppCtaClicked,
      parameters: {fieldCtaName: ctaName},
      gameId: gameId,
      sessionId: sessionId,
    );
  }

  Future<void> logSignupCompleted({
    required String signupMethod,
  }) async {
    await trackProductEvent(
      eventSignupCompleted,
      parameters: {fieldSignupMethod: signupMethod},
    );
  }

  Future<void> logPurchaseCompleted({
    required String productId,
    required num price,
    required String currency,
    String? gameId,
    String? sessionId,
  }) async {
    await trackProductEvent(
      eventPurchaseCompleted,
      parameters: {
        fieldProductId: productId,
        fieldPrice: price,
        fieldCurrency: currency,
      },
      gameId: gameId,
      sessionId: sessionId,
    );
  }

  Future<void> _routeToFirebase(
      String eventName, Map<String, Object?> parameters) async {
    try {
      final firebaseParameters = <String, Object>{};
      for (final entry in parameters.entries) {
        if (entry.value != null && _isSupportedFirebaseValue(entry.value)) {
          firebaseParameters[entry.key] = entry.value as Object;
        }
      }

      if (_firebaseLogger != null) {
        await _firebaseLogger!(eventName, firebaseParameters);
        return;
      }
      if (_firebaseAnalytics == null) {
        return;
      }
      await _firebaseAnalytics!.logEvent(
        name: eventName,
        parameters: firebaseParameters,
      );
    } catch (_) {}
  }

  Future<void> _routeToAppsFlyer(
      String eventName, Map<String, Object?> parameters) async {
    try {
      if (_appsFlyerLogger != null) {
        await _appsFlyerLogger!(eventName, parameters);
        return;
      }
      await _appsFlyerService?.logEvent(eventName, parameters);
    } catch (_) {}
  }

  Future<PackageInfo?> _getPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveAnonymousId(SharedPreferences? prefs) async {
    final selectedPrefs = prefs ?? await SharedPreferences.getInstance();
    final existing = selectedPrefs.getString(anonymousIdPrefsKey) ??
        selectedPrefs.getString(legacyGuestIdPrefsKey);
    if ((existing ?? '').isNotEmpty) {
      await selectedPrefs.setString(anonymousIdPrefsKey, existing!);
      return existing;
    }

    final generated = _generateUuidV4();
    await selectedPrefs.setString(anonymousIdPrefsKey, generated);
    await selectedPrefs.setString(legacyGuestIdPrefsKey, generated);
    return generated;
  }

  Map<String, Object?> _filterNullValues(Map<String, Object?> payload) {
    return payload.entries
        .where((entry) => entry.value != null)
        .fold<Map<String, Object?>>(
      <String, Object?>{},
      (map, entry) => map..putIfAbsent(entry.key, () => entry.value!),
    );
  }

  Object? _sanitizeParameterValue(String key, Object? value) {
    if (value == null) {
      return null;
    }

    if (disallowedParamKeys.contains(key.toLowerCase())) {
      return null;
    }

    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return null;
      }
      if (key.toLowerCase().contains('email')) {
        return null;
      }
      return normalized;
    }

    if (value is num || value is bool) {
      return value;
    }

    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }

    return value.toString();
  }

  bool _isSupportedFirebaseValue(Object? value) {
    return value is String || value is num || value is bool;
  }

  static FirebaseAnalytics? _resolveFirebaseAnalytics() {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
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
