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

        final referrerId = mapData['deep_link_sub1'];
        if (referrerId != null) {
          _handleReferral(referrerId, mapData);
        }
      } catch (e) {
        log('Error parsing onAppOpenAttribution data: $e');
      }
    });

    appsflyerSdk.onInstallConversionData((dynamic data) {
      try {
        final Map<String, dynamic> mapData = Map<String, dynamic>.from(data);
        _conversionData = mapData;

        final referrerId = mapData['deep_link_sub1'];
        if (referrerId != null) {
          _handleReferral(referrerId, mapData);
        }
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
          if (attributionDataString != null && attributionDataString.isNotEmpty) {
            // Convert string representation back to map (simple approach)
            // This is a simple implementation and may need improvement for complex objects
            attributionData = {'stored_data': attributionDataString};
          }
          
          // Save to Firestore with complete user details
          await _saveReferralToFirestore(referrerId, attributionData, currentUser);
          
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

  Future<void> _saveReferralToFirestore(
      String referrerId, Map<String, dynamic>? attributionData, User user) async {
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
        'installerCreationTime': user.metadata.creationTime?.millisecondsSinceEpoch,
        'installerLastSignInTime': user.metadata.lastSignInTime?.millisecondsSinceEpoch,
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

      log('Successfully saved referral data to Firestore with complete user details');
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
