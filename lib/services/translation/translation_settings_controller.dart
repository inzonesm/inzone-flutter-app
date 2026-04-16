import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationLanguageOption {
  final String code;
  final String label;

  const TranslationLanguageOption({
    required this.code,
    required this.label,
  });
}

class TranslationSettingsController extends ChangeNotifier {
  static const String _enabledKey = 'translation_enabled_v1';
  static const String _targetLanguageKey = 'translation_target_language_v1';
  static const String _uiLocaleKey = 'app_ui_locale_v1';
  static const String _showImproveActionKey =
      'translation_show_improve_action_v1';

  static const List<TranslationLanguageOption> supportedLanguages = [
    TranslationLanguageOption(code: 'en', label: 'English'),
    TranslationLanguageOption(code: 'es', label: 'Spanish'),
    TranslationLanguageOption(code: 'fr', label: 'French'),
    TranslationLanguageOption(code: 'de', label: 'German'),
    TranslationLanguageOption(code: 'pt', label: 'Portuguese'),
    TranslationLanguageOption(code: 'ar', label: 'Arabic'),
    TranslationLanguageOption(code: 'hi', label: 'Hindi'),
    TranslationLanguageOption(code: 'ja', label: 'Japanese'),
    TranslationLanguageOption(code: 'ko', label: 'Korean'),
    TranslationLanguageOption(code: 'zh', label: 'Chinese'),
  ];

  bool _translationEnabled = false;
  String _targetLanguageCode = 'en';
  String _uiLocaleCode = 'en';
  bool _showImproveAction = true;
  bool _isLoaded = false;

  bool get translationEnabled => _translationEnabled;
  String get targetLanguageCode => _targetLanguageCode;
  String get uiLocaleCode => _uiLocaleCode;
  bool get showImproveAction => _showImproveAction;
  bool get isLoaded => _isLoaded;

  Locale get locale => Locale(_uiLocaleCode);

  List<Locale> get supportedUiLocales {
    return supportedLanguages.map((option) => Locale(option.code)).toList();
  }

  String languageLabelForCode(String code) {
    for (final option in supportedLanguages) {
      if (option.code == code) {
        return option.label;
      }
    }
    return code.toUpperCase();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _translationEnabled = prefs.getBool(_enabledKey) ?? false;
    _targetLanguageCode = prefs.getString(_targetLanguageKey) ?? 'en';
    _uiLocaleCode = prefs.getString(_uiLocaleKey) ?? 'en';
    _showImproveAction = prefs.getBool(_showImproveActionKey) ?? true;

    if (!_isSupportedCode(_targetLanguageCode)) {
      _targetLanguageCode = 'en';
    }
    if (!_isSupportedCode(_uiLocaleCode)) {
      _uiLocaleCode = 'en';
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setTranslationEnabled(bool enabled) async {
    _translationEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setTargetLanguageCode(String code) async {
    if (!_isSupportedCode(code)) {
      return;
    }

    _targetLanguageCode = code;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_targetLanguageKey, code);
  }

  Future<void> setUiLocaleCode(String code) async {
    if (!_isSupportedCode(code)) {
      return;
    }

    _uiLocaleCode = code;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiLocaleKey, code);
  }

  Future<void> setShowImproveAction(bool show) async {
    _showImproveAction = show;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showImproveActionKey, show);
  }

  bool _isSupportedCode(String code) {
    return supportedLanguages.any((option) => option.code == code);
  }
}
