import 'package:flutter/material.dart';

/// Message type for conversation history
class Message {
  final String role;
  final String content;

  Message({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        role: json['role'] as String,
        content: json['content'] as String,
      );
}

/// Ad data returned from API
class AdData {
  final String id;
  final String format;
  final String? iframeUrl;
  final String? iframeHtml;  // HTML content fetched from iframe URL (for prefetching)
  final bool? adInserted;    // Whether an ad was inserted (from API response header)
  final String? adFormat;    // Ad format (from API response header)

  AdData({
    required this.id,
    required this.format,
    this.iframeUrl,
    this.iframeHtml,
    this.adInserted,
    this.adFormat,
  });

  factory AdData.fromJson(Map<String, dynamic> json) {
    // Parse adInserted - can be bool or string "true"/"false"
    bool? adInserted;
    final adInsertedValue = json['adInserted'];
    if (adInsertedValue != null) {
      if (adInsertedValue is bool) {
        adInserted = adInsertedValue;
      } else if (adInsertedValue is String) {
        adInserted = adInsertedValue.toLowerCase() == 'true';
      }
    }
    
    return AdData(
      id: json['id'] as String? ?? json['ad_id'] as String? ?? '',
      format: json['format'] as String? ?? 'iframe',
      iframeUrl: json['iframeUrl'] as String? ?? json['iframe_url'] as String?,
      iframeHtml: json['iframeHtml'] as String? ?? json['iframe_html'] as String?,
      adInserted: adInserted,
      adFormat: json['adFormat'] as String?,
    );
  }

  /// Create a copy with updated fields
  AdData copyWith({
    String? iframeHtml,
    bool? adInserted,
    String? adFormat,
  }) {
    return AdData(
      id: id,
      format: format,
      iframeUrl: iframeUrl,
      iframeHtml: iframeHtml ?? this.iframeHtml,
      adInserted: adInserted ?? this.adInserted,
      adFormat: adFormat ?? this.adFormat,
    );
  }
}

/// Accent color options
enum AccentOption {
  blue,
  red,
  green,
  yellow,
  purple,
  pink,
  orange,
  neutral,
  gray,
  tan,
  transparent,
  image,
}

/// Font options
enum FontOption {
  sansSerif,
  serif,
  monospace,
}

/// Theme configuration for ads
class InChatTheme {
  final SimulaThemeMode? mode;
  final AccentOption? accent;
  final List<AccentOption>? accentList; // For A/B testing
  final FontOption? font;
  final List<FontOption>? fontList; // For A/B testing
  final double? width;
  final double? cornerRadius;

  InChatTheme({
    this.mode,
    this.accent,
    this.accentList,
    this.font,
    this.fontList,
    this.width,
    this.cornerRadius,
  });

  Map<String, dynamic> toJson() {
    final accentValue = accentList != null
        ? accentList!.map((a) => a.name).toList()
        : (accent != null ? [accent!.name] : null);
    
    // Convert font enum names to match backend format (sansSerif -> sans-serif)
    final fontValue = fontList != null
        ? fontList!.map((f) => f.name == 'sansSerif' ? 'sans-serif' : f.name).toList()
        : (font != null ? [font!.name == 'sansSerif' ? 'sans-serif' : font!.name] : null);

    return {
      if (mode != null) 'mode': mode!.name,
      if (accentValue != null) 'accent': accentValue,
      if (fontValue != null) 'font': fontValue,
      // Convert width to int, skip if infinity or null
      // Use round() instead of toInt() to properly round to nearest integer instead of truncating
      if (width != null && width != double.infinity) 'width': width!.round(),
      // Convert cornerRadius to int
      if (cornerRadius != null) 'cornerRadius': cornerRadius!.round(),
    };
  }
}

enum SimulaThemeMode {
  light,
  dark,
  auto,
}

/// Contextual signals for ad relevance
class NativeContext {
  final String? searchTerm;
  final List<String>? tags;
  final String? category;
  final String? title;
  final String? description;
  final String? userProfile;
  final String? userEmail;
  final bool? nsfw;
  final Map<String, dynamic>? customContext;

  NativeContext({
    this.searchTerm,
    this.tags,
    this.category,
    this.title,
    this.description,
    this.userProfile,
    this.userEmail,
    this.nsfw,
    this.customContext,
  });

  Map<String, dynamic> toJson() {
    return {
      if (searchTerm != null) 'searchTerm': searchTerm,
      if (tags != null) 'tags': tags,
      if (category != null) 'category': category,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (userProfile != null) 'userProfile': userProfile,
      if (userEmail != null) 'userEmail': userEmail,
      if (nsfw != null) 'nsfw': nsfw,
      if (customContext != null) 'customContext': customContext,
    };
  }

  /// Create a copy of this context with PII filtered out if consent is not granted.
  /// When hasPrivacyConsent is false, removes userEmail and userProfile.
  NativeContext filterForPrivacy(bool hasPrivacyConsent) {
    if (hasPrivacyConsent) {
      return this; // No filtering needed
    }
    // Return a copy without userEmail and userProfile
    return NativeContext(
      searchTerm: searchTerm,
      tags: tags,
      category: category,
      title: title,
      description: description,
      // userProfile and userEmail are intentionally omitted
      nsfw: nsfw,
      customContext: customContext,
    );
  }
}

/// Game data returned from catalog API
class GameData {
  final String id;
  final String name;
  final String iconUrl;
  final String description;
  final String? iconFallback;

  GameData({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.description,
    this.iconFallback,
  });

  factory GameData.fromJson(Map<String, dynamic> json) => GameData(
        id: json['id'] as String,
        name: json['name'] as String,
        iconUrl: json['icon'] as String? ?? json['iconUrl'] as String? ?? '',
        description: json['description'] as String? ?? '',
        iconFallback: json['iconFallback'] as String?,
      );
}

/// Minigame completion payload used by host app callbacks.
///
/// `playedLikely` is a best-effort heuristic indicating whether the user
/// actually engaged with gameplay before closing.
class MiniGameCompletion {
  final GameData? game;
  final bool playedLikely;
  final String? gameOverText;

  MiniGameCompletion({
    required this.game,
    required this.playedLikely,
    this.gameOverText,
  });
}

/// Theme configuration for minigame menu
class MiniGameTheme {
  final Color? backgroundColor;
  final Color? headerColor;
  final Color? borderColor;
  final String? titleFont;
  final String? secondaryFont;
  final Color? titleFontColor;
  final Color? secondaryFontColor;
  final double? iconCornerRadius;
  /// Unified accent color for interactive elements.
  /// Used for search bar focus border and pagination dots.
  /// Default: '#3B82F6' (blue-500)
  final Color? accentColor;
  /// Controls the height of the Mini Game iframe (not the ad).
  /// Displayed as a bottom sheet with rounded corners at the top.
  /// - double <= 1.0: percentage of screen height (e.g., 0.8 = 80%, 1.0 = 100%)
  /// - double > 1.0: pixel value (e.g., 600.0 = 600px)
  /// - null: full screen (default behavior)
  /// Minimum height is 500px.
  final dynamic playableHeight; // double | null
  /// Controls the background color of the curved border area above the playable
  /// when playableHeight is not null (bottom sheet mode).
  /// This is the color of the rounded top corners and drag handle area.
  /// Default: '#262626' (Instagram comments dark gray)
  final Color? playableBorderColor;

  MiniGameTheme({
    this.backgroundColor,
    this.headerColor,
    this.borderColor,
    this.titleFont,
    this.secondaryFont,
    this.titleFontColor,
    this.secondaryFontColor,
    this.iconCornerRadius,
    this.accentColor,
    this.playableHeight,
    this.playableBorderColor,
  });
}
