# Push Notifications Setup — Android + iOS ✅ COMPLETED

This document gives a concrete, start-to-finish checklist and code snippets to enable push notifications for both Android (FCM) and iOS (APNs via Firebase). 

## ✅ What's Already Done (Completed by Assistant)

- [x] Added Firebase Cloud Messaging background handler to `main.dart`
- [x] Added `NotificationService.initialize()` call in `main.dart` 
- [x] Updated Android root `build.gradle` with google-services classpath
- [x] Updated iOS `AppDelegate.swift` with Firebase configuration and FCM setup
- [x] Added required Android permissions for push notifications
- [x] Created test script (`test_push_notifications.dart`) to verify setup
- [x] Verified project compiles successfully

## ✅ Original Setup (Done by you)
- [x] Create / confirm a Firebase project for this app. (inzone-f93e4)
- [x] Add Android app to Firebase and download `google-services.json`.
- [x] Add iOS app to Firebase and download `GoogleService-Info.plist`.
- [x] Upload your iOS APNs Auth Key (.p8) into Firebase (or configure APNs certs).
- [x] Add the platform files to this repo (or place them into the correct platform folders):
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`

## 🚀 Final Steps to Complete (What you need to do)

### 1. iOS Xcode Configuration (Required - Must be done on macOS)
Open `ios/Runner.xcworkspace` in Xcode and:
- Select the Runner target > Signing & Capabilities
- Add "Push Notifications" capability
- Add "Background Modes" capability and enable "Remote notifications"

### 2. Test Push Notifications

#### Option A: Use our test script
```bash
flutter run test_push_notifications.dart
```
This will show you the FCM token and testing instructions.

#### Option B: Test with your main app
```bash
flutter run
```
The app will automatically request notification permissions and register the FCM token.

#### Option C: Firebase Console Testing
1. Go to Firebase Console > Cloud Messaging
2. Click "Send your first message"
3. Enter title and body
4. In "Target", select "FCM registration token"
5. Use the token from the test script or console logs
6. Send the test message

### 3. Verify Everything Works
- Build and run on a real device (simulators don't fully support push notifications)
- Check console logs for "FCM token: ..." 
- Send a test notification from Firebase Console
- Verify notification appears when app is in background/foreground

## 📱 What We Implemented

### Flutter (main.dart)
- Added Firebase background message handler
- Added NotificationService initialization
- Import statements for firebase_messaging

### Android Configuration
- Root `build.gradle`: Added google-services classpath
- App `build.gradle`: Already had google-services plugin
- `AndroidManifest.xml`: Added notification permissions
- FCM works automatically with these changes

### iOS Configuration (Code Done)
- `AppDelegate.swift`: Added Firebase configuration, FCM setup, and notification delegates
- Handles FCM token updates and notification presentation
- **Still needed**: Xcode capabilities (must be done manually)

### Notification Service
Your existing `NotificationService` class already handles:
- FCM token registration with backend
- Local notification display
- Notification channels and preferences
- Backend API integration

## 🔧 Testing Commands

```bash
# Get dependencies (if needed)
flutter pub get

# Test with our notification test app
flutter run test_push_notifications.dart

# Build and test on device
flutter run

# Build for release
flutter build apk
flutter build ios
```

## 🎯 Expected Behavior After Setup

1. **App Launch**: Requests notification permission automatically
2. **FCM Token**: Generated and logged to console
3. **Firebase Console**: Can send test messages using the token
4. **Background**: Notifications appear even when app is closed
5. **Foreground**: Notifications show as local notifications for better UX

## 🔍 Troubleshooting

### Android Issues
- Make sure `google-services.json` is in `android/app/`
- Check that applicationId matches Firebase project
- Verify google-services plugin is applied in `app/build.gradle`

### iOS Issues  
- Ensure `GoogleService-Info.plist` is added to Xcode project
- Verify Bundle ID matches Firebase iOS app
- Check that APNs key is uploaded to Firebase Console
- Must enable capabilities in Xcode (Push Notifications + Background Modes)

### General Issues
- Test on real devices, not simulators
- Check console logs for error messages
- Verify Firebase project has both Android and iOS apps configured

## 🎉 You're Ready!

The code implementation is complete. You just need to:
1. Add iOS capabilities in Xcode (2 minutes)
2. Test on a real device
3. Send test notifications from Firebase Console

Push notifications should work immediately after the iOS Xcode step!

This document gives a concrete, start-to-finish checklist and code snippets to enable push notifications for both Android (FCM) and iOS (APNs via Firebase). It assumes you already have a Firebase project (recommended) and that the app bundle id / Android applicationId are registered in that Firebase project.

Checklist
- [ ] Create / confirm a Firebase project for this app. (inzone-f93e4)
- [ ] Add Android app to Firebase and download `google-services.json`.
- [ ] Add iOS app to Firebase and download `GoogleService-Info.plist`.
- [ ] Upload your iOS APNs Auth Key (.p8) into Firebase (or configure APNs certs).
- [ ] Add the platform files to this repo (or place them into the correct platform folders):
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- [ ] Configure Android Gradle and add the plugin if not already present.
- [ ] Enable Background Modes (Remote notifications) + Push Notifications in Xcode; add entitlements.
- [ ] Add Firebase initialization and FCM background handler in Flutter `main.dart`.
- [ ] Test with Firebase Console (send test message) and with `firebase-admin` or `curl` on your backend.

High-level notes
- This project already contains a `lib/services/notification_service.dart` that handles local notifications and FCM messages. You will still need to wire the Firebase & platform configuration and add the background message handler in `main.dart`.
- Do NOT commit private credentials (APNs .p8, google-services.json with secrets) into a public repo. Keep them on your machine or in secure CI secrets.

Detailed Steps — Android

1) Add Android app to Firebase
- In Firebase console, add an Android app using your app's applicationId (see `android/app/build.gradle`).
- Download `google-services.json` and put it in `android/app/`.

2) Update Android Gradle files
- In `android/build.gradle` make sure you have:
  buildscript/dependencies {
    classpath 'com.google.gms:google-services:4.3.15' // or latest
  }

- In `android/app/build.gradle` at the bottom add:
  apply plugin: 'com.google.gms.google-services'

- Ensure `minSdkVersion` >= 19 (recommended >= 21) for firebase_messaging newer releases.

3) Add Android manifest entries
- Add the INTERNET permission (usually already present):
  <uses-permission android:name="android.permission.INTERNET" />

- In `android/app/src/main/AndroidManifest.xml` ensure you have the default launcher icon and a service entry if using older non-plugin methods. With `firebase_messaging` plugin you typically don't need to manually add the FCM service.

4) Notification icon (optional but recommended)
- Add a small monochrome notification icon in `android/app/src/main/res/drawable/` and reference it in `AndroidManifest.xml` or via `flutter_local_notifications` initialization.

5) Firebase Cloud Messaging Server credentials
- For sending messages from your backend, prefer the FCM HTTP v1 API with a Google service account. Create a service account JSON in the Firebase console (Project Settings > Service accounts), give it the `Firebase Admin` rights, and use it on your server to send messages.

Detailed Steps — iOS

1) Add iOS app to Firebase
- In Firebase console, add an iOS app with the correct Bundle ID (see `ios/Runner/Info.plist` for CFBundleIdentifier or the Xcode project settings).
- Download `GoogleService-Info.plist` and add it to `ios/Runner` (use Xcode to "Add files to Runner").

2) APNs Authentication Key (.p8) upload
- In Apple Developer portal > Keys, create a key with the "Apple Push Notifications service (APNs)" enabled. Download the `.p8` file. Note the Key ID and your Team ID.
- In Firebase console > Project Settings > Cloud Messaging, upload the `.p8` file and enter Key ID + Team ID and your App's Bundle ID. This lets Firebase send APNs messages for your app.

3) Xcode capabilities
- Open `ios/Runner.xcworkspace` in Xcode.
- Select the Runner target > Signing & Capabilities.
- Add "Push Notifications" capability.
- Add "Background Modes" capability and enable "Remote notifications".

4) Entitlements
- Confirm `ios/Runner/Runner.entitlements` contains the aps-environment key if you use manual provisioning. Xcode usually handles this when you enable capabilities.

5) AppDelegate changes (Swift example)
- If your iOS app uses Swift AppDelegate (or Objective-C), ensure Firebase is configured and FCM delegates are wired. Add the APNs registration and UNUserNotificationCenter delegate handling.

Example `ios/Runner/AppDelegate.swift` snippet:

// import statements
import UIKit
import Flutter
import Firebase
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        // handle
      }
    } else {
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// And add MessagingDelegate conformance if needed to catch token updates:
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("FCM token: \(fcmToken ?? "(nil)")")
    // send to your backend or save locally
  }
}

Important: If your Flutter project uses an Objective-C AppDelegate, apply the equivalent Objective-C changes. For apps created recently Flutter's default template uses Swift.

Flutter wiring (Dart)

1) Add background message handler in `main.dart` (very important)
- Create a top-level function (must be a top-level or static function):

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need Firebase services here, initialize Firebase
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(MyApp());
}

2) Request permission and get token in your startup code (your `NotificationService.initialize` is already doing much of this). Make sure `NotificationService.initialize()` is called after `Firebase.initializeApp()` in `main()`.

Testing

- Test on a real device. (iOS simulator doesn't support remote push delivery; some local notifications will work.)
- Use Firebase Console > Cloud Messaging to send a test message to the specific device token.
- From your backend use the Firebase Admin SDK (recommended) or the FCM HTTP v1 API. For example, with `curl` and legacy token auth (not recommended long-term) you can send to a single device with the FCM server key. Prefer using the Admin SDK with service account JSON.

Quick commands (PowerShell)

# Get dependencies
flutter pub get

# Build/debug on Android device
flutter run -d <android-device-id>

# Build for iOS (mac required)
flutter build ios

Security & CI notes
- Keep the Apple `.p8` file and Firebase service-account JSON out of source control.
- If you need CI distribution or server pushes, store credentials in your CI secret store and inject them at build/deploy time.

What I added to this repo
- `PUSH_SETUP.md` (this file) — step-by-step checklist, code snippets, and test steps.

Next steps I can take for you
- If you want, I can:
  - Add the background handler snippet into `lib/main.dart` (or create it) and wire `NotificationService.initialize()` in `main()`.
  - Add a small script or docs showing how to upload the APNs key to Firebase and where to place `GoogleService-Info.plist` / `google-services.json` locally.
  - Make safe platform edits to Android manifests / iOS AppDelegate if you want me to and you confirm backups.

Requirements coverage
- Provide steps for Android (FCM): Done (doc + code snippets).
- Provide steps for iOS (APNs + .p8 -> Firebase): Done (doc + code snippets).
- Explain where to put iOS key: Done (upload to Firebase Console > Project Settings > Cloud Messaging).

If you'd like I can now add the Flutter `main.dart` background handler and a minimal wire-up change so the app will request permissions and initialize the `NotificationService` automatically — tell me to proceed and I will edit `lib/main.dart` and run `flutter pub get`/a small static check for you.
