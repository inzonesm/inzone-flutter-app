import 'package:inzone/services/translation/translation_metrics_service.dart';
import 'package:inzone/services/translation/translation_result.dart';

class PremiumTranslationRouter {
  PremiumTranslationRouter._();

  static final PremiumTranslationRouter instance = PremiumTranslationRouter._();

  Future<TranslationResult> requestNuancedTranslation({
    required String originalText,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    // Routing is wired now, but a premium provider can be plugged in later.
    await TranslationMetricsService.instance.recordPremiumEscalation();

    return TranslationResult(
      originalText: originalText,
      translatedText: originalText,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      wasTranslated: false,
      usedPremiumRoute: true,
    );
  }
}
