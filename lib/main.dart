import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inzone/config/default_firebase_options.dart';
import 'package:inzone/root_app.dart';
import 'package:inzone/screen/auth/introduction_screen.dart';
import 'package:inzone/screen/auth/splash_screen.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

AppsFlyerOptions appsFlyerOptions = AppsFlyerOptions(
  afDevKey: "GouQRMcXkXP2CMBgZfHdfB",
  appId: "6478089068",
  showDebug: false, // timeToWaitForATTUserAuthorization: 50, // for iOS 14.5
  // appInviteOneLink: oneLinkID, // Optional field
  // disableAdvertisingIdentifier: false, // Optional field
  // disableCollectASA: false, //Optional field
  // manualStart: true,
); // Optional field

AppsflyerSdk appsflyerSdk = AppsflyerSdk(appsFlyerOptions);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await appsflyerSdk.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true);

  String? advertisingId = await appsflyerSdk.getAppsFlyerUID();
  print("The advertising ID is $advertisingId");

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        canvasColor: const Color(0xffdaf5ff),
        scaffoldBackgroundColor: const Color(0xffdaf5ff),
        primaryColor: Colors.blue,
        textTheme: TextTheme(
            titleLarge:
                GoogleFonts.afacad(fontSize: 25, fontWeight: FontWeight.bold),
            titleMedium:
                GoogleFonts.afacad(fontSize: 22, fontWeight: FontWeight.bold),
            bodyMedium: GoogleFonts.afacad(fontSize: 18),
            bodySmall: GoogleFonts.afacad(fontSize: 16)),
        colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            onPrimary: Colors.black,
            secondary: Colors.white,
            onSecondary: Colors.black),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xffdaf5ff),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            // backgroundColor: MaterialStateProperty.all(Colors.blue), // Default icon button color
            foregroundColor:
                WidgetStateProperty.all(Colors.white), // Icon color
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash screen while checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(loggedIn: null);
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return const SplashScreen(loggedIn: true);
        }
        
        // User is not logged in
        return const SplashScreen(loggedIn: false);
      },
    );
  }
}
