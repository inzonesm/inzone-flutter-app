
import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Configure Firebase
    FirebaseApp.configure()
    
    // Set up notifications
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self
    
    // Request notification permission
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if granted {
        print("✅ iOS notification permission granted")
      } else {
        print("❌ iOS notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
      }
    }
    
    // Register for remote notifications
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    let factory = NativeAdFactory()
    let groupfactory = GroupNativeAdFactory()

    // Pass 'self' as the registry, not binaryMessenger
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "listTileMedium",
      nativeAdFactory: factory
    )
      
      FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
           self,
           factoryId: "groupTileSmall",
           nativeAdFactory: groupfactory
         )


    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle APNs token registration
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("📱 APNs device token received")
    Messaging.messaging().apnsToken = deviceToken
  }
  
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📱 FCM token updated: \(fcmToken ?? "nil")")
    
    // Send token to your backend here if needed
    // You can also access this token in Flutter via FirebaseMessaging.instance.getToken()
  }
}

// MARK: - UNUserNotificationCenterDelegate  
extension AppDelegate {
  // Handle foreground notifications
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                            willPresent notification: UNNotification,
                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Show notification even when app is in foreground
    completionHandler([.alert, .badge, .sound])
  }
  
  // Handle notification taps
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse,
                            withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("📱 Notification tapped with data: \(userInfo)")
    
    completionHandler()
  }
}
  
