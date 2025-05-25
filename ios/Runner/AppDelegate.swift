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
        
        // Set up the ad view with a simple layout - no padding
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(stackView)
        
        // Setup constraints for the stack view - no padding
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor)
        ])
        
        // Create header container for headline and body text
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.heightAnchor.constraint(equalToConstant: 60).isActive = true
        stackView.addArrangedSubview(headerContainer)
        
        // Create and add the headline label
        if let headline = nativeAd.headline {
            let headlineLabel = UILabel()
            headlineLabel.font = UIFont.boldSystemFont(ofSize: 14)
            headlineLabel.text = headline
            headlineLabel.numberOfLines = 2
            headlineLabel.textColor = UIColor.black
            headlineLabel.translatesAutoresizingMaskIntoConstraints = false
            headerContainer.addSubview(headlineLabel)
            nativeAdView.headlineView = headlineLabel
            
            // Position headline at top of header container
            NSLayoutConstraint.activate([
                headlineLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
                headlineLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 8),
                headlineLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -8)
            ])
            
            // Create and add the body text if available
            if let body = nativeAd.body, !body.isEmpty {
                let bodyLabel = UILabel()
                bodyLabel.font = UIFont.systemFont(ofSize: 14)
                bodyLabel.text = body
                bodyLabel.numberOfLines = 2
                bodyLabel.textColor = UIColor.systemGray
                bodyLabel.translatesAutoresizingMaskIntoConstraints = false
                headerContainer.addSubview(bodyLabel)
                nativeAdView.bodyView = bodyLabel
                
                // Position body text below headline
                NSLayoutConstraint.activate([
                    bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 2),
                    bodyLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 8),
                    bodyLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -8)
                ])
            }
        }
        
        // Create and add media view if available - takes most of the space
        if nativeAd.mediaContent != nil {
            let mediaView = MediaView()
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            mediaView.mediaContent = nativeAd.mediaContent
            mediaView.contentMode = .scaleAspectFill
            mediaView.clipsToBounds = true
            mediaView.layer.cornerRadius = 12
            mediaView.layer.masksToBounds = true
            stackView.addArrangedSubview(mediaView)
            nativeAdView.mediaView = mediaView
            
            // Make media view flexible and take most space
            mediaView.setContentHuggingPriority(UILayoutPriority(249), for: .vertical)
            mediaView.setContentCompressionResistancePriority(UILayoutPriority(749), for: .vertical)
        }
        
        // Create footer container for CTA button
        let footerContainer = UIView()
        footerContainer.translatesAutoresizingMaskIntoConstraints = false
        footerContainer.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.addArrangedSubview(footerContainer)
        
        // Create and add the call to action button if available
        if let callToAction = nativeAd.callToAction, !callToAction.isEmpty {
            let ctaButton = UIButton(type: .system)
            ctaButton.setTitle(callToAction, for: .normal)
            ctaButton.setTitleColor(.white, for: .normal)
            ctaButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
            ctaButton.backgroundColor = UIColor(red: 0.259, green: 0.522, blue: 0.957, alpha: 1.0) // #4286F4
            ctaButton.layer.cornerRadius = 6
            ctaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            ctaButton.translatesAutoresizingMaskIntoConstraints = false
            footerContainer.addSubview(ctaButton)
            nativeAdView.callToActionView = ctaButton
            
            // Position CTA button on the right
            NSLayoutConstraint.activate([
                ctaButton.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -8),
                ctaButton.centerYAnchor.constraint(equalTo: footerContainer.centerYAnchor),
                ctaButton.heightAnchor.constraint(equalToConstant: 36),
                ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
            ])
        }
        
        // Associate the native ad with the view
        nativeAdView.nativeAd = nativeAd
        
        return nativeAdView
  }
}
