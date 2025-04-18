import 'package:flutter/material.dart';
import 'package:inzone/theme/app_colors.dart';

/// Light theme for the InZone app
class LightTheme {
  static ThemeData get theme => ThemeData(
        // Base colors
        primaryColor: AppColors.primaryBlue,
        canvasColor: AppColors.lightBackground,
        scaffoldBackgroundColor: AppColors.lightBackground,

        // Color scheme
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primaryBlue,
          onPrimary: AppColors.white,
          secondary: AppColors.lightBlue,
          onSecondary: AppColors.black,
          error: AppColors.error,
          onError: AppColors.white,
          surface: AppColors.lightSurfaceColor,
          onSurface: AppColors.black,
        ),

        // App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightSurfaceColor,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.black),
          titleTextStyle: TextStyle(
              color: AppColors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),

        // Text themes
        textTheme: const TextTheme(
          headlineLarge:
              TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
          headlineMedium:
              TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
          headlineSmall:
              TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
          titleLarge:
              TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
          titleMedium:
              TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
          titleSmall:
              TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: AppColors.black),
          bodyMedium: TextStyle(color: AppColors.black),
          bodySmall: TextStyle(color: AppColors.grey),
          labelLarge: TextStyle(
              color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
          labelMedium: TextStyle(color: AppColors.primaryBlue),
          labelSmall: TextStyle(color: AppColors.grey),
        ),

        // Button themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),

        // Card theme
        cardTheme: CardTheme(
          color: AppColors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightGrey.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primaryBlue),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: AppColors.grey),
        ),

        // Divider theme
        dividerTheme: const DividerThemeData(
          color: AppColors.lightDividerColor,
          thickness: 1,
          space: 1,
        ),

        // Icon theme
        iconTheme: const IconThemeData(
          color: AppColors.black,
        ),

        // Floating action button theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
        ),
      );
}
