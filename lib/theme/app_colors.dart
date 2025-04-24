import 'package:flutter/material.dart';

/// App color constants used throughout the app
class AppColors {
  // Primary marketing colors - blue gradient
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color lightBlue = Color(0xFF14CFEE);
  static const Color marketingBlue = primaryBlue;

  // Common UI colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  static const Color lightGrey = Color(0xFFF0F0F0);
  static const Color mediumGrey = Color(0xFFA4ACB9);
  static const Color error = Colors.red;

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFE8F5FE);
  static const Color lightSurfaceColor = Colors.white;
  static const Color lightTextColor = Colors.black;
  static const Color lightDividerColor = Color(0xFFE0E0E0);

  // Dark Theme Colorsf
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkTextColor = Colors.white;
  static const Color darkDividerColor = Color(0xFF323232);

  // Chat Colors - Light Theme
  static const Color lightMyChatBubble =
      Color(0xFF2196F3); // Primary blue for my messages
  static const Color lightOtherChatBubble =
      Color(0xFFECECEC); // Light gray for other messages
  static const Color lightMyChatText =
      Colors.white; // White text on blue bubble
  static const Color lightOtherChatText =
      Colors.black; // Black text on light gray bubble

  // Chat Colors - Dark Theme
  static const Color darkMyChatBubble =
      Color(0xFF1976D2); // Darker blue for my messages
  static const Color darkOtherChatBubble =
      Color(0xFF2C2C2C); // Dark gray for other messages
  static const Color darkMyChatText = Colors.white; // White text on blue bubble
  static const Color darkOtherChatText =
      Colors.white; // White text on dark gray bubble

  // Marketing gradient colors
  static const List<Color> blueGradient = [lightBlue, primaryBlue];

  // Category Colors
  static const List<Color> categoryColors = [
    Color(0xffFF6B6B), // Light Red
    Color(0xff4ECDC4), // Turquoise
    Color(0xffFFD93D), // Yellow
    Color(0xffFF9F1C), // Orange
    Color(0xff2EC4B6), // Mint Green
    Color(0xff8338EC), // Purple
    Color(0xff06D6A0), // Bright Green
    Color(0xff3A86FF), // Sky Blue
    Color(0xff073B4C), // Dark Teal
  ];
}
