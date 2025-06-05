import 'package:flutter/material.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:inzone/theme/light_theme.dart'; // Import for ChatTheme extension

/// Dark theme for the InZone app
class DarkTheme {
  static ThemeData get theme => ThemeData(
        // Base colors
        primaryColor: AppColors.primaryBlue,
        canvasColor: AppColors.darkBackground,
        scaffoldBackgroundColor: AppColors.darkBackground,

        // Color scheme
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.primaryBlue,
          onPrimary: AppColors.white,
          secondary: AppColors.lightBlue,
          onSecondary: AppColors.white,
          error: AppColors.error,
          onError: AppColors.white,
          surface: AppColors.darkSurfaceColor,
          onSurface: AppColors.white,
        ),

        // App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurfaceColor,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.white),
          titleTextStyle: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Text themes - using system default font
        textTheme: const TextTheme(
          headlineLarge:
              TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
          headlineMedium:
              TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
          headlineSmall:
              TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
          titleLarge:
              TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
          titleMedium:
              TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          titleSmall:
              TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: AppColors.white),
          bodyMedium: TextStyle(color: AppColors.white),
          bodySmall: TextStyle(color: AppColors.grey),
          labelLarge: TextStyle(
              color: AppColors.lightBlue, fontWeight: FontWeight.bold),
          labelMedium: TextStyle(color: AppColors.lightBlue),
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
        cardTheme: CardThemeData(
          color: AppColors.darkSurfaceColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade800.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lightBlue),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),

        // Divider theme
        dividerTheme: const DividerThemeData(
          color: AppColors.darkDividerColor,
          thickness: 1,
          space: 1,
        ),

        // Icon theme
        iconTheme: const IconThemeData(
          color: AppColors.white,
        ),

        // Bottom navigation bar theme
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurfaceColor,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: Colors.grey,
        ),

        // Floating action button theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
        ),

        // Switch theme
        switchTheme: SwitchThemeData(
          thumbColor:
              WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue;
            }
            return Colors.grey.shade400;
          }),
          trackColor:
              WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue.withOpacity(0.5);
            }
            return Colors.grey.shade700;
          }),
        ),

        // Dialog theme
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.darkSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
        ),

        // Chat-specific theme extensions are provided via the ChatTheme extension
      );
}
