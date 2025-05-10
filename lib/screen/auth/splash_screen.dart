import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';

class SplashScreen extends StatefulWidget {
  final bool? loggedIn;
  const SplashScreen({super.key, this.loggedIn});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Check auth status and navigate accordingly after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      // Use the passed loggedIn value if provided, otherwise check auth state
      final bool isLoggedIn =
          widget.loggedIn ?? (FirebaseAuth.instance.currentUser != null);

      if (isLoggedIn) {
        // User is logged in, go to home
        context.go(Routes.home);
      } else {
        // User is not logged in, go to intro
        context.go(Routes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SvgPicture.asset(
          'assets/splash.svg',
          width: 255,
          height: 255,
        ),
      ),
    );
  }
}
