import 'package:flutter/material.dart' hide ThemeMode;
import '../models/types.dart';

/// Theme utilities for styling ads
class ThemeUtils {
  /// Get color scheme based on theme mode
  static ColorScheme getColorScheme(SimulaThemeMode mode, BuildContext context) {
    switch (mode) {
      case SimulaThemeMode.light:
        return const ColorScheme.light();
      case SimulaThemeMode.dark:
        return const ColorScheme.dark();
      case SimulaThemeMode.auto:
        return Theme.of(context).colorScheme;
    }
  }

  /// Get font family based on FontOption
  static String getFontFamily(FontOption? font) {
    switch (font) {
      case FontOption.sansSerif:
        return 'sans-serif';
      case FontOption.serif:
        return 'serif';
      case FontOption.monospace:
        return 'monospace';
      case null:
        return 'sans-serif';
    }
  }

  /// Get corner radius
  static double getCornerRadius(double? cornerRadius) {
    return cornerRadius ?? 8.0;
  }

  /// Get width value (with minimum of 320)
  static double? getWidth(double? width, double? measuredWidth) {
    if (width == null) return null;
    const minWidth = 320.0;
    final finalWidth = width < minWidth ? minWidth : width;
    return finalWidth;
  }

  /// Get accent color based on AccentOption
  static Color? getAccentColor(AccentOption? accent) {
    if (accent == null) return null;
    
    switch (accent) {
      case AccentOption.blue:
        return Colors.blue;
      case AccentOption.red:
        return Colors.red;
      case AccentOption.green:
        return Colors.green;
      case AccentOption.yellow:
        return Colors.yellow;
      case AccentOption.purple:
        return Colors.purple;
      case AccentOption.pink:
        return Colors.pink;
      case AccentOption.orange:
        return Colors.orange;
      case AccentOption.neutral:
        return Colors.grey;
      case AccentOption.gray:
        return Colors.grey;
      case AccentOption.tan:
        return const Color(0xFFD2B48C);
      case AccentOption.transparent:
        return Colors.transparent;
      case AccentOption.image:
        return null; // Image accent doesn't have a color
    }
  }
}
