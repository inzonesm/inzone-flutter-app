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
        
        // Fluid behavior: enable hugging/compression priority
        nativeAdView.setContentHuggingPriority(UILayoutPriority(251), for: .vertical)
        nativeAdView.setContentCompressionResistancePriority(UILayoutPriority(751), for: .vertical)
        
        // Make background transparent to inherit card color
        nativeAdView.backgroundColor = UIColor.clear
        
        // Set up the ad view with a simple layout - left aligned with small margin
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4 // Reduced spacing between components
        stackView.distribution = .fill
        stackView.alignment = .leading // Left alignment instead of center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(stackView)
        
        // Setup constraints for the stack view with padding
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12), // Small left margin
            stackView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -8)
        ])
        
        // Create header container for headline and body text
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(headerContainer)
        
        // Ensure header container takes full width
        headerContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        
        // Create and add the headline label
        if let headline = nativeAd.headline {
            let headlineLabel = UILabel()
            headlineLabel.font = UIFont.boldSystemFont(ofSize: 14)
            headlineLabel.text = headline
            headlineLabel.numberOfLines = 2
            headlineLabel.textAlignment = .left // Left text alignment
            
            if #available(iOS 13.0, *) {
                nativeAdView.overrideUserInterfaceStyle = .unspecified
            }
            
            // Support dark mode for headline text
            if #available(iOS 13.0, *) {
                headlineLabel.textColor = UIColor.label
            } else {
                headlineLabel.textColor = UIColor.black
            }
            headlineLabel.translatesAutoresizingMaskIntoConstraints = false
            headerContainer.addSubview(headlineLabel)
            nativeAdView.headlineView = headlineLabel
            
            // Position headline at top of header container with left alignment and small margin
            NSLayoutConstraint.activate([
                headlineLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
                headlineLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 4),
                headlineLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -4)
            ])
            
            // Create and add the body text if available
            if let body = nativeAd.body, !body.isEmpty {
                let bodyLabel = UILabel()
                bodyLabel.font = UIFont.systemFont(ofSize: 14)
                bodyLabel.text = body
                bodyLabel.numberOfLines = 2
                bodyLabel.textAlignment = .left // Left text alignment
                
                if #available(iOS 13.0, *) {
                    nativeAdView.overrideUserInterfaceStyle = .unspecified
                }
                
                // Support dark mode for body text
                if #available(iOS 13.0, *) {
                    bodyLabel.textColor = UIColor.secondaryLabel
                } else {
                    bodyLabel.textColor = UIColor.systemGray
                }
                bodyLabel.translatesAutoresizingMaskIntoConstraints = false
                headerContainer.addSubview(bodyLabel)
                nativeAdView.bodyView = bodyLabel
                
                // Position body text below headline with minimal spacing
                NSLayoutConstraint.activate([
                    bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 0), // No spacing between headline and body
                    bodyLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 4),
                    bodyLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -4),
                    bodyLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4)
                ])
            } else {
                // If no body text, anchor headline to bottom
                NSLayoutConstraint.activate([
                    headlineLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4)
                ])
            }
        }
        
        // Create and add media view if available - takes most of the space
        if nativeAd.mediaContent != nil {
            let mediaContainer = UIView()
            mediaContainer.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(mediaContainer)
            
            let mediaView = MediaView()
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            mediaView.mediaContent = nativeAd.mediaContent
            mediaView.contentMode = .scaleAspectFit // Use scaleAspectFit to ensure content is not cut off
            mediaView.clipsToBounds = true
            mediaView.layer.cornerRadius = 12
            mediaView.layer.masksToBounds = true
            mediaContainer.addSubview(mediaView)
            nativeAdView.mediaView = mediaView
            
            // Center the media view horizontally but keep it top-aligned
            NSLayoutConstraint.activate([
                mediaView.centerXAnchor.constraint(equalTo: mediaContainer.centerXAnchor),
                mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor)
            ])
            
            // Ensure media container takes full width 
            mediaContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            
            if nativeAd.mediaContent != nil && nativeAd.mediaContent.aspectRatio > 0 {
                let aspectRatio = CGFloat(nativeAd.mediaContent.aspectRatio)
                // Set height based on aspect ratio to maintain proportions
                mediaContainer.heightAnchor.constraint(equalTo: mediaContainer.widthAnchor, multiplier: 1 / aspectRatio).isActive = true
            } else {
                // Fallback minimum height if aspect ratio is not available
                mediaContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
            }
        }
        
        // No CTA button as requested
        
        // Associate the native ad with the view
        nativeAdView.nativeAd = nativeAd
        
        return nativeAdView
    }
}
