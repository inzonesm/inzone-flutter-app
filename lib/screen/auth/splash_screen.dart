import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inzone/screen/auth/introduction_screen.dart';
import 'package:inzone/root_app.dart';

class SplashScreen extends StatelessWidget {
  bool loggedIn;
  SplashScreen({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      duration: 2000,
      splash: Column(
        children: [
          //TODO Change this
          Text("InZone",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 35, height: 1.2)),
        ],
      ),
      backgroundColor: Theme.of(context).canvasColor,
      nextScreen: loggedIn ? const RootApp() : const IntroductionScreen(),
    );
  }
}
