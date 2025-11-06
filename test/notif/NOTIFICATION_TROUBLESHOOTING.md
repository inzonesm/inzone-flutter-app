# Push Notification Troubleshooting Guide

## 🚨 Why Notifications Aren't Showing on Emulator

**The main issue:** Android emulators **DO NOT support Firebase Cloud Messaging (FCM)** out of the box because:

1. **No Google Play Services**: Most emulators don't have proper Google Play Services
2. **No FCM Connection**: FCM requires a real Google account and Play Services
3. **Emulator Limitations**: Push notifications need real device connectivity

## ✅ Solutions to Test Push Notifications

### Option 1: Use Real Android Device (RECOMMENDED)
```bash
# Connect your Android phone via USB
# Enable Developer Options and USB Debugging
flutter run
```

### Option 2: Use Google Play Emulator
1. Create a new AVD with **Google Play** (not just Google APIs)
2. Use system images that include "Google Play"
3. Sign in with real Google account in emulator

### Option 3: Test Local Notifications Only
We can test local notifications which work on emulator:

```dart
// Add this to test local notifications
await _localNotifications.show(
  0,
  'Test Local Notification',
  'This tests local notifications only',
  NotificationDetails(
    android: AndroidNotificationDetails(
      'test_channel',
      'Test Channel',
      importance: Importance.high,
    ),
  ),
);
```

## 🔧 What You Should See on Real Device

1. **Permission Request**: App asks for notification permission
2. **FCM Token**: Printed in console logs
3. **Firebase Console**: Can send test messages using token
4. **Background/Foreground**: Notifications appear in both states

## 📱 How to Test on Real Device

1. **Connect Phone**: USB cable + USB debugging enabled
2. **Run App**: `flutter run` and select your device
3. **Check Logs**: Look for "FCM token: ..." in console
4. **Send Test**: Use Firebase Console > Cloud Messaging
5. **Verify**: Notification should appear on your phone

## 🛠️ Quick Local Notification Test

I can create a simple test that works on emulator - this tests the notification display system without FCM:

```dart
// Test button to show local notification
ElevatedButton(
  onPressed: () async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Test Notification',
      'This is a local test notification',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel_id',
          'Test Channel',
          channelDescription: 'Channel for test notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  },
  child: Text('Test Local Notification'),
)
```

## 🎯 The Real Test

**For actual push notifications, you MUST test on:**
- Real Android device with Google Play Services
- iOS device (real iPhone, not simulator for full testing)
- Android emulator with Google Play (properly configured)

**Emulators are mainly for UI/layout testing, not push notifications.**

Would you like me to:
1. Create a local notification test that works on emulator?
2. Help you set up testing on a real device?
3. Create a Google Play emulator configuration guide?
