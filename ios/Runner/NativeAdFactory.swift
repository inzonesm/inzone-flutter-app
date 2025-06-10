import Foundation
import google_mobile_ads
import UIKit

class NativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]?) -> NativeAdView {
    guard let nibObjects = Bundle.main.loadNibNamed("listTileMedium", owner: nil, options: nil),
          let adView = nibObjects.first as? NativeAdView else {
      fatalError("Could not load nib file for native ad view")
    }
    
    // Ensure background is transparent
    adView.backgroundColor = UIColor.clear

    (adView.headlineView as? UILabel)?.text = nativeAd.headline
    (adView.bodyView as? UILabel)?.text = nativeAd.body
    adView.bodyView?.isHidden = nativeAd.body == nil

    // Set call to action button style
    if let callToActionButton = adView.callToActionView as? UIButton {
      callToActionButton.setTitle(nativeAd.callToAction, for: .normal)
      
      // Apply Android-like color #3F51B5 (indigo blue)
      let androidButtonColor = UIColor(red: 63/255.0, green: 81/255.0, blue: 181/255.0, alpha: 1.0)
      
      // Check if the button has a configuration (iOS 15+)
      if #available(iOS 15.0, *) {
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.baseBackgroundColor = androidButtonColor
        buttonConfig.baseForegroundColor = UIColor.white
        buttonConfig.cornerStyle = .medium
        buttonConfig.title = nativeAd.callToAction
        callToActionButton.configuration = buttonConfig
      } else {
        // Fallback for older iOS versions
        callToActionButton.backgroundColor = androidButtonColor
        callToActionButton.setTitleColor(UIColor.clear, for: .normal)
        callToActionButton.layer.cornerRadius = 8
      }
    }
    
    adView.callToActionView?.isHidden = nativeAd.callToAction == nil

    (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
      if nativeAd.advertiser == nil {
        adView.advertiserView?.removeFromSuperview()
      }
    adView.advertiserView?.isHidden = nativeAd.advertiser == nil
    
    // Apply text colors based on dark/light mode
    updateColorsForCurrentTraitCollection(adView: adView)
    
    // Configure media view with rounded corners
      if let mediaView = adView.mediaView {
        mediaView.layer.cornerRadius = 12.0
        mediaView.layer.masksToBounds = true
        mediaView.clipsToBounds = true

        // Apply background color based on interface style
        if #available(iOS 13.0, *) {
          let userInterfaceStyle = UITraitCollection.current.userInterfaceStyle
          mediaView.backgroundColor = (userInterfaceStyle == .dark) ? UIColor.black : UIColor.white
        } else {
          mediaView.backgroundColor = UIColor.white // Default to light mode for iOS 12 and below
        }
      }


    adView.nativeAd = nativeAd

    return adView
  }
  
  private func updateColorsForCurrentTraitCollection(adView: NativeAdView) {
    // Check for dark mode in a way that's compatible with iOS 12 and below
    let isDarkMode: Bool
    
    if #available(iOS 13.0, *) {
      isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
    } else {
      // For iOS 12 and below, always use light mode colors
      isDarkMode = false
    }
    
    if isDarkMode {
      // Dark mode text colors
      (adView.headlineView as? UILabel)?.textColor = UIColor.white
      (adView.bodyView as? UILabel)?.textColor = UIColor(white: 0.7, alpha: 1.0) // Light gray
      (adView.advertiserView as? UILabel)?.textColor = UIColor(white: 0.7, alpha: 1.0)
    } else {
      // Light mode text colors
      (adView.headlineView as? UILabel)?.textColor = UIColor.black
      (adView.bodyView as? UILabel)?.textColor = UIColor(white: 0.3, alpha: 1.0) // Dark gray
      (adView.advertiserView as? UILabel)?.textColor = UIColor(white: 0.3, alpha: 1.0)
    }
  }
}
  
