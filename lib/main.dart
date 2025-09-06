import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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
import 'package:inzone/router/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:inzone/services/reward_ad_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:inzone/services/ai_engagement_service.dart';

// Key for storing first launch status in SharedPreferences
const String FIRST_LAUNCH_KEY = 'is_first_launch';

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
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: Duration.zero,
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
      // Try to reload the user to make sure their token is still valid
      await user.reload();
      print('User session validated: ${user.uid}');

      // Try to refresh the ID token in case it's about to expire
      await user.getIdToken(true);
      return;
    } catch (e) {
      print('Error validating user session: $e');
      // Token is invalid, sign the user out
      try {
        await FirebaseAuth.instance.signOut();
        print('User signed out due to invalid session');
      } catch (signOutError) {
        print('Error signing out: $signOutError');
      }
    }
  }
}

Future<void> initPlatformState() async {
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration configuration;
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
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize AdMob with test device configuration
  MobileAds.instance.initialize();

  // Initialize reward ad service
  final rewardAdService = RewardAdService();
  await rewardAdService.initialize();

  // Initialize SharedPreferences
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // prefs.clear();

  MediaKit.ensureInitialized();

  // Firebase initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register FCM background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notification service
  try {
    await NotificationService.initialize();
    print('✅ Notification service initialized');
  } catch (e) {
    print('⚠️ Failed to initialize notification service: $e');
  }

  // Initialize push notifications for event service
  try {
    await NotificationEventService.initializePushNotifications();
    print('✅ Push notifications initialized');
  } catch (e) {
    print('⚠️ Failed to initialize push notifications: $e');
  }

  // Setup Firebase Remote Config
  await setupRemoteConfig();

  // Check for force update BEFORE initializing the app
  bool needsUpdate = await checkForceUpdateRequired();

  // Firebase auth check
  await validateFirebaseSession();

  // Request tracking permission and get IDFA if authorized
  await requestTrackingPermission();

  // Initialize AppsFlyerService
  final appsFlyerService = AppsFlyerService();
  await appsFlyerService.initialize();
  await initPlatformState();
  String? advertisingId = await appsFlyerService.getAdvertisingId();
  print("The advertising ID is $advertisingId");

  // Warm up Cloud Run container to improve app performance
  // This runs asynchronously and doesn't block app startup
  InZoneDatabase.warmUpCloudRun();

  // Initialize AI engagement service for background operations
  try {
    await AIEngagementService.initialize();
    print("✅ AI Engagement Service initialized successfully");
  } catch (e) {
    print("⚠️ AI Engagement Service initialization failed: $e");
    // Don't block app startup if AI service fails
  }

  // // TESTING: Uncomment the line below to test all analytics
  // await appsFlyerService.testAllAnalytics();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeManager(),
        child: MyApp(prefs: prefs, needsUpdate: needsUpdate),
      ),
    );
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
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();

      // If update is required, show force update screen
      if (widget.needsUpdate) {
        print("Force update required - showing update screen");
        AppRouter.setInitialRoute(Routes.forceUpdate);
        return;
      }

      // Check if this is the first launch
      bool isFirstLaunch = widget.prefs.getBool(FIRST_LAUNCH_KEY) ?? true;

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;

      // Determine initial route based on login status
      if (currentUser != null) {
        // User is logged in - go to home
        print("User is logged in - going to home");
        AppRouter.setInitialRoute(Routes.home);

        // Start AI engagement service for logged-in users
        _startAIEngagementService();

        // Update first launch status if it was the first launch
        if (isFirstLaunch) {
          widget.prefs.setBool(FIRST_LAUNCH_KEY, false);
        }
      } else {
        // User is not logged in - always show onboarding
        print("User is not logged in - showing onboarding");
        AppRouter.setInitialRoute(Routes.onboarding);

        // Update first launch status if it was the first launch
        if (isFirstLaunch) {
          widget.prefs.setBool(FIRST_LAUNCH_KEY, false);
        }
      }
    });
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

  @override
  void dispose() {
    AIEngagementService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the ThemeManager from the Provider
    final themeManager = Provider.of<ThemeManager>(context);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Inzone',
      theme: themeManager.getLightTheme(),
      darkTheme: themeManager.getDarkTheme(),
      themeMode: themeManager.themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
