import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

// Post View Tracking Helper
class PostViewTracker {
  static final Map<String, DateTime> _postViewStartTimes = {};
  static final Map<String, int> _postRewatchCounts = {};

  static void startViewingPost(String postId) {
    _postViewStartTimes[postId] = DateTime.now();
  }

  static void stopViewingPost(
    String postId, {
    String? category,
    String? postType,
    String? authorId,
  }) {
    final startTime = _postViewStartTimes[postId];
    if (startTime != null) {
      final viewDuration = DateTime.now().difference(startTime).inSeconds;
      final userId = AppsFlyerService().getCurrentUserId();

      if (userId != null && viewDuration > 1) {
        // Only track views longer than 1 second
        AppsFlyerService().trackPostView(
          postId: postId,
          timeSpentSeconds: viewDuration,
          category: category ?? 'unknown',
          userId: userId,
          postType: postType,
          authorId: authorId,
        );
      }

      _postViewStartTimes.remove(postId);
    }
  }

  static void trackRewatch(String postId) {
    _postRewatchCounts[postId] = (_postRewatchCounts[postId] ?? 0) + 1;
    final userId = AppsFlyerService().getCurrentUserId();

    if (userId != null) {
      AppsFlyerService().trackPostRewatch(
        postId: postId,
        userId: userId,
        rewatchCount: _postRewatchCounts[postId]!,
      );
    }
  }

  static void clearPostTracking(String postId) {
    _postViewStartTimes.remove(postId);
    _postRewatchCounts.remove(postId);
  }
}

class AppsFlyerService {
  static final AppsFlyerService _instance = AppsFlyerService._internal();
  static const String pendingMinigameDeepLinkGameIdKey =
      'pending_minigame_deeplink_game_id';
  late AppsflyerSdk appsflyerSdk;

  // Store attribution data
  Map<String, dynamic>? _attributionData;
  Map<String, dynamic>? _conversionData;

  factory AppsFlyerService() {
    return _instance;
  }

  AppsFlyerService._internal() {
    final AppsFlyerOptions appsFlyerOptions = AppsFlyerOptions(
      afDevKey: "GouQRMcXkXP2CMBgZfHdfB",
      appId: "6478089068",
      showDebug: true,
      timeToWaitForATTUserAuthorization: 60, // For iOS 14.5+
    );

    appsflyerSdk = AppsflyerSdk(appsFlyerOptions);
  }

  Future<void> initialize() async {
    await appsflyerSdk.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    // Set up deep link listeners
    setupDeepLinkListeners();

    // Set customer user ID if available
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setCustomerUserId(currentUser.uid);
      // Check if there's a pending referral for this user and save it
      await checkAndSavePendingReferral();
    }

    // Add auth state listener to detect sign-in
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // User signed in, set customer ID and check pending referrals
        setCustomerUserId(user.uid);
        checkAndSavePendingReferral();
      }
    });
  }

  void setupDeepLinkListeners() {
    appsflyerSdk.onAppOpenAttribution((dynamic data) {
      try {
        final Map<String, dynamic> mapData = Map<String, dynamic>.from(data);
        _attributionData = mapData;
        _handleDeepLinkPayload(mapData);
      } catch (e) {
        log('Error parsing onAppOpenAttribution data: $e');
      }
    });

    appsflyerSdk.onInstallConversionData((dynamic data) {
      try {
        final Map<String, dynamic> mapData = Map<String, dynamic>.from(data);
        _conversionData = mapData;
        _handleDeepLinkPayload(mapData);
      } catch (e) {
        log('Error parsing onInstallConversionData data: $e');
      }
    });

    // Listen for deep linking
    appsflyerSdk.onDeepLinking((DeepLinkResult deepLinkResult) {
      switch (deepLinkResult.status) {
        case Status.FOUND:
          // Deep link found
          final deepLinkData = deepLinkResult.deepLink;
          if (deepLinkData?.clickEvent != null) {
            final payload =
                Map<String, dynamic>.from(deepLinkData!.clickEvent);
            _handleDeepLinkPayload(payload);
          }
          break;
        case Status.NOT_FOUND:
          // Deep link not found
          log('Deep link not found.');
          break;
        case Status.ERROR:
          // Error getting deep link
          log('Deep link error: ${deepLinkResult.error}');
          break;
        default:
          break;
      }
    });
  }

  void _handleDeepLinkPayload(Map<String, dynamic> payload) {
    final deepLinkValue = (payload['deep_link_value'] ?? payload['deep_link'])
        ?.toString()
        .toLowerCase();
    final deepLinkSub1 = payload['deep_link_sub1']?.toString();

    if (deepLinkValue == 'referral') {
      if (deepLinkSub1 != null && deepLinkSub1.isNotEmpty) {
        _handleReferral(deepLinkSub1, payload);
      }
      return;
    }

    if (deepLinkValue == 'minigame') {
      if (deepLinkSub1 != null && deepLinkSub1.isNotEmpty) {
        _handleMinigameDeepLink(deepLinkSub1);
      }
      return;
    }

    // Backwards-compatible fallback for payloads without deep_link_value
    if (deepLinkSub1 != null && deepLinkSub1.isNotEmpty) {
      _handleReferral(deepLinkSub1, payload);
    }
  }

  Future<void> _handleMinigameDeepLink(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingMinigameDeepLinkGameIdKey, gameId);
    logEvent('minigame_deep_link_received', {'game_id': gameId});
  }

  static Future<String?> consumePendingMinigameDeepLinkGameId() async {
    final prefs = await SharedPreferences.getInstance();
    final gameId = prefs.getString(pendingMinigameDeepLinkGameIdKey);
    if (gameId != null && gameId.trim().isNotEmpty) {
      await prefs.remove(pendingMinigameDeepLinkGameIdKey);
      return gameId;
    }
    return null;
  }

  void _handleReferral(
      String referrerId, Map<String, dynamic>? attributionData) async {
    // Store the referrerId and attribution data using SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('referrer_id', referrerId);

    // Store attribution data as a string
    if (attributionData != null) {
      await prefs.setString('attribution_data', attributionData.toString());
    }

    // If user is already logged in, save the referral data to Firestore
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _saveReferralToFirestore(referrerId, attributionData, currentUser);
    } else {
      log('User not signed in yet. Referral data saved locally and will be sent after login.');
    }

    // Log referral event
    logEvent('referral_received', {'referrer_id': referrerId});
  }

  Future<void> checkAndSavePendingReferral() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final referrerId = prefs.getString('referrer_id');

      if (referrerId != null) {
        // We have a stored referral, get the current user
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // Get stored attribution data if available
          String? attributionDataString = prefs.getString('attribution_data');
          Map<String, dynamic>? attributionData;
          if (attributionDataString != null &&
              attributionDataString.isNotEmpty) {
            // Convert string representation back to map (simple approach)
            // This is a simple implementation and may need improvement for complex objects
            attributionData = {'stored_data': attributionDataString};
          }

          // Save to Firestore with complete user details
          await _saveReferralToFirestore(
              referrerId, attributionData, currentUser);

          // Optionally clear the stored referral after saving to avoid duplicates
          // await prefs.remove('referrer_id');
          // await prefs.remove('attribution_data');
          log('Saved pending referral data for signed-in user');
        }
      }
    } catch (e) {
      log('Error checking for pending referrals: $e');
    }
  }

  Future<void> _saveReferralToFirestore(String referrerId,
      Map<String, dynamic>? attributionData, User user) async {
    try {
      // Get AppsFlyer ID
      String? appsFlyerId = await getAdvertisingId();

      // Create the document data with complete user details
      Map<String, dynamic> referralData = {
        'referrerId': referrerId,
        'installerId': user.uid,
        'installerEmail': user.email,
        'installerDisplayName': user.displayName,
        'installerPhoneNumber': user.phoneNumber,
        'installerPhotoURL': user.photoURL,
        'installerEmailVerified': user.emailVerified,
        'installerCreationTime':
            user.metadata.creationTime?.millisecondsSinceEpoch,
        'installerLastSignInTime':
            user.metadata.lastSignInTime?.millisecondsSinceEpoch,
        'appsFlyerId': appsFlyerId,
        'attributionData': attributionData ?? {},
        'installTimestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatform(),
        'conversionData': _conversionData,
      };

      // Get a reference to the Firestore collection
      final firestore = FirebaseFirestore.instance;

      // Add a new document to the 'referrals' collection
      await firestore.collection('referrals').add(referralData);

      // Add 1500 to balance for both users
      await _updateUserBalance(referrerId, 1500); // Referrer gets 1500
      await _updateUserBalance(user.uid, 1500); // Installer gets 1500

      log('Successfully saved referral data to Firestore with complete user details');
      log('Successfully added 1500 balance to both referrer ($referrerId) and installer (${user.uid})');
    } catch (e) {
      log('Error saving referral data to Firestore: $e');
    }
  }

  Future<void> _updateUserBalance(String userId, int amount) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('humanUsers').doc(userId).update({
        'balance': FieldValue.increment(amount),
      });
      log('Successfully added $amount to balance for user: $userId');
    } catch (e) {
      log('Error updating balance for user $userId: $e');
    }
  }

  String _getPlatform() {
    if (Platform.isIOS) {
      return "ios";
    } else if (Platform.isAndroid) {
      return "android";
    } else {
      return "unknown";
    }
  }

  void setCustomerUserId(String userId) {
    appsflyerSdk.setCustomerUserId(userId);
  }

  Future<bool?> logEvent(
      String eventName, Map<String, dynamic>? eventValues) async {
    // Debug logging for testing
    // print('🔥 AppsFlyer Event: $eventName');
    if (eventValues != null) {
      print('📊 Parameters: ${eventValues.toString()}');
    }

    final result = await appsflyerSdk.logEvent(eventName, eventValues);
    // print('✅ Event sent successfully: $result');

    return result;
  }

  Future<String?> getAdvertisingId() async {
    return await appsflyerSdk.getAppsFlyerUID();
  }

  String generateReferralLink(String userId) {
    final Uri referralUri = Uri.https('join-inzone.onelink.me', '/SACg', {
      'af_xp': 'custom',
      'pid': 'my_media_source',
      'deep_link_value': 'referral',
      'deep_link_sub1': userId,
    });

    return referralUri.toString();
  }

  String generateMinigameLink(String gameId) {
    final Uri fallbackDeepLink = Uri(
      scheme: 'inzone',
      host: 'minigame',
      queryParameters: {
        'gameId': gameId,
      },
    );

    final Uri minigameOneLink = Uri.https('join-inzone.onelink.me', '/SACg', {
      'af_xp': 'custom',
      'pid': 'social_share',
      'deep_link_value': 'minigame',
      'deep_link_sub1': gameId,
      'af_dp': fallbackDeepLink.toString(),
    });

    return minigameOneLink.toString();
  }

  Future<bool?> trackSignupEvent(String referrerId) {
    return logEvent('signup', {
      'referrer_id': referrerId,
    });
  }

  Future<bool?> trackPurchaseEvent(
      String productId, double price, String currency, String referrerId) {
    return logEvent('purchase', {
      'product_id': productId,
      'price': price,
      'currency': currency,
      'referrer_id': referrerId,
    });
  }

  // ==================== BEHAVIORAL TRACKING METHODS ====================

  // Post Engagement Tracking
  Future<bool?> trackPostView({
    required String postId,
    required int timeSpentSeconds,
    required String category,
    required String userId,
    String? postType,
    String? authorId,
  }) {
    return logEvent('post_view', {
      'post_id': postId,
      'time_spent_sec': timeSpentSeconds,
      'category': category,
      'user_id': userId,
      'post_type': postType,
      'author_id': authorId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackPostLike({
    required String postId,
    required String userId,
    required bool isLiked, // true for like, false for unlike
    String? category,
    String? authorId,
  }) {
    return logEvent('post_like', {
      'post_id': postId,
      'user_id': userId,
      'action': isLiked ? 'like' : 'unlike',
      'category': category,
      'author_id': authorId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackPostComment({
    required String postId,
    required String userId,
    required String commentText,
    String? category,
    String? authorId,
  }) {
    return logEvent('post_comment', {
      'post_id': postId,
      'user_id': userId,
      'comment_length': commentText.length,
      'category': category,
      'author_id': authorId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackVideoCompletion({
    required String postId,
    required String userId,
    required double watchedPercent,
    required int durationSeconds,
    required bool completed,
  }) {
    return logEvent('video_completion', {
      'post_id': postId,
      'user_id': userId,
      'watched_percent': watchedPercent,
      'duration_sec': durationSeconds,
      'completed': completed,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackPostRewatch({
    required String postId,
    required String userId,
    required int rewatchCount,
  }) {
    return logEvent('post_rewatch', {
      'post_id': postId,
      'user_id': userId,
      'rewatch_count': rewatchCount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // AI Character Interaction Tracking
  Future<bool?> trackAICharacterInteraction({
    required String characterId,
    required String userId,
    required int durationSeconds,
    required int messageCount,
    String? interactionType,
  }) {
    return logEvent('ai_character_interaction', {
      'character_id': characterId,
      'user_id': userId,
      'duration_sec': durationSeconds,
      'message_count': messageCount,
      'interaction_type': interactionType ?? 'chat',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Group Chat Tracking
  Future<bool?> trackGroupChatJoined({
    required String groupId,
    required String userId,
  }) {
    return logEvent('groupchat_joined', {
      'group_id': groupId,
      'user_id': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackGroupChatActivity({
    required String groupId,
    required String userId,
    required int durationSeconds,
    required int messagesSent,
  }) {
    return logEvent('groupchat_activity', {
      'group_id': groupId,
      'user_id': userId,
      'duration_sec': durationSeconds,
      'messages_sent': messagesSent,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Scroll & Navigation Tracking
  Future<bool?> trackScrollBehavior({
    required String screenName,
    required double scrollSpeedPxPerSec,
    required String scrollDirection,
    required int durationSeconds,
    required String userId,
  }) {
    return logEvent('scroll_behavior', {
      'screen_name': screenName,
      'scroll_speed_px_per_sec': scrollSpeedPxPerSec,
      'scroll_direction': scrollDirection,
      'duration_sec': durationSeconds,
      'user_id': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Search Tracking
  Future<bool?> trackSearchQuery({
    required String query,
    required String userId,
    required int resultCount,
    String? category,
  }) {
    return logEvent('search_query', {
      'query': query,
      'user_id': userId,
      'result_count': resultCount,
      'category': category,
      'query_length': query.length,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Content Creation Tracking
  Future<bool?> trackContentCreation({
    required String userId,
    required String postType,
    required String category,
    required int contentLength,
    required String mediaType,
    List<String>? tags,
  }) {
    return logEvent('content_created', {
      'user_id': userId,
      'post_type': postType,
      'category': category,
      'content_length': contentLength,
      'media_type': mediaType,
      'tags': tags?.join(','),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Session & App Usage Tracking
  Future<bool?> trackSessionStart({
    required String userId,
    String? location,
    String? deviceModel,
  }) {
    return logEvent('session_start', {
      'user_id': userId,
      'location': location,
      'device_model': deviceModel,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackSessionEnd({
    required String userId,
    required int sessionDurationSeconds,
  }) {
    return logEvent('session_end', {
      'user_id': userId,
      'session_duration_sec': sessionDurationSeconds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackDailyActiveTime({
    required String userId,
    required int totalMinutesActive,
    required String date,
  }) {
    return logEvent('daily_active_time', {
      'user_id': userId,
      'total_minutes_active': totalMinutesActive,
      'date': date,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Device & Settings Tracking
  Future<bool?> trackDeviceInfo({
    required String userId,
    required String deviceModel,
    required String osVersion,
    required String appVersion,
  }) {
    return logEvent('device_info', {
      'user_id': userId,
      'device_model': deviceModel,
      'os_version': osVersion,
      'app_version': appVersion,
      'platform': _getPlatform(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackLanguageSettings({
    required String userId,
    required String languageCode,
  }) {
    return logEvent('language_setting', {
      'user_id': userId,
      'language_code': languageCode,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackLocationUpdate({
    required String userId,
    required String city,
    required String country,
    double? latitude,
    double? longitude,
  }) {
    return logEvent('location_update', {
      'user_id': userId,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Social Features Tracking
  Future<bool?> trackFollowAction({
    required String userId,
    required String targetUserId,
    required bool isFollowing, // true for follow, false for unfollow
  }) {
    return logEvent('follow_action', {
      'user_id': userId,
      'target_user_id': targetUserId,
      'action': isFollowing ? 'follow' : 'unfollow',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ==================== ADVANCED ANALYTICS METHODS ====================

  // AI Character Advanced Analytics
  Future<bool?> trackAICharacterRecommendation({
    required String characterId,
    required String userId,
    required String
        recommendationType, // 'popular', 'similar', 'trending', 'personalized'
    List<String>? basedOnCharacters,
    String? algorithmVersion,
  }) {
    return logEvent('ai_character_recommendation', {
      'character_id': characterId,
      'user_id': userId,
      'recommendation_type': recommendationType,
      'based_on_characters': basedOnCharacters?.join(','),
      'algorithm_version': algorithmVersion,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackAICharacterConversationQuality({
    required String characterId,
    required String userId,
    required int conversationTurns,
    required double averageResponseTime,
    required String userSatisfaction, // 'high', 'medium', 'low'
    bool conversationCompleted = false,
  }) {
    return logEvent('ai_character_conversation_quality', {
      'character_id': characterId,
      'user_id': userId,
      'conversation_turns': conversationTurns,
      'avg_response_time_ms': averageResponseTime,
      'user_satisfaction': userSatisfaction,
      'conversation_completed': conversationCompleted,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackAICharacterRetention({
    required String characterId,
    required String userId,
    required int daysSinceFirstChat,
    required int totalChats,
    required int totalMessages,
    required bool returningUser,
  }) {
    return logEvent('ai_character_retention', {
      'character_id': characterId,
      'user_id': userId,
      'days_since_first_chat': daysSinceFirstChat,
      'total_chats': totalChats,
      'total_messages': totalMessages,
      'returning_user': returningUser,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Group Chat Advanced Analytics
  Future<bool?> trackGroupChatCohesion({
    required String groupId,
    required String userId,
    required double participationRate, // % of messages user contributed
    required int activeParticipants,
    required double averageResponseTime,
    List<String>? topContributors,
  }) {
    return logEvent('group_chat_cohesion', {
      'group_id': groupId,
      'user_id': userId,
      'participation_rate': participationRate,
      'active_participants': activeParticipants,
      'avg_response_time_sec': averageResponseTime,
      'top_contributors': topContributors?.join(','),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackGroupChatModerationEvent({
    required String groupId,
    required String userId,
    required String moderationAction, // 'warning', 'mute', 'kick', 'report'
    required String reason,
    String? moderatorId,
  }) {
    return logEvent('group_chat_moderation', {
      'group_id': groupId,
      'user_id': userId,
      'moderation_action': moderationAction,
      'reason': reason,
      'moderator_id': moderatorId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackGroupChatGrowth({
    required String groupId,
    required int memberCount,
    required int newMembersToday,
    required int activeMembersToday,
    required double growthRate,
  }) {
    return logEvent('group_chat_growth', {
      'group_id': groupId,
      'member_count': memberCount,
      'new_members_today': newMembersToday,
      'active_members_today': activeMembersToday,
      'growth_rate': growthRate,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // User Behavior Pattern Analytics
  Future<bool?> trackUserJourneyMilestone({
    required String userId,
    required String
        milestone, // 'first_ai_chat', 'first_group_join', 'first_week_active', etc.
    required int daysFromSignup,
    Map<String, dynamic>? additionalData,
  }) {
    return logEvent('user_journey_milestone', {
      'user_id': userId,
      'milestone': milestone,
      'days_from_signup': daysFromSignup,
      'additional_data': additionalData?.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackPersonalizationInsight({
    required String userId,
    required String
        insightType, // 'preferred_ai_personality', 'active_time_pattern', 'content_preference'
    required Map<String, dynamic> insights,
    String? confidenceLevel,
  }) {
    return logEvent('personalization_insight', {
      'user_id': userId,
      'insight_type': insightType,
      'insights': insights.toString(),
      'confidence_level': confidenceLevel,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Cross-Feature Analytics
  Future<bool?> trackFeatureTransition({
    required String userId,
    required String fromFeature,
    required String toFeature,
    required int sessionDurationBeforeTransition,
    String? transitionTrigger,
  }) {
    return logEvent('feature_transition', {
      'user_id': userId,
      'from_feature': fromFeature,
      'to_feature': toFeature,
      'session_duration_before_transition': sessionDurationBeforeTransition,
      'transition_trigger': transitionTrigger,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool?> trackEngagementHeatmap({
    required String userId,
    required String featureArea,
    required Map<String, int> interactionCounts,
    required int totalSessionTime,
  }) {
    return logEvent('engagement_heatmap', {
      'user_id': userId,
      'feature_area': featureArea,
      'interaction_counts': interactionCounts.toString(),
      'total_session_time': totalSessionTime,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ==================== UTILITY METHODS ====================

  // Get current user ID from Firebase Auth
  String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // Batch event logging for performance
  Future<void> logBatchEvents(List<Map<String, dynamic>> events) async {
    for (var event in events) {
      await logEvent(event['event_name'], event['parameters']);
    }
  }

  // Get attribution data
  Map<String, dynamic>? getAttributionData() {
    return _attributionData;
  }

  Map<String, dynamic>? getConversionData() {
    return _conversionData;
  }

  // ==================== TESTING METHODS ====================

  /// Test method to fire sample events for verification
  Future<void> testAllAnalytics() async {
    final userId = getCurrentUserId() ?? 'test_user';

    print('🧪 Starting AppsFlyer Analytics Test...');

    // Test 1: AI Character Analytics
    await Future.delayed(const Duration(milliseconds: 500));
    await trackAICharacterInteraction(
      characterId: 'test_char_001',
      userId: userId,
      durationSeconds: 120,
      messageCount: 5,
      interactionType: 'test_chat',
    );

    // Test 2: Group Chat Analytics
    await Future.delayed(const Duration(milliseconds: 500));
    await trackGroupChatActivity(
      groupId: 'test_group_001',
      userId: userId,
      durationSeconds: 180,
      messagesSent: 3,
    );

    // Test 3: Search Analytics
    await Future.delayed(const Duration(milliseconds: 500));
    await trackSearchQuery(
      query: 'test search',
      userId: userId,
      resultCount: 10,
      category: 'test',
    );

    // Test 4: Post Engagement
    await Future.delayed(const Duration(milliseconds: 500));
    await trackPostView(
      postId: 'test_post_001',
      timeSpentSeconds: 45,
      category: 'test',
      userId: userId,
      postType: 'video',
    );

    // Test 5: Session Analytics
    await Future.delayed(const Duration(milliseconds: 500));
    await trackSessionStart(
      userId: userId,
      location: 'test_location',
      deviceModel: 'test_device',
    );

    print('✅ Analytics Test Complete! Check console for event logs.');
  }
}
