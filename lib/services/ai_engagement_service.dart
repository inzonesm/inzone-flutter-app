import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// AI Engagement Service for InZone
/// Manages automatic AI character engagement in the background
class AIEngagementService {
  static const String _apiBaseUrl = 'https://inzoneapi-912424781531.us-central1.run.app';
  static const String _lastRunKey = 'ai_engagement_last_run';
  static const String _enabledKey = 'ai_engagement_enabled';
  
  // Configuration
  static const Duration _defaultInterval = Duration(hours: 2);
  static const Duration _peakInterval = Duration(hours: 1);
  static const int _maxCharactersPerRun = 20;
  
  // Peak engagement hours (9 AM, 1 PM, 6 PM, 9 PM)
  static const List<int> _peakHours = [9, 13, 18, 21];
  
  static Timer? _engagementTimer;
  static bool _isRunning = false;
  static bool _isEnabled = true;
  
  /// Initialize the AI engagement service
  static Future<void> initialize() async {
    try {
      await _loadSettings();
      if (_isEnabled) {
        await _startBackgroundEngagement();
        debugPrint('🤖 AI Engagement Service initialized');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize AI Engagement Service: $e');
    }
  }
  
  /// Start background AI engagement
  static Future<void> _startBackgroundEngagement() async {
    if (_engagementTimer?.isActive == true) {
      _engagementTimer?.cancel();
    }
    
    // Calculate next run time
    final nextRunDuration = _calculateNextRunDuration();
    
    _engagementTimer = Timer(nextRunDuration, () async {
      await _runEngagementCycle();
      // Schedule next run
      await _startBackgroundEngagement();
    });
    
    debugPrint('🕐 Next AI engagement in ${nextRunDuration.inMinutes} minutes');
  }
  
  /// Calculate when to run next engagement cycle
  static Duration _calculateNextRunDuration() {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // Check if we're in a peak hour
    final isPeakHour = _peakHours.contains(currentHour);
    
    // Check if we should run soon based on last run time
    final shouldRunSoon = _shouldRunSoon();
    
    if (shouldRunSoon) {
      return const Duration(minutes: 5); // Run in 5 minutes
    } else if (isPeakHour) {
      return _peakInterval; // More frequent during peak hours
    } else {
      return _defaultInterval; // Normal frequency
    }
  }
  
  /// Check if we should run engagement soon
  static bool _shouldRunSoon() {
    // Implementation would check last run time and current activity
    // For now, return false to use standard intervals
    return false;
  }
  
  /// Execute an AI engagement cycle
  static Future<void> _runEngagementCycle() async {
    if (_isRunning) {
      debugPrint('⚠️ AI engagement cycle already running, skipping');
      return;
    }
    
    _isRunning = true;
    
    try {
      debugPrint('🚀 Starting AI engagement cycle');
      
      final result = await _callEngagementAPI();
      
      if (result['success'] == true) {
        final executed = result['total_executed'] ?? result['total_interactions_executed'] ?? 0;
        final characters = result['total_characters'] ?? 0;
        
        debugPrint('✅ AI engagement completed: $executed interactions for $characters characters');
        
        // Save last run time
        await _saveLastRunTime();
        
        // Optional: Show notification to user (if in debug mode)
        if (kDebugMode && executed > 0) {
          _showEngagementNotification(executed, characters);
        }
      } else {
        final error = result['error'] ?? 'Unknown error';
        final message = result['message'] ?? '';
        
        // Handle specific error types
        if (error == 'AI engagement already running' || error == 'Execution already in progress') {
          debugPrint('⏳ AI engagement already running, will retry later');
          // Don't treat this as a failure, just skip this cycle
        } else if (error == 'Rate limit exceeded' || error == 'Recent execution detected') {
          debugPrint('⏱️ Rate limit hit: $message');
          // Adjust next run time if provided
          if (result.containsKey('next_allowed_time')) {
            // Could implement smart scheduling here
          }
        } else {
          debugPrint('❌ AI engagement failed: $error');
          if (message.isNotEmpty) {
            debugPrint('   Details: $message');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ AI engagement cycle error: $e');
    } finally {
      _isRunning = false;
    }
  }
  
  /// Call the backend API to execute engagement
  static Future<Map<String, dynamic>> _callEngagementAPI() async {
    const int maxRetries = 3;
    int attempt = 0;
    final url = Uri.parse('$_apiBaseUrl/api/ai/schedule-engagement-auto');

    while (attempt < maxRetries) {
      try {
        final response = await http
            .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'limit': _maxCharactersPerRun}),
        )
            .timeout(const Duration(seconds: 120));

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else if (response.statusCode == 429) {
          try {
            final errorBody = jsonDecode(response.body);
            return errorBody;
          } catch (e) {
            return {
              'success': false,
              'error': 'Rate limit exceeded',
              'message': 'Too many requests, please try again later'
            };
          }
        } else {
          return {
            'success': false,
            'error': 'HTTP ${response.statusCode}: ${response.body}'
          };
        }
      } catch (e) {
        attempt++;
        debugPrint('Attempt $attempt failed for AI engagement API: $e');
        if (attempt >= maxRetries) {
          return {
            'success': false,
            'error': e.toString(),
            'message': 'Failed after $attempt attempts'
          };
        }
        // Exponential backoff before retrying
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
    return {'success': false, 'error': 'Unknown error'};
  }
  
  /// Get engagement status from backend
  static Future<Map<String, dynamic>> getEngagementStatus() async {
    try {
      final url = Uri.parse('$_apiBaseUrl/api/ai/engagement-status');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
  
  /// Manually trigger an engagement cycle
  static Future<Map<String, dynamic>> triggerManualEngagement({int? limit}) async {
    const int maxRetries = 3;
    int attempt = 0;
    final url = Uri.parse('$_apiBaseUrl/api/ai/schedule-engagement-auto');

    debugPrint('🎯 Manually triggering AI engagement');

    while (attempt < maxRetries) {
      try {
        final response = await http
            .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'limit': limit ?? _maxCharactersPerRun}),
        )
            .timeout(const Duration(seconds: 120));

        Map<String, dynamic> result;
        if (response.statusCode == 200) {
          result = jsonDecode(response.body);
        } else if (response.statusCode == 429) {
          try {
            result = jsonDecode(response.body);
          } catch (e) {
            result = {
              'success': false,
              'error': 'Rate limit exceeded',
              'message': 'Too many requests, please try again later'
            };
          }
        } else {
          result = {
            'success': false,
            'error': 'HTTP ${response.statusCode}: ${response.body}'
          };
        }

        if (result['success'] == true) {
          await _saveLastRunTime();
        }

        return result;
      } catch (e) {
        attempt++;
        debugPrint('Manual engagement attempt $attempt failed: $e');
        if (attempt >= maxRetries) {
          return {
            'success': false,
            'error': e.toString(),
            'message': 'Failed after $attempt attempts'
          };
        }
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }

    return {'success': false, 'error': 'Unknown error'};
  }
  
  /// Enable or disable AI engagement
  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    
    if (enabled) {
      await _startBackgroundEngagement();
      debugPrint('✅ AI engagement enabled');
    } else {
      _engagementTimer?.cancel();
      debugPrint('⏹️ AI engagement disabled');
    }
  }
  
  /// Start background engagement (public method)
  static Future<void> start() async {
    if (!_isEnabled) {
      debugPrint('⚠️ AI engagement is disabled, cannot start');
      return;
    }
    
    await _startBackgroundEngagement();
    debugPrint('🚀 AI engagement background service started');
  }
  
  /// Check if AI engagement is enabled
  static bool get isEnabled => _isEnabled;
  
  /// Get time until next engagement
  static Duration? get timeUntilNext {
    if (_engagementTimer?.isActive == true) {
      // This is an approximation since Timer doesn't expose remaining time
      return _calculateNextRunDuration();
    }
    return null;
  }
  
  /// Get last run time
  static Future<DateTime?> getLastRunTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastRunKey);
    return timestamp != null 
      ? DateTime.fromMillisecondsSinceEpoch(timestamp)
      : null;
  }
  
  /// Load settings from SharedPreferences
  static Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? true;
  }
  
  /// Save last run time
  static Future<void> _saveLastRunTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRunKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Show engagement notification (debug only)
  static void _showEngagementNotification(int interactions, int characters) {
    debugPrint('🎉 AI Engagement: $interactions interactions across $characters characters');
    // In production, you might want to show a subtle in-app notification
  }
  
  /// Dispose resources
  static void dispose() {
    _engagementTimer?.cancel();
    _isRunning = false;
    debugPrint('🛑 AI Engagement Service disposed');
  }
  
  /// Get service statistics
  static Future<Map<String, dynamic>> getServiceStats() async {
    final lastRun = await getLastRunTime();
    
    return {
      'is_enabled': _isEnabled,
      'is_running': _isRunning,
      'last_run': lastRun?.toIso8601String(),
      'time_until_next_minutes': timeUntilNext?.inMinutes,
      'max_characters_per_run': _maxCharactersPerRun,
      'peak_hours': _peakHours,
    };
  }
}
