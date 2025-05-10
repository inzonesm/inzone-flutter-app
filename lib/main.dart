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

import 'package:purchases_flutter/purchases_flutter.dart'
    show LogLevel, Purchases;

Future<void> initPlatformState() async {
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration configuration;
  if (Platform.isAndroid) {
    if (FirebaseAuth.instance.currentUser != null) {
      await Purchases.configure(
          PurchasesConfiguration('appl_veaMcyjzStDagTGHzLYMJiDVkWO')
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
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Enable pending purchases on Android

  // Initialize Google Fonts
  GoogleFonts.config.allowRuntimeFetching = true;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
