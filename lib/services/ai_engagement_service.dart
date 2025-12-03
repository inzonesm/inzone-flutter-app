import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// AI Engagement Service for InZone
/// Manages automatic AI character engagement in the background
class AIEngagementService {
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
      
      // 1. Run scheduled engagement (likes, comments, DMs)
      final scheduledResult = await _callEngagementAPI();
      
      // 2. Run DM monitoring for immediate responses (24/7 functionality)
      final dmResult = await monitorAndRespondDMs();
      
      // Combine results
      bool overallSuccess = false;
      int totalExecuted = 0;
      int totalCharacters = 0;
      int dmResponses = 0;
      
      if (scheduledResult['success'] == true) {
        final executed = (scheduledResult['total_executed'] ?? scheduledResult['total_interactions_executed'] ?? 0) as int;
        final characters = (scheduledResult['total_characters'] ?? 0) as int;
        totalExecuted += executed;
        totalCharacters = characters;
        overallSuccess = true;
        
        debugPrint('✅ Scheduled engagement: $executed interactions for $characters characters');
      }
      
      if (dmResult['success'] == true) {
        dmResponses = (dmResult['responses_sent'] ?? 0) as int;
        if (dmResponses > 0) {
          debugPrint('✅ DM monitoring: $dmResponses immediate responses sent');
          overallSuccess = true;
        }
      }
      
      if (overallSuccess) {
        // Save last run time
        await _saveLastRunTime();
        
        // Optional: Show notification to user (if in debug mode)
        if (kDebugMode && (totalExecuted > 0 || dmResponses > 0)) {
          _showEngagementNotification(totalExecuted + dmResponses, totalCharacters);
        }
      } else {
        // Handle errors from both scheduled and DM results
        final scheduledError = scheduledResult['error'] ?? '';
        final dmError = dmResult['error'] ?? '';
        
        if (scheduledError == 'AI engagement already running' || scheduledError == 'Execution already in progress') {
          debugPrint('⏳ Scheduled AI engagement already running, will retry later');
        } else if (scheduledError == 'Rate limit exceeded' || scheduledError == 'Recent execution detected') {
          debugPrint('⏱️ Rate limit hit: ${scheduledResult['message'] ?? ''}');
        } else {
          if (scheduledError.isNotEmpty) {
            debugPrint('❌ Scheduled engagement failed: $scheduledError');
          }
          if (dmError.isNotEmpty) {
            debugPrint('❌ DM monitoring failed: $dmError');
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
    final url = Uri.parse(ApiConfig.endpoint('/api/ai/schedule-engagement-auto'));

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
  
  /// Trigger immediate AI DM response when user sends message to AI character
  /// This method provides near-instantaneous responses for real-time conversations
  static Future<Map<String, dynamic>> triggerDMAutoResponse({
    required String userId,
    required String aiCharacterId,
    required String messageText,
    String? conversationId,
  }) async {
    try {
      debugPrint('🚀 Triggering IMMEDIATE AI DM response for user: $userId, AI: $aiCharacterId');
      
      final url = Uri.parse(ApiConfig.endpoint('/api/ai/dm-auto-responder'));
      
      // Use shorter timeout for real-time feel, with retry logic
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Priority': 'immediate', // Custom header to signal urgency
        },
        body: jsonEncode({
          'user_id': userId,
          'ai_character_id': aiCharacterId,
          'message_text': messageText,
          'conversation_id': conversationId,
          'priority': 'immediate', // Flag for immediate processing
          'trigger_time': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15)); // Reduced timeout for faster fail/retry
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint('✅ AI DM auto-response triggered successfully in real-time');
        
        // Also trigger a background monitoring call to catch any missed responses
        _triggerBackgroundMonitoring();
        
        return result;
      } else {
        final errorBody = response.statusCode == 400 || response.statusCode == 404 
          ? jsonDecode(response.body) 
          : {'error': 'HTTP ${response.statusCode}'};
        debugPrint('❌ DM auto-response failed: ${errorBody['error']}');
        
        // If immediate response fails, trigger background monitoring as fallback
        debugPrint('🔄 Triggering backup monitoring for missed response...');
        _triggerBackgroundMonitoring();
        
        return {
          'success': false,
          'error': errorBody['error'] ?? 'Unknown error'
        };
      }
    } catch (e) {
      debugPrint('❌ DM auto-response error: $e');
      
      // On any error, ensure monitoring catches it
      debugPrint('🔄 Error occurred, triggering backup monitoring...');
      _triggerBackgroundMonitoring();
      
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  /// Trigger background monitoring as fallback for missed responses
  static void _triggerBackgroundMonitoring() {
    // Use a brief delay before triggering monitoring to allow message to be processed
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await monitorAndRespondDMs();
      } catch (e) {
        debugPrint('Background monitoring error: $e');
      }
    });
  }
  
  /// Monitor and respond to pending DMs (24/7 monitoring)
  static Future<Map<String, dynamic>> monitorAndRespondDMs() async {
    try {
      final url = Uri.parse(ApiConfig.endpoint('/api/ai/monitor-dms'));
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final responses = result['responses_sent'] ?? 0;
        if (responses > 0) {
          debugPrint('✅ AI DM monitoring: $responses responses sent');
        }
        return result;
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      debugPrint('❌ DM monitoring error: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  /// Get engagement status from backend
  static Future<Map<String, dynamic>> getEngagementStatus() async {
    try {
      final url = Uri.parse(ApiConfig.endpoint('/api/ai/engagement-status'));
      
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
    final url = Uri.parse(ApiConfig.endpoint('/api/ai/schedule-engagement-auto'));

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
    debugPrint('🎉 AI Engagement Complete: $interactions total interactions across $characters characters');
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
