import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register the native ad factory
    let factory = NativeAdFactoryExample()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        self, 
        factoryId: "adFactoryExample", 
        nativeAdFactory: factory
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// Native Ad Factory implementation
class NativeAdFactoryExample: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable: Any]?) -> NativeAdView {
        // Create a simple native ad view
        let nativeAdView = NativeAdView()
        nativeAdView.backgroundColor = UIColor.white
        
        // Set up the ad view with a simple layout
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(stackView)
        
        // Setup constraints for the stack view
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -16)
        ])
        
        // Add a small "Ad" label at the top
        let adLabel = UILabel()
        adLabel.text = "Ad"
        adLabel.font = UIFont.systemFont(ofSize: 10)
        adLabel.textColor = UIColor.gray
        adLabel.textAlignment = .center
        adLabel.backgroundColor = UIColor.lightGray
        adLabel.layer.cornerRadius = 4
        adLabel.layer.masksToBounds = true
        stackView.addArrangedSubview(adLabel)
        
        // Create and add the headline label
        if let headline = nativeAd.headline {
            let headlineLabel = UILabel()
            headlineLabel.font = UIFont.boldSystemFont(ofSize: 16)
            headlineLabel.text = headline
            headlineLabel.numberOfLines = 2
            headlineLabel.textColor = UIColor.black
            stackView.addArrangedSubview(headlineLabel)
            nativeAdView.headlineView = headlineLabel
        }
        
        // Create and add the body text if available
        if let body = nativeAd.body, !body.isEmpty {
            let bodyLabel = UILabel()
            bodyLabel.font = UIFont.systemFont(ofSize: 14)
            bodyLabel.text = body
            bodyLabel.numberOfLines = 3
            bodyLabel.textColor = UIColor.darkGray
            stackView.addArrangedSubview(bodyLabel)
            nativeAdView.bodyView = bodyLabel
        }
        
        // Create and add media view if available
        if nativeAd.mediaContent != nil {
            let mediaView = MediaView()
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            mediaView.heightAnchor.constraint(equalToConstant: 120).isActive = true
            mediaView.mediaContent = nativeAd.mediaContent
            stackView.addArrangedSubview(mediaView)
            nativeAdView.mediaView = mediaView
        }
        
        // Create and add the call to action button if available
        if let callToAction = nativeAd.callToAction, !callToAction.isEmpty {
            let ctaButton = UIButton(type: .system)
            ctaButton.setTitle(callToAction, for: .normal)
            ctaButton.setTitleColor(.white, for: .normal)
            ctaButton.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // systemBlue equivalent
            ctaButton.layer.cornerRadius = 8
            ctaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            ctaButton.isUserInteractionEnabled = false
            stackView.addArrangedSubview(ctaButton)
            nativeAdView.callToActionView = ctaButton
        }
        
        // Associate the native ad with the view
        nativeAdView.nativeAd = nativeAd
        
        return nativeAdView
    }
}
