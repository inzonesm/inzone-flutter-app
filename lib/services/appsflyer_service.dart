import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:inzone/config/api_config.dart';
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
  static const String _pendingReferralKey = 'pending_referral_payload_v1';
  static const String _legacyReferrerKey = 'referrer_id';
  static const String _legacyAttributionKey = 'attribution_data';
  late AppsflyerSdk appsflyerSdk;

  // Store attribution data
  Map<String, dynamic>? _attributionData;
  Map<String, dynamic>? _conversionData;
  final StreamController<String> _minigameDeepLinkController =
      StreamController<String>.broadcast();
  final StreamController<String?> _minigameMenuOpenController =
      StreamController<String?>.broadcast();
  // Community (html) games live in the `html_games` collection and open on the
  // Game Hub, NOT the Simula minigame catalogue — they have their own stream so
  // their deep links never fall into the minigame menu.
  final StreamController<String> _communityGameDeepLinkController =
      StreamController<String>.broadcast();
  // On a cold start the deep link can arrive before RootApp subscribes to the
  // (broadcast) stream above, which would drop the event. We also stash the last
  // gameId here so RootApp can consume it once it has mounted.
  String? _pendingCommunityGameDeepLinkGameId;

  Stream<String> get minigameDeepLinkStream =>
      _minigameDeepLinkController.stream;
  Stream<String?> get minigameMenuOpenStream =>
      _minigameMenuOpenController.stream;
  Stream<String> get communityGameDeepLinkStream =>
      _communityGameDeepLinkController.stream;

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

    // Community / html games open on the Game Hub (CommunityGameScreen).
    if (deepLinkValue == 'community_game' || deepLinkValue == 'html_game') {
      if (deepLinkSub1 != null && deepLinkSub1.isNotEmpty) {
        _handleCommunityGameDeepLink(deepLinkSub1);
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
    if (!_minigameDeepLinkController.isClosed) {
      _minigameDeepLinkController.add(gameId);
    }
    logEvent('minigame_deep_link_received', {'game_id': gameId});
  }

  Future<void> _handleCommunityGameDeepLink(String gameId) async {
    final normalized = gameId.trim();
    if (normalized.isEmpty) return;
    _pendingCommunityGameDeepLinkGameId = normalized;
    if (!_communityGameDeepLinkController.isClosed) {
      _communityGameDeepLinkController.add(normalized);
    }
    logEvent('community_game_deep_link_received', {'game_id': normalized});
  }

  /// Returns and clears any community-game deep link that arrived before a
  /// listener was attached (e.g. on cold start). Returns null if none pending.
  String? consumePendingCommunityGameDeepLinkGameId() {
    final gameId = _pendingCommunityGameDeepLinkGameId;
    _pendingCommunityGameDeepLinkGameId = null;
    if (gameId != null && gameId.trim().isNotEmpty) {
      return gameId.trim();
    }
    return null;
  }

  Future<void> queueMinigameDeepLink(String gameId) async {
    final normalized = gameId.trim();
    if (normalized.isEmpty) return;
    if (!_minigameDeepLinkController.isClosed) {
      _minigameDeepLinkController.add(normalized);
    }
    logEvent('minigame_deep_link_queued', {'game_id': normalized});
  }

  Future<void> queueCommunityGameDeepLink(String gameId) async {
    final normalized = gameId.trim();
    if (normalized.isEmpty) return;
    _pendingCommunityGameDeepLinkGameId = normalized;
    if (!_communityGameDeepLinkController.isClosed) {
      _communityGameDeepLinkController.add(normalized);
    }
    logEvent('community_game_deep_link_queued', {'game_id': normalized});
  }

  Future<void> openMinigameMenu({String? initialGameId}) async {
    final normalized = initialGameId?.trim();
    if (!_minigameMenuOpenController.isClosed) {
      _minigameMenuOpenController
          .add((normalized == null || normalized.isEmpty) ? null : normalized);
    }

    if (normalized != null && normalized.isNotEmpty) {
      logEvent('minigame_menu_open_requested', {'game_id': normalized});
    } else {
      logEvent('minigame_menu_open_requested', {'game_id': null});
    }
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
    if (referrerId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final normalizedAttributionData =
        _normalizeReferralAttribution(attributionData);
    final pendingPayload = <String, dynamic>{
      'referrerId': referrerId,
      'attributionData': normalizedAttributionData,
      'receivedAt': DateTime.now().millisecondsSinceEpoch,
    };

    await prefs.setString(_pendingReferralKey, jsonEncode(pendingPayload));
    await prefs.setString(_legacyReferrerKey, referrerId);

    if (normalizedAttributionData.isNotEmpty) {
      await prefs.setString(
          _legacyAttributionKey, jsonEncode(normalizedAttributionData));
    }

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final saved = await _saveReferralToFirestore(
          referrerId, normalizedAttributionData, currentUser);
      if (saved) {
        await prefs.remove(_pendingReferralKey);
        await prefs.remove(_legacyReferrerKey);
        await prefs.remove(_legacyAttributionKey);
      }
    } else {
      log('User not signed in yet. Referral data saved locally and will be sent after login.');
    }

    // Log referral event
    logEvent('referral_received', {'referrer_id': referrerId});
  }

  Future<void> checkAndSavePendingReferral() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? referrerId;
      Map<String, dynamic>? attributionData;

      final pendingPayloadString = prefs.getString(_pendingReferralKey);
      if (pendingPayloadString != null && pendingPayloadString.isNotEmpty) {
        try {
          final decoded = jsonDecode(pendingPayloadString);
          if (decoded is Map) {
            final pendingMap = Map<String, dynamic>.from(decoded);
            referrerId = pendingMap['referrerId']?.toString();
            final pendingAttribution = pendingMap['attributionData'];
            if (pendingAttribution is Map) {
              attributionData = Map<String, dynamic>.from(pendingAttribution);
            }
          }
        } catch (e) {
          log('Error decoding pending referral payload: $e');
        }
      }

      referrerId ??= prefs.getString(_legacyReferrerKey);
      if (attributionData == null) {
        final attributionDataString = prefs.getString(_legacyAttributionKey);
        if (attributionDataString != null && attributionDataString.isNotEmpty) {
          try {
            final decoded = jsonDecode(attributionDataString);
            if (decoded is Map) {
              attributionData = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {
            attributionData = {'stored_data': attributionDataString};
          }
        }
      }

      if (referrerId != null && referrerId.isNotEmpty) {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final normalizedAttributionData =
              _normalizeReferralAttribution(attributionData);
          final saved = await _saveReferralToFirestore(
              referrerId, normalizedAttributionData, currentUser);

          if (saved) {
            await prefs.remove(_pendingReferralKey);
            await prefs.remove(_legacyReferrerKey);
            await prefs.remove(_legacyAttributionKey);
            log('Saved pending referral data for signed-in user');
          }
        }
      }
    } catch (e) {
      log('Error checking for pending referrals: $e');
    }
  }

  Future<bool> _saveReferralToFirestore(String referrerId,
      Map<String, dynamic>? attributionData, User user) async {
    try {
      if (referrerId.isEmpty || user.uid.isEmpty) {
        return false;
      }
      if (referrerId == user.uid) {
        log('Skipping self-referral for user ${user.uid}');
        return false;
      }

      // Get AppsFlyer ID
      String? appsFlyerId = await getAdvertisingId();
      final firestore = FirebaseFirestore.instance;
        final normalizedAttributionData =
          _normalizeReferralAttribution(attributionData);
        final installerProfile =
          await _loadInstallerProfile(firestore: firestore, installerId: user.uid);
        final installerDisplayName =
          _resolveInstallerDisplayName(user: user, profile: installerProfile);
        final installerPhotoUrl =
          _resolveInstallerPhotoUrl(user: user, profile: installerProfile);
      final referralKey = '${referrerId}_${user.uid}';
      final referralDoc = firestore.collection('referrals').doc(referralKey);
      final existingReferral = await referralDoc.get();

      if (existingReferral.exists) {
        log('Referral already exists for referrer $referrerId and installer ${user.uid}');
        return true;
      }

      // Create the document data with complete user details
      Map<String, dynamic> referralData = {
        'referrerId': referrerId,
        'installerId': user.uid,
        'installerEmail': user.email,
        'installerDisplayName': installerDisplayName,
        'installerPhoneNumber': user.phoneNumber,
        'installerPhotoURL': installerPhotoUrl,
        'installerEmailVerified': user.emailVerified,
        'installerCreationTime':
            user.metadata.creationTime?.millisecondsSinceEpoch,
        'installerLastSignInTime':
            user.metadata.lastSignInTime?.millisecondsSinceEpoch,
        'appsFlyerId': appsFlyerId,
        'attributionData': normalizedAttributionData,
        'installTimestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatform(),
        'conversionData': _conversionData,
        'referralKey': referralKey,
      };

      await referralDoc.set(referralData, SetOptions(merge: true));

      await _markInstallerReferrerIfMissing(
        firestore: firestore,
        installerId: user.uid,
        referrerId: referrerId,
      );

      // Add 1500 to balance for both users
      await _updateUserBalance(referrerId, 1500); // Referrer gets 1500
      await _updateUserBalance(user.uid, 1500); // Installer gets 1500

      try {
        await http.post(
          Uri.parse(ApiConfig.endpoint('/user/referral/track-accepted')),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'ReferrerId': referrerId,
            'RefereeId': user.uid,
            'Platform': _getPlatform(),
            'Source': 'appsflyer_deeplink',
            'AttributionData': {
              ...normalizedAttributionData,
              'appsFlyerId': appsFlyerId,
              'installerEmail': user.email,
                'installerDisplayName': installerDisplayName,
              'installerPhoneNumber': user.phoneNumber,
                'installerPhotoURL': installerPhotoUrl,
              'installerEmailVerified': user.emailVerified,
              'installerCreationTime':
                  user.metadata.creationTime?.millisecondsSinceEpoch,
              'installerLastSignInTime':
                  user.metadata.lastSignInTime?.millisecondsSinceEpoch,
              'conversionData': _conversionData,
            },
          }),
        );
      } catch (e) {
        log('Error mirroring accepted referral to backend: $e');
      }

      log('Successfully saved referral data to Firestore with complete user details');
      log('Successfully added 1500 balance to both referrer ($referrerId) and installer (${user.uid})');
      return true;
    } catch (e) {
      log('Error saving referral data to Firestore: $e');
      return false;
    }
  }

  Future<void> _markInstallerReferrerIfMissing({
    required FirebaseFirestore firestore,
    required String installerId,
    required String referrerId,
  }) async {
    final installerRef = firestore.collection('humanUsers').doc(installerId);
    await firestore.runTransaction((transaction) async {
      final installerSnapshot = await transaction.get(installerRef);
      final installerData = installerSnapshot.data() ?? <String, dynamic>{};
      final existingReferrer = installerData['referred_by']?.toString();

      if (existingReferrer == null || existingReferrer.isEmpty) {
        transaction.set(installerRef, {
          'referred_by': referrerId,
        }, SetOptions(merge: true));
      }
    });
  }

  Future<Map<String, dynamic>?> _loadInstallerProfile({
    required FirebaseFirestore firestore,
    required String installerId,
  }) async {
    try {
      final snapshot = await firestore.collection('humanUsers').doc(installerId).get();
      return snapshot.data();
    } catch (e) {
      return null;
    }
  }

  String? _resolveInstallerDisplayName({
    required User user,
    required Map<String, dynamic>? profile,
  }) {
    final authDisplayName = user.displayName?.trim();
    if (authDisplayName != null && authDisplayName.isNotEmpty) {
      return authDisplayName;
    }

    final profileName = profile?['name']?.toString().trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    final profileNameLegacy = profile?['Name']?.toString().trim();
    if (profileNameLegacy != null && profileNameLegacy.isNotEmpty) {
      return profileNameLegacy;
    }

    final profileUsername = profile?['username']?.toString().trim();
    if (profileUsername != null && profileUsername.isNotEmpty) {
      return profileUsername;
    }

    final profileUsernameLegacy = profile?['Username']?.toString().trim();
    if (profileUsernameLegacy != null && profileUsernameLegacy.isNotEmpty) {
      return profileUsernameLegacy;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) {
        return local;
      }
      return email;
    }

    return user.uid;
  }

  String? _resolveInstallerPhotoUrl({
    required User user,
    required Map<String, dynamic>? profile,
  }) {
    final authPhoto = user.photoURL?.trim();
    if (authPhoto != null && authPhoto.isNotEmpty) {
      return authPhoto;
    }

    final profilePhoto = profile?['profilePicture']?.toString().trim();
    if (profilePhoto != null && profilePhoto.isNotEmpty) {
      return profilePhoto;
    }

    final profilePhotoLegacy = profile?['ProfilePicture']?.toString().trim();
    if (profilePhotoLegacy != null && profilePhotoLegacy.isNotEmpty) {
      return profilePhotoLegacy;
    }

    final profilePhotoUrl = profile?['profile_picture_url']?.toString().trim();
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      return profilePhotoUrl;
    }

    return null;
  }

  Map<String, dynamic> _normalizeReferralAttribution(
      Map<String, dynamic>? raw) {
    final source = raw ?? <String, dynamic>{};
    final normalized = <String, dynamic>{
      'is_deferred': source['is_deferred'],
      'af_sub4': source['af_sub4'] ?? '',
      'click_http_referrer': source['click_http_referrer'] ?? '',
      'af_sub1': source['af_sub1'] ?? '',
      'af_sub3': source['af_sub3'] ?? '',
      'deep_link_value': source['deep_link_value'] ?? source['deep_link'] ?? '',
      'campaign': source['campaign'] ?? '',
      'match_type': source['match_type'] ?? '',
      'af_sub5': source['af_sub5'] ?? '',
      'campaign_id': source['campaign_id'] ?? '',
      'media_source': source['media_source'] ?? '',
      'deep_link_sub1': source['deep_link_sub1'] ?? '',
      'af_sub2': source['af_sub2'] ?? '',
    };

    normalized.removeWhere((key, value) => value == null);
    return normalized;
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

  String generateMinigameAccomplishmentLink(String gameId) {
    final Uri fallbackDeepLink = Uri(
      scheme: 'inzone',
      host: 'minigame',
      queryParameters: {
        'gameId': gameId,
      },
    );

    final Uri accomplishmentOneLink = Uri.https('join-inzone.onelink.me', '/SACg', {
      'af_xp': 'custom',
      'pid': 'minigame_accomplishment',
      'deep_link_value': 'minigame',
      'deep_link_sub1': gameId,
      'af_dp': fallbackDeepLink.toString(),
    });

    return accomplishmentOneLink.toString();
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
