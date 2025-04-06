import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Lottie.asset(
          'assets/animations/animation_intro.json', // Path to your Lottie animation
          width: 200,                      // You can adjust the size as needed
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
