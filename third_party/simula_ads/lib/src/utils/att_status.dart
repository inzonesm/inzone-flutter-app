import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// ATT (App Tracking Transparency) authorization status
enum ATTAuthorizationStatus {
  /// User has not been prompted yet
  notDetermined,
  
  /// User has authorized tracking
  authorized,
  
  /// User has denied tracking
  denied,
  
  /// Tracking is restricted (e.g., parental controls)
  restricted,
  
  /// Not applicable (Android, Web, or ATT not available)
  notApplicable,
}

/// Utility class for reading ATT status and IDFA
class ATTStatus {
  static const MethodChannel _channel = MethodChannel('simula_ads/att');

  /// Read ATT authorization status
  /// Returns the current authorization status without prompting the user
  /// Note: Chai app owns the ATT prompt, SDK only reads the status
  static Future<ATTAuthorizationStatus> getAuthorizationStatus() async {
    // Not applicable on Android or Web
    if (!Platform.isIOS || kIsWeb) {
      return ATTAuthorizationStatus.notApplicable;
    }

    try {
      final int? statusCode = await _channel.invokeMethod('getATTStatus');
      
      if (statusCode == null) {
        return ATTAuthorizationStatus.notApplicable;
      }

      // Map iOS ATTrackingManager.AuthorizationStatus enum values
      // 0 = notDetermined
      // 1 = restricted
      // 2 = denied
      // 3 = authorized
      switch (statusCode) {
        case 0:
          return ATTAuthorizationStatus.notDetermined;
        case 1:
          return ATTAuthorizationStatus.restricted;
        case 2:
          return ATTAuthorizationStatus.denied;
        case 3:
          return ATTAuthorizationStatus.authorized;
        default:
          return ATTAuthorizationStatus.notApplicable;
      }
    } catch (e) {
      // Default to notApplicable on error
      return ATTAuthorizationStatus.notApplicable;
    }
  }

  /// Get IDFA (Identifier for Advertisers) when ATT is authorized
  /// Returns null if ATT is not authorized, not applicable, or unavailable
  static Future<String?> getIDFA() async {
    // Only available on iOS when ATT is authorized
    if (!Platform.isIOS || kIsWeb) {
      return null;
    }

    try {
      // First check if ATT is authorized
      final status = await getAuthorizationStatus();
      if (status != ATTAuthorizationStatus.authorized) {
        return null;
      }

      // Get IDFA from native iOS
      final String? idfa = await _channel.invokeMethod('getIDFA');
      return idfa;
    } catch (e) {
      return null;
    }
  }

  /// Check if tracking is allowed (authorized)
  static Future<bool> isTrackingAllowed() async {
    final status = await getAuthorizationStatus();
    return status == ATTAuthorizationStatus.authorized;
  }
}
