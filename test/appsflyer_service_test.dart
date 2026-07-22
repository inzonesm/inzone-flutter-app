import 'dart:async';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeAppsFlyerSdkClient implements AppsFlyerSdkClient {
  int initCalls = 0;
  int logEventCalls = 0;
  int onAppOpenAttributionRegistrations = 0;
  int onInstallConversionDataRegistrations = 0;
  int onDeepLinkingRegistrations = 0;
  bool failInit = false;
  bool failLogEvent = false;
  Completer<void>? initCompleter;
  final List<String> loggedEvents = <String>[];

  @override
  Future<void> initSdk({
    required bool registerConversionDataCallback,
    required bool registerOnAppOpenAttributionCallback,
    required bool registerOnDeepLinkingCallback,
  }) async {
    initCalls += 1;
    if (failInit) {
      throw StateError('init failed');
    }
    if (initCompleter != null) {
      await initCompleter!.future;
    }
  }

  @override
  void onAppOpenAttribution(void Function(dynamic data) callback) {
    onAppOpenAttributionRegistrations += 1;
  }

  @override
  void onInstallConversionData(void Function(dynamic data) callback) {
    onInstallConversionDataRegistrations += 1;
  }

  @override
  void onDeepLinking(void Function(DeepLinkResult deepLinkResult) callback) {
    onDeepLinkingRegistrations += 1;
  }

  @override
  void setCustomerUserId(String userId) {}

  @override
  Future<bool?> logEvent(
      String eventName, Map<String, dynamic>? eventValues) async {
    logEventCalls += 1;
    loggedEvents.add(eventName);
    if (failLogEvent) {
      throw StateError('log failed');
    }
    return true;
  }

  @override
  Future<String?> getAppsFlyerUID() async {
    return 'fake-id';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppsFlyerService service;
  late _FakeAppsFlyerSdkClient fakeClient;
  int authProviderCalls = 0;

  setUp(() async {
    service = AppsFlyerService();
    fakeClient = _FakeAppsFlyerSdkClient();
    authProviderCalls = 0;

    await service.resetForTests();
    service.configureForTests(
      sdkClient: fakeClient,
      currentUserProvider: () => null,
      authStateChangesProvider: () {
        authProviderCalls += 1;
        return const Stream.empty();
      },
      packageInfoProvider: () async => PackageInfo(
        appName: 'InZone',
        packageName: 'com.aadeshkheria.inzone',
        version: '5.0.6',
        buildNumber: '725',
        buildSignature: 'test',
      ),
    );
  });

  test('initialize runs once and deduplicates listener registration', () async {
    await Future.wait(<Future<void>>[
      service.initialize(),
      service.initialize(),
      service.initialize(),
    ]);

    expect(fakeClient.initCalls, 1);
    expect(authProviderCalls, 1);
    expect(fakeClient.onAppOpenAttributionRegistrations, 1);
    expect(fakeClient.onInstallConversionDataRegistrations, 1);
    expect(fakeClient.onDeepLinkingRegistrations, 1);
  });

  test('logEvent waits for initialization to finish', () async {
    final completer = Completer<void>();
    fakeClient.initCompleter = completer;

    final pending = service.logEvent('test_event', <String, dynamic>{'a': 1});
    await Future<void>.delayed(Duration.zero);

    expect(fakeClient.initCalls, 1);
    expect(fakeClient.logEventCalls, 0);

    completer.complete();
    final result = await pending;

    expect(result, true);
    expect(fakeClient.logEventCalls, 1);
  });

  test('initialization failure does not crash event callers', () async {
    fakeClient.failInit = true;

    final result = await service.logEvent('test_event', <String, dynamic>{});

    expect(result, isNull);
    expect(fakeClient.logEventCalls, 0);
  });

  test('smoke event is gated and sent once', () async {
    await service.runDebugSmokeTestIfEnabled(flagEnabled: false);
    expect(fakeClient.loggedEvents, isEmpty);

    await service.runDebugSmokeTestIfEnabled(flagEnabled: true);
    await service.runDebugSmokeTestIfEnabled(flagEnabled: true);

    expect(
      fakeClient.loggedEvents.where((e) => e == 'af_sdk_smoke_test').length,
      1,
    );
  });
}
