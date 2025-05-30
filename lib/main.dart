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
import 'package:google_fonts/google_fonts.dart';
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

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize AdMob with test device configuration
  MobileAds.instance.initialize();

  // SharedPreferences prefs = await SharedPreferences.getInstance();

  // prefs.clear();

  MediaKit.ensureInitialized();

  // Initialize Google Fonts
  GoogleFonts.config.allowRuntimeFetching = true;

  // Firebase initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firebase auth check
  await validateFirebaseSession();

  // Initialize AppsFlyerService
  final appsFlyerService = AppsFlyerService();
  await appsFlyerService.initialize();
  await initPlatformState();
  String? advertisingId = await appsFlyerService.getAdvertisingId();
  print("The advertising ID is $advertisingId");

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeManager(),
        child: const MyApp(),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 앱이 로드되면 네이티브 스플래시를 제거하고 적절한 초기 경로로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 네이티브 스플래시 제거
      FlutterNativeSplash.remove();

      // 인증 상태에 따라 적절한 초기 경로로 이동
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // 로그인되어 있는 경우 홈 화면으로 이동
        AppRouter.setInitialRoute(Routes.home);
      } else {
        // 로그인되어 있지 않은 경우 로그인 화면으로 이동
        AppRouter.setInitialRoute(Routes.login);
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
