import 'package:shared_preferences/shared_preferences.dart';

class TranslationMetricsService {
  TranslationMetricsService._();

  static final TranslationMetricsService instance =
      TranslationMetricsService._();

  static const String _requestCountKey = 'translation_metrics_request_count_v1';
  static const String _cacheHitCountKey = 'translation_metrics_cache_hits_v1';
  static const String _onDeviceCountKey =
      'translation_metrics_ondevice_success_v1';
  static const String _fallbackCountKey =
      'translation_metrics_fallback_count_v1';
  static const String _premiumEscalationsKey =
      'translation_metrics_premium_escalations_v1';
  static const String _lastUpdatedAtKey =
      'translation_metrics_last_updated_at_v1';

  Future<void> recordRequest() async {
    await _increment(_requestCountKey);
  }

  Future<void> recordCacheHit() async {
    await _increment(_cacheHitCountKey);
  }

  Future<void> recordOnDeviceSuccess() async {
    await _increment(_onDeviceCountKey);
  }

  Future<void> recordFallback() async {
    await _increment(_fallbackCountKey);
  }

  Future<void> recordPremiumEscalation() async {
    await _increment(_premiumEscalationsKey);
  }

  Future<Map<String, dynamic>> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final requestCount = prefs.getInt(_requestCountKey) ?? 0;
    final cacheHits = prefs.getInt(_cacheHitCountKey) ?? 0;
    final onDeviceSuccess = prefs.getInt(_onDeviceCountKey) ?? 0;
    final fallbackCount = prefs.getInt(_fallbackCountKey) ?? 0;
    final premiumEscalations = prefs.getInt(_premiumEscalationsKey) ?? 0;
    final lastUpdatedMillis = prefs.getInt(_lastUpdatedAtKey);

    final cacheHitRate =
        requestCount == 0 ? 0.0 : (cacheHits / requestCount) * 100;

    return {
      'requestCount': requestCount,
      'cacheHits': cacheHits,
      'onDeviceSuccess': onDeviceSuccess,
      'fallbackCount': fallbackCount,
      'premiumEscalations': premiumEscalations,
      'cacheHitRate': cacheHitRate,
      'lastUpdatedAt': lastUpdatedMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastUpdatedMillis),
    };
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestCountKey);
    await prefs.remove(_cacheHitCountKey);
    await prefs.remove(_onDeviceCountKey);
    await prefs.remove(_fallbackCountKey);
    await prefs.remove(_premiumEscalationsKey);
    await prefs.remove(_lastUpdatedAtKey);
  }

  Future<void> _increment(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, next);
    await prefs.setInt(
        _lastUpdatedAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
