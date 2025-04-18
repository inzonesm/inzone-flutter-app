import 'package:flutter/material.dart';
import 'package:inzone/theme/dark_theme.dart';
import 'package:inzone/theme/light_theme.dart';

/// Theme management for the InZone app
///
/// Handles theme switching between light and dark modes
class ThemeManager with ChangeNotifier {
  // Initialize with light theme by default
  ThemeMode _themeMode = ThemeMode.system;

  // Getter for the current theme mode
  ThemeMode get themeMode => _themeMode;

  // Check if dark mode is active
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Check if system mode is active
  bool get isSystemMode => _themeMode == ThemeMode.system;

  // Provide the current theme based on the mode
  ThemeData get currentTheme =>
      _themeMode == ThemeMode.dark ? DarkTheme.theme : LightTheme.theme;

  ThemeData getLightTheme() => LightTheme.theme;

  ThemeData getDarkTheme() => DarkTheme.theme;

  // Toggle between light and dark themes
  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // Set a specific theme
  void setTheme(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }

  // Use system theme
  void useSystemTheme() {
    _themeMode = ThemeMode.system;
    notifyListeners();
  }
}
