
import UIKit
import Flutter
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

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
}
  
