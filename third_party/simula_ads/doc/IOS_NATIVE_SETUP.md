# iOS Native Setup for ATT and IDFA

This document describes the required native iOS implementation for ATT (App Tracking Transparency) and IDFA support.

## Overview

The Flutter SDK uses platform channels to read ATT status and IDFA from iOS. The native iOS code must be added to the host app (Chai app) to enable this functionality.

## Required Implementation

### 1. AppDelegate Setup (Swift)

Add the following to your `AppDelegate.swift`:

```swift
import Flutter
import AppTrackingTransparency
import AdSupport

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let attChannel = FlutterMethodChannel(name: "simula_ads/att",
                                         binaryMessenger: controller.binaryMessenger)
    
    attChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getATTStatus" {
        if #available(iOS 14, *) {
          let status = ATTrackingManager.trackingAuthorizationStatus
          result(status.rawValue)
        } else {
          // iOS < 14: Assume authorized (ATT not available)
          result(3) // authorized
        }
      } else if call.method == "getIDFA" {
        if #available(iOS 14, *) {
          let status = ATTrackingManager.trackingAuthorizationStatus
          if status == .authorized {
            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            // Return IDFA only if not "00000000-0000-0000-0000-000000000000" (limit ad tracking)
            if idfa != "00000000-0000-0000-0000-000000000000" {
              result(idfa)
            } else {
              result(nil)
            }
          } else {
            result(nil)
          }
        } else {
          // iOS < 14: Return IDFA if available
          let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
          if idfa != "00000000-0000-0000-0000-000000000000" {
            result(idfa)
          } else {
            result(nil)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 2. Info.plist Configuration

Add the following to your `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use your device's advertising identifier to provide personalized ads and measure ad performance. This helps us keep our service free.</string>
```

**Important**: Chai app owns the ATT prompt. The SDK only reads the status. You must show the ATT prompt using `ATTrackingManager.requestTrackingAuthorization` when appropriate in your app flow.

### 3. Required Frameworks

Ensure your iOS project includes:
- `AppTrackingTransparency.framework` (iOS 14+)
- `AdSupport.framework`

These are automatically included when you add the native code above.

## ATT Status Values

The native code returns integer values that map to ATT status:

- `0` = `.notDetermined` - User hasn't been prompted yet
- `1` = `.restricted` - Tracking is restricted (e.g., parental controls)
- `2` = `.denied` - User denied tracking
- `3` = `.authorized` - User authorized tracking

## IDFA Format

IDFA is a UUID string (e.g., `"12345678-1234-1234-1234-123456789ABC"`).

If the IDFA is all zeros (`"00000000-0000-0000-0000-000000000000"`), it means Limit Ad Tracking is enabled and should be treated as unavailable.

## Testing

1. Test on a physical iOS device (simulator doesn't support ATT properly)
2. Reset ATT status between tests: Settings > Privacy & Security > Tracking
3. Test all authorization states:
   - Not determined (before prompt)
   - Authorized (after granting)
   - Denied (after denying)

## Notes

- The SDK never shows the ATT prompt - Chai app must handle this
- IDFA is only collected when ATT status is `.authorized`
- On iOS < 14, IDFA may be available without ATT (treated as authorized)
- The SDK gracefully handles cases where ATT/IDFA is unavailable
