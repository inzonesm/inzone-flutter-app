import 'package:flutter/material.dart';
import 'package:inzone/screen/auth/introduction_screen.dart';
import 'package:inzone/root_app.dart';

class SplashScreen extends StatefulWidget {
  final bool? loggedIn;
  const SplashScreen({super.key, required this.loggedIn});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => widget.loggedIn == null
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : widget.loggedIn!
                  ? const RootApp()
                  : const IntroductionScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 150,
          height: 150,
        ),
      ),
    );
  }
}
