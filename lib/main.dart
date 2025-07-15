import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:inzone/config/default_firebase_options.dart';
import 'package:media_kit/media_kit.dart';
import 'package:inzone/theme/theme_manager.dart';
import 'package:provider/provider.dart';
import 'package:inzone/router/app_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:inzone/services/appsflyer_service.dart';
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

// Key for storing first launch status in SharedPreferences
const String FIRST_LAUNCH_KEY = 'is_first_launch';

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

  // // TESTING: Uncomment the line below to test all analytics
  // await appsFlyerService.testAllAnalytics();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeManager(),
        child: MyApp(prefs: prefs),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();

      // Check if this is the first launch
      bool isFirstLaunch = widget.prefs.getBool(FIRST_LAUNCH_KEY) ?? true;

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;

      // Determine initial route based on login status
      if (currentUser != null) {
        // User is logged in - go to home
        print("User is logged in - going to home");
        AppRouter.setInitialRoute(Routes.home);

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
