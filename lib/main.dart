import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/config/default_firebase_options.dart';
import 'package:media_kit/media_kit.dart';
import 'package:inzone/theme/theme_manager.dart';
import 'package:provider/provider.dart';
import 'package:inzone/router/app_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/services/appsflyer_service.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/notification_service.dart';
import 'package:inzone/services/notification_event_service.dart';
import 'package:purchases_flutter/models/purchases_configuration.dart'
    show PurchasesConfiguration;
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart'
    show LogLevel, Purchases;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:inzone/services/reward_ad_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:inzone/services/ai_engagement_service.dart';
import 'package:inzone/services/active_character_notifier.dart';
import 'package:simula_ads/simula_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inzone/services/unity_bridge.dart';

// Key for storing first launch status in SharedPreferences
const String FIRST_LAUNCH_KEY = 'is_first_launch';
const String LAUNCH_COUNT_KEY = 'launch_count';

Future<int> _incrementLaunchCount(SharedPreferences prefs) async {
  final nextCount = (prefs.getInt(LAUNCH_COUNT_KEY) ?? 0) + 1;
  await prefs.setInt(LAUNCH_COUNT_KEY, nextCount);
  return nextCount;
}

/// Performance timing utility for measuring initialization times
class InitTimer {
  static final Stopwatch _totalTimer = Stopwatch();
  static final Map<String, int> _timings = {};

  static void startTotal() {
    _totalTimer.reset();
    _totalTimer.start();
    print('\n⏱️ ===== INITIALIZATION TIMING START =====');
  }

  static Future<T> measure<T>(
      String label, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();
      _timings[label] = stopwatch.elapsedMilliseconds;
      print('⏱️ [$label] ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      _timings[label] = stopwatch.elapsedMilliseconds;
      print('⏱️ [$label] ${stopwatch.elapsedMilliseconds}ms (FAILED: $e)');
      rethrow;
    }
  }

  static void measureSync(String label, void Function() operation) {
    final stopwatch = Stopwatch()..start();
    operation();
    stopwatch.stop();
    _timings[label] = stopwatch.elapsedMilliseconds;
    print('⏱️ [$label] ${stopwatch.elapsedMilliseconds}ms');
  }

  static void printSummary() {
    _totalTimer.stop();
    print('\n⏱️ ===== INITIALIZATION TIMING SUMMARY =====');

    // Sort by duration descending
    final sorted = _timings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sorted) {
      final bar = '█' * (entry.value ~/ 50).clamp(0, 40);
      print(
          '⏱️ ${entry.value.toString().padLeft(5)}ms | ${entry.key.padRight(30)} $bar');
    }

    print('⏱️ ─────────────────────────────────────────');
    print('⏱️ TOTAL: ${_totalTimer.elapsedMilliseconds}ms');
    print('⏱️ =========================================\n');
  }
}

/// Firebase Cloud Messaging background message handler
/// This must be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('📱 Background message received: ${message.notification?.title}');
  print('📱 Background message data: ${message.data}');

  // Handle the background message here if needed
  // Note: You cannot update UI from background handler
}

Future<void> setupRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;

  await remoteConfig.setDefaults({
    'required_version': '4.2.8',
  });

  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval: const Duration(hours: 12),
  ));

  try {
    // Fetch and activate
    await remoteConfig.fetchAndActivate();
    print('Remote Config fetched and activated successfully');

    print('Current Remote Config values:');
    print('  required_version: ${remoteConfig.getString('required_version')}');
    print('  Source: ${remoteConfig.getValue('required_version').source}');
  } catch (e) {
    print('Failed to fetch remote config: $e');
  }
}

Future<bool> checkForceUpdateRequired() async {
  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    final remoteConfig = FirebaseRemoteConfig.instance;
    String requiredVersion = remoteConfig.getString('required_version');

    print('Current app version: $currentVersion');
    print('Required version from Remote Config: $requiredVersion');

    if (!_isValidVersionString(currentVersion) ||
        !_isValidVersionString(requiredVersion)) {
      print('Invalid version format detected');
      return false;
    }

    bool updateRequired = _isUpdateRequired(currentVersion, requiredVersion);
    print('Update required: $updateRequired');

    return updateRequired;
  } catch (e) {
    print('Error checking for force update: $e');
    return false;
  }
}

bool _isValidVersionString(String version) {
  if (version.isEmpty) return false;
  final versionRegex = RegExp(r'^\d+\.\d+\.\d+(\+\d+)?$');
  return versionRegex.hasMatch(version);
}

bool _isUpdateRequired(String currentVersion, String requiredVersion) {
  List<int> current = _parseVersionString(currentVersion);
  List<int> required = _parseVersionString(requiredVersion);

  for (int i = 0; i < 3; i++) {
    if (current[i] < required[i]) {
      return true;
    } else if (current[i] > required[i]) {
      return false;
    }
  }
  return false;
}

List<int> _parseVersionString(String version) {
  String cleanVersion = version.split('+')[0];
  return cleanVersion.split('.').map((e) => int.parse(e)).toList();
}

Future<void> validateFirebaseSession() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    try {
      // Try a lightweight token read first so we do not force a re-auth.
      await user.getIdToken(false);
      print('User session validated: ${user.uid}');
      return;
    } on FirebaseAuthException catch (e) {
      print('Firebase auth exception while validating session: ${e.code}');

      const fatalSessionErrorCodes = {
        'user-disabled',
        'user-not-found',
        'invalid-user-token',
        'user-token-expired'
      };

      if (!fatalSessionErrorCodes.contains(e.code)) {
        print('Keeping existing session; validation failure appears transient.');
        return;
      }

      // Do not force sign-out here. Let the auth state listener and
      // Firebase persistence keep the user signed in unless auth fully fails.
      print('Session appears invalid (${e.code}); leaving current auth state intact for now.');
    } catch (e) {
      print('Non-auth error validating session: $e');
      print(
          'Keeping existing session; likely temporary network/startup issue.');
    }
  }
}

/// Try to restore a previously-signed-in Google user silently on cold start.
Future<void> tryRestoreAuth() async {
  if (FirebaseAuth.instance.currentUser != null) return;

  try {
    final googleSignIn = GoogleSignIn(
      scopes: ['email'],
      serverClientId:
          '912424781531-vru85aelna5oro0lrnkl11jd49oc74ss.apps.googleusercontent.com',
    );

    final account = await googleSignIn.signInSilently();
    if (account != null) {
      final gAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      print('✅ Restored Google sign-in silently');
    }
  } catch (e) {
    print('⚠️ Silent Google restore failed: $e');
  }
}

Future<void> initPlatformState() async {
  await Purchases.setLogLevel(LogLevel.debug);

  if (Platform.isAndroid) {
    if (FirebaseAuth.instance.currentUser != null) {
      await Purchases.configure(
          PurchasesConfiguration('goog_TMTKRzQNQBHDOwdGzYeRqHhbDPB')
            ..appUserID = FirebaseAuth.instance.currentUser!.uid);
    }
  } else if (Platform.isIOS) {
    if (FirebaseAuth.instance.currentUser != null) {
      await Purchases.configure(
          PurchasesConfiguration('appl_veaMcyjzStDagTGHzLYMJiDVkWO')
            ..appUserID = FirebaseAuth.instance.currentUser!.uid);
      print("CONFIGURED");
    }
  }
}

Future<void> requestTrackingPermission() async {
  if (Platform.isIOS) {
    final TrackingStatus status =
        await AppTrackingTransparency.requestTrackingAuthorization();

    // If authorized, fetch IDFA (else, fall back to SKAdNetwork or do nothing)
    if (status == TrackingStatus.authorized) {
      try {
        final String advertisingId =
            await AppTrackingTransparency.getAdvertisingIdentifier();
        // Now you have the IDFA in `advertisingId`
        print('IDFA = $advertisingId');
        // …send it to your server or to your ad SDK
      } catch (e) {
        // Failed to retrieve IDFA
        print('Error fetching IDFA: $e');
      }
    } else {
      // "denied" or "notDetermined" or "restricted"
      // Don't attempt to fetch IDFA; use SKAdNetwork or generic attribution instead.
      print('Tracking permission not granted (status = $status).');
    }
  }
}

void main() async {
  InitTimer.startTotal();

  InitTimer.measureSync('WidgetsBinding', () {
    WidgetsFlutterBinding.ensureInitialized();
  });

  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Start non-blocking initializations early
  InitTimer.measureSync('MobileAds.init (fire & forget)', () {
    MobileAds.instance.initialize();
  });

  InitTimer.measureSync('MediaKit.ensureInitialized', () {
    MediaKit.ensureInitialized();
  });

  // Initialize Unity bridge MethodChannel listener
  UnityBridge.instance.init();

  // Run SharedPreferences and Firebase init in parallel
  late SharedPreferences prefs;
  await InitTimer.measure('SharedPrefs + Firebase (parallel)', () async {
    final initFutures = await Future.wait([
      InitTimer.measure(
          '  └─ SharedPreferences', () => SharedPreferences.getInstance()),
      InitTimer.measure(
          '  └─ Firebase.initializeApp',
          () => Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform)),
    ]);
    prefs = initFutures[0] as SharedPreferences;
  });

  await InitTimer.measure('LaunchCount', () async {
    await _incrementLaunchCount(prefs);
  });

  // Register FCM background message handler (must be after Firebase init)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const bool needsUpdate = false;

  // Don't block first render on tracking/appsflyer initialization.
  Future(() async {
    await InitTimer.measure('Tracking + AppsFlyer (parallel)', () async {
      await Future.wait([
        InitTimer.measure('  └─ requestTrackingPermission',
            () => requestTrackingPermission()),
        InitTimer.measure('  └─ AppsFlyer.init', () async {
          final appsFlyerService = AppsFlyerService();
          await appsFlyerService.initialize();
          String? advertisingId = await appsFlyerService.getAdvertisingId();
          print("The advertising ID is $advertisingId");
        }),
      ]);
    });
  });

  // Initialize RevenueCat in background (depends on Firebase Auth being ready).
  Future(() async {
    await InitTimer.measure(
        'initPlatformState (RevenueCat)', () => initPlatformState());
  });

  // Print timing summary before UI starts
  InitTimer.printSummary();

  // These don't need to block app startup - run async
  FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true).then((_) {
    print("✅ Firebase Analytics initialized for ad revenue tracking");
  });

  // Warm up Cloud Run container (already async)
  InZoneDatabase.warmUpCloudRun();

  // Defer AI engagement service - initialize after app is running
  Future.delayed(const Duration(seconds: 1), () async {
    try {
      await AIEngagementService.initialize();
      print("✅ AI Engagement Service initialized successfully");
    } catch (e) {
      print("⚠️ AI Engagement Service initialization failed: $e");
    }
  });

  // // TESTING: Uncomment the line below to test all analytics
  // await appsFlyerService.testAllAnalytics();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeManager()),
          ChangeNotifierProvider(create: (_) => ActiveCharacterNotifier()),
        ],
        child: MyApp(prefs: prefs, needsUpdate: needsUpdate),
      ),
    );
  });

  // Run startup work in background after first frame can render.
  Future(() async {
    await InitTimer.measure('Notifications + RemoteConfig + Session (bg)',
        () async {
      await Future.wait([
        InitTimer.measure('  └─ NotificationService.init', () async {
          try {
            await NotificationService.initialize().timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                print(
                    '⚠️ NotificationService.init timed out after 8s; continuing startup');
              },
            );
            print('✅ Notification service initialized');
          } catch (e) {
            print('⚠️ Failed to initialize notification service: $e');
          }
        }),
        InitTimer.measure('  └─ NotificationEventService.init', () async {
          try {
            await NotificationEventService.initializePushNotifications()
                .timeout(const Duration(seconds: 8), onTimeout: () {
              print(
                  '⚠️ NotificationEventService.init timed out after 8s; continuing startup');
            });
            print('✅ Push notifications initialized');
          } catch (e) {
            print('⚠️ Failed to initialize push notifications: $e');
          }
        }),
        InitTimer.measure('  └─ setupRemoteConfig', () => setupRemoteConfig()),
        InitTimer.measure(
            '  └─ validateFirebaseSession', () => validateFirebaseSession()),
      ]);
    });

    final shouldForceUpdate = await InitTimer.measure(
        'checkForceUpdateRequired (bg)', () => checkForceUpdateRequired());
    if (shouldForceUpdate) {
      Future.delayed(const Duration(milliseconds: 300), () {
        AppRouter.setInitialRoute(Routes.forceUpdate);
      });
    }
  });
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;
  final bool needsUpdate;

  const MyApp({super.key, required this.prefs, required this.needsUpdate});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _launchCountSynced = false;

  Future<void> _syncLaunchCountToFirestore() async {
    if (_launchCountSynced) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final launchCount = widget.prefs.getInt(LAUNCH_COUNT_KEY);
    if (launchCount == null) return;

    _launchCountSynced = true;

    try {
      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(user.uid)
          .set({
        'launch_count': launchCount,
      }, SetOptions(merge: true));
    } catch (e) {
      _launchCountSynced = false;
      print('Failed to sync launch_count: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Set up auth state change listener for pending notifications
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && mounted) {
        // User just signed in, set influencer_id user property
        _setInfluencerIdProperty(user.uid);

        // // Ensure FCM token registration runs after auth is available.
        // Future.delayed(const Duration(seconds: 1), () async {
        //   try {
        //     await NotificationEventService.reRegisterFCMToken();
        //     print('✅ FCM token re-registered after login');
        //   } catch (e) {
        //     print('⚠️ Failed to re-register FCM token after login: $e');
        //   }
        // });

        // Handle any pending push notification
        Future.delayed(const Duration(milliseconds: 500), () async {
          await NotificationEventService.handlePendingInitialMessage();
        });

        _syncLaunchCountToFirestore();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();

      _resolveInitialRoute();
    });
  }

  Future<void> _resolveInitialRoute() async {
    // If update is required, show force update screen first.
    if (widget.needsUpdate) {
      print('Force update required - showing update screen');
      AppRouter.setInitialRoute(Routes.forceUpdate);
      return;
    }

    final isFirstLaunch = widget.prefs.getBool(FIRST_LAUNCH_KEY) ?? true;

    // Try to restore provider sign-ins (Google) silently before resolving auth.
    await tryRestoreAuth();

    // Wait for Firebase Auth to settle before deciding where to send the user.
    final currentUser = await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;

    if (currentUser != null) {
      print('User is logged in - going to home');
      AppRouter.setInitialRoute(Routes.home);

      _initializeRewardAds();
      _startAIEngagementService();

      Future.delayed(const Duration(milliseconds: 1000), () async {
        await NotificationEventService.handlePendingInitialMessage();
      });

      _syncLaunchCountToFirestore();
    } else {
      print('User is not logged in - showing onboarding');
      AppRouter.setInitialRoute(Routes.onboarding);
    }

    if (isFirstLaunch) {
      await widget.prefs.setBool(FIRST_LAUNCH_KEY, false);
    }
  }

  /// Start AI engagement service for background operations
  void _startAIEngagementService() {
    try {
      AIEngagementService.start();
      print("🤖 AI engagement background service started");
    } catch (e) {
      print("⚠️ Failed to start AI engagement service: $e");
      // Don't crash the app if AI service fails to start
    }
  }

  /// Initialize reward ad service (load first ad in background)
  void _initializeRewardAds() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final rewardAdService = RewardAdService();
        await rewardAdService.initialize();
        print("✅ Reward ad service initialized");
      } catch (e) {
        print("⚠️ Failed to initialize reward ads: $e");
        // Don't crash if ad loading fails
      }
    });
  }

  /// Set influencer_id user property for ad revenue attribution
  Future<void> _setInfluencerIdProperty(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final referrerId = userData?['referred_by'] as String?;

        if (referrerId != null && referrerId.isNotEmpty) {
          await FirebaseAnalytics.instance.setUserProperty(
            name: 'influencer_id',
            value: referrerId,
          );
          print("✅ Set influencer_id user property: $referrerId");
        }
      }
    } catch (e) {
      print("⚠️ Failed to set influencer_id: $e");
      // Don't crash if this fails
    }
  }

  @override
  void dispose() {
    AIEngagementService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the ThemeManager from the Provider
    final themeManager = Provider.of<ThemeManager>(context);

    return SimulaProvider(
      apiKey: 'pub_6d4e9b1c8a3f5e2d7c0b41a9f6e38d2c',
      primaryUserID: FirebaseAuth.instance.currentUser?.uid ?? '',
      hasPrivacyConsent: true,
      devMode: false,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Inzone',
        theme: themeManager.getLightTheme(),
        darkTheme: themeManager.getDarkTheme(),
        themeMode: themeManager.themeMode,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
