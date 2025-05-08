import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class AppsFlyerService {
  static final AppsFlyerService _instance = AppsFlyerService._internal();
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
    }
  }

  void setupDeepLinkListeners() {
    // Listen for deep link attribution (when app is opened via deep link)
    appsflyerSdk.onAppOpenAttribution((Map<String, dynamic> data) {
      _attributionData = data;

      // Handle referral data
      final referrerId = data['deep_link_sub1'];
      if (referrerId != null) {
        _handleReferral(referrerId, data);
      }
    });

    // Listen for first install attribution
    appsflyerSdk.onInstallConversionData((Map<String, dynamic> data) {
      _conversionData = data;

      // Check if this is coming from a referral
      final referrerId = data['deep_link_sub1'];
      if (referrerId != null) {
        _handleReferral(referrerId, data);
      }
    });

    // Listen for deep linking
    appsflyerSdk.onDeepLinking((DeepLinkResult deepLinkResult) {
      switch (deepLinkResult.status) {
        case Status.FOUND:
          // Deep link found
          final deepLinkData = deepLinkResult.deepLink;
          if (deepLinkData?.clickEvent != null) {
            final referrerId = deepLinkData?.clickEvent['deep_link_sub1'];
            if (referrerId != null) {
              _handleReferral(referrerId, deepLinkData?.clickEvent);
            }
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

  void _handleReferral(
      String referrerId, Map<String, dynamic>? attributionData) async {
    // Store the referrerId using SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('referrer_id', referrerId);

    // Save referral data to Firestore
    _saveReferralToFirestore(referrerId, attributionData);

    // Log referral event
    logEvent('referral_received', {'referrer_id': referrerId});
  }

  Future<void> _saveReferralToFirestore(
      String referrerId, Map<String, dynamic>? attributionData) async {
    try {
      // Get current user info if available
      User? currentUser = FirebaseAuth.instance.currentUser;
      String? installerId = currentUser?.uid;
      String? installerEmail = currentUser?.email;

      // Get AppsFlyer ID
      String? appsFlyerId = await getAdvertisingId();

      // Create the document data
      Map<String, dynamic> referralData = {
        'referrerId': referrerId,
        'installerId': installerId ?? 'anonymous',
        'installerEmail': installerEmail,
        'appsFlyerId': appsFlyerId,
        'attributionData': attributionData ?? {},
        'installTimestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatform(),
        'conversionData': _conversionData,
      };

      // Get a reference to the Firestore collection
      final firestore = FirebaseFirestore.instance;

      // Add a new document to the 'test' collection
      await firestore.collection('test').add(referralData);

      log('Successfully saved referral data to Firestore');
    } catch (e) {
      log('Error saving referral data to Firestore: $e');
    }
  }

  String _getPlatform() {
    return const String.fromEnvironment('dart.library.io.Platform') == 'true'
        ? 'mobile'
        : const String.fromEnvironment('dart.library.html') == 'true'
            ? 'web'
            : 'unknown';
  }

  void setCustomerUserId(String userId) {
    appsflyerSdk.setCustomerUserId(userId);
  }

  Future<bool?> logEvent(
      String eventName, Map<String, dynamic>? eventValues) async {
    return await appsflyerSdk.logEvent(eventName, eventValues);
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

  // Get attribution data
  Map<String, dynamic>? getAttributionData() {
    return _attributionData;
  }

  Map<String, dynamic>? getConversionData() {
    return _conversionData;
  }
}
