class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final bool wasTranslated;
  final bool fromCache;
  final bool usedPremiumRoute;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.wasTranslated,
    this.fromCache = false,
    this.usedPremiumRoute = false,
  });
}
