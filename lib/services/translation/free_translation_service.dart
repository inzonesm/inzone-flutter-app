import 'package:flutter/foundation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:inzone/services/translation/translation_cache_service.dart';
import 'package:inzone/services/translation/translation_metrics_service.dart';
import 'package:inzone/services/translation/translation_result.dart';

class FreeTranslationService {
  FreeTranslationService._();

  static final FreeTranslationService instance = FreeTranslationService._();

  static const Map<String, TranslateLanguage> _mlkitLanguages = {
    'en': TranslateLanguage.english,
    'es': TranslateLanguage.spanish,
    'fr': TranslateLanguage.french,
    'de': TranslateLanguage.german,
    'pt': TranslateLanguage.portuguese,
    'ar': TranslateLanguage.arabic,
    'hi': TranslateLanguage.hindi,
    'ja': TranslateLanguage.japanese,
    'ko': TranslateLanguage.korean,
    'zh': TranslateLanguage.chinese,
  };

  final LanguageIdentifier _identifier =
      LanguageIdentifier(confidenceThreshold: 0.5);
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translatorPool = {};
  final Set<String> _downloadedModels = <String>{};

  Future<TranslationResult> translate({
    required String originalText,
    required String targetLanguageCode,
    bool forceRefresh = false,
  }) async {
    final normalized = originalText.trim();
    if (normalized.isEmpty) {
      return TranslationResult(
        originalText: originalText,
        translatedText: originalText,
        sourceLanguageCode: targetLanguageCode,
        targetLanguageCode: targetLanguageCode,
        wasTranslated: false,
      );
    }

    await TranslationMetricsService.instance.recordRequest();

    final sourceLanguageCode = await _detectLanguageCode(normalized);
    final normalizedTargetLanguageCode =
        _normalizeLanguageCode(targetLanguageCode);

    if (sourceLanguageCode == normalizedTargetLanguageCode) {
      return TranslationResult(
        originalText: originalText,
        translatedText: originalText,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: normalizedTargetLanguageCode,
        wasTranslated: false,
      );
    }

    if (!forceRefresh) {
      final cacheValue = await TranslationCacheService.instance.get(
        source: sourceLanguageCode,
        target: normalizedTargetLanguageCode,
        text: normalized,
      );

      if (cacheValue != null && cacheValue.trim().isNotEmpty) {
        await TranslationMetricsService.instance.recordCacheHit();
        return TranslationResult(
          originalText: originalText,
          translatedText: cacheValue,
          sourceLanguageCode: sourceLanguageCode,
          targetLanguageCode: normalizedTargetLanguageCode,
          wasTranslated: true,
          fromCache: true,
        );
      }
    }

    final sourceLanguage = _mlkitLanguages[sourceLanguageCode];
    final targetLanguage = _mlkitLanguages[normalizedTargetLanguageCode];

    if (!_isMobilePlatform() ||
        sourceLanguage == null ||
        targetLanguage == null) {
      await TranslationMetricsService.instance.recordFallback();
      return TranslationResult(
        originalText: originalText,
        translatedText: originalText,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: normalizedTargetLanguageCode,
        wasTranslated: false,
      );
    }

    try {
      final translator = _translatorPool.putIfAbsent(
        '$sourceLanguageCode>$targetLanguageCode',
        () => OnDeviceTranslator(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        ),
      );

      await _ensureModelDownloaded(sourceLanguage.bcpCode);
      await _ensureModelDownloaded(targetLanguage.bcpCode);
      final translatedText = await translator.translateText(normalized);

      if (translatedText.trim().isEmpty ||
          translatedText.trim() == normalized) {
        await TranslationMetricsService.instance.recordFallback();
        return TranslationResult(
          originalText: originalText,
          translatedText: originalText,
          sourceLanguageCode: sourceLanguageCode,
          targetLanguageCode: normalizedTargetLanguageCode,
          wasTranslated: false,
        );
      }

      await TranslationCacheService.instance.set(
        source: sourceLanguageCode,
        target: normalizedTargetLanguageCode,
        text: normalized,
        translatedText: translatedText,
      );
      await TranslationMetricsService.instance.recordOnDeviceSuccess();

      return TranslationResult(
        originalText: originalText,
        translatedText: translatedText,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: normalizedTargetLanguageCode,
        wasTranslated: true,
      );
    } catch (error) {
      debugPrint('Translation failed [$sourceLanguageCode -> '
          '$normalizedTargetLanguageCode]: $error');
      await TranslationMetricsService.instance.recordFallback();
      return TranslationResult(
        originalText: originalText,
        translatedText: originalText,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: normalizedTargetLanguageCode,
        wasTranslated: false,
      );
    }
  }

  Future<String> _detectLanguageCode(String text) async {
    try {
      final detected = await _identifier.identifyLanguage(text);
      final normalized = _normalizeLanguageCode(detected);
      if (normalized == 'und' || normalized.isEmpty) {
        return 'en';
      }
      return normalized;
    } catch (_) {
      return 'en';
    }
  }

  String _normalizeLanguageCode(String code) {
    final normalized = code.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return '';
    }

    if (normalized == 'iw') {
      return 'he';
    }

    if (normalized.contains('-')) {
      return normalized.split('-').first;
    }

    return normalized;
  }

  bool _isMobilePlatform() {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _ensureModelDownloaded(String languageCode) async {
    if (_downloadedModels.contains(languageCode)) {
      return;
    }

    try {
      final isDownloaded =
          await _modelManager.isModelDownloaded(languageCode).catchError((_) {
        return false;
      });

      if (isDownloaded == true) {
        _downloadedModels.add(languageCode);
        return;
      }

      final downloaded = await _modelManager.downloadModel(
        languageCode,
        isWifiRequired: false,
      );

      if (downloaded) {
        _downloadedModels.add(languageCode);
      }
    } catch (error) {
      debugPrint('Model pre-download failed for $languageCode: $error');
    }
  }

  Future<void> dispose() async {
    for (final translator in _translatorPool.values) {
      translator.close();
    }
    _translatorPool.clear();
    _identifier.close();
  }
}
