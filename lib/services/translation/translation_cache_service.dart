import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TranslationCacheService {
  TranslationCacheService._();

  static final TranslationCacheService instance = TranslationCacheService._();

  static const String _cacheStorageKey = 'translation_cache_v1';
  static const int _maxEntries = 500;
  static const Duration _defaultTtl = Duration(days: 7);

  final Map<String, Map<String, dynamic>> _cache = {};
  bool _isLoaded = false;

  Future<void> _ensureLoaded() async {
    if (_isLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            if (entry.value is Map<String, dynamic>) {
              _cache[entry.key] = Map<String, dynamic>.from(entry.value);
            }
          }
        }
      } catch (_) {
        _cache.clear();
      }
    }

    _isLoaded = true;
  }

  String _buildKey({
    required String source,
    required String target,
    required String text,
  }) {
    final normalized = text.trim();
    final hash = _fnv1a(normalized);
    return '$source|$target|$hash|${normalized.length}';
  }

  String _fnv1a(String input) {
    int hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<String?> get({
    required String source,
    required String target,
    required String text,
  }) async {
    await _ensureLoaded();

    final key = _buildKey(source: source, target: target, text: text);
    final entry = _cache[key];
    if (entry == null) {
      return null;
    }

    final expiresAt = entry['expiresAt'] as int?;
    if (expiresAt == null ||
        DateTime.now().millisecondsSinceEpoch >= expiresAt) {
      _cache.remove(key);
      await _persist();
      return null;
    }

    return entry['value'] as String?;
  }

  Future<void> set({
    required String source,
    required String target,
    required String text,
    required String translatedText,
    Duration ttl = _defaultTtl,
  }) async {
    await _ensureLoaded();

    final key = _buildKey(source: source, target: target, text: text);
    final now = DateTime.now().millisecondsSinceEpoch;

    _cache[key] = {
      'value': translatedText,
      'createdAt': now,
      'expiresAt': now + ttl.inMilliseconds,
    };

    if (_cache.length > _maxEntries) {
      final entries = _cache.entries.toList()
        ..sort((a, b) {
          final aCreated = (a.value['createdAt'] as int?) ?? 0;
          final bCreated = (b.value['createdAt'] as int?) ?? 0;
          return aCreated.compareTo(bCreated);
        });

      final overBy = _cache.length - _maxEntries;
      for (var i = 0; i < overBy; i++) {
        _cache.remove(entries[i].key);
      }
    }

    await _persist();
  }

  Future<int> count() async {
    await _ensureLoaded();
    return _cache.length;
  }

  Future<void> clear() async {
    await _ensureLoaded();
    _cache.clear();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheStorageKey, jsonEncode(_cache));
  }
}
