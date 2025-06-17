import Foundation
import google_mobile_ads
import UIKit

class GroupNativeAdFactory: NSObject, FLTNativeAdFactory {
    
    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]?) -> NativeAdView {
        guard let nibObjects = Bundle.main.loadNibNamed("groupTileMedium", owner: nil, options: nil),
              let adView = nibObjects.first as? NativeAdView else {
            fatalError("Could not load nib file for native ad view")
        }

        adView.backgroundColor = .clear
        
        // Headline
        if let headlineLabel = adView.headlineView as? UILabel {
            headlineLabel.text = nativeAd.headline
        }

        // Body
        if let bodyLabel = adView.bodyView as? UILabel {
            bodyLabel.text = nativeAd.body
            bodyLabel.isHidden = nativeAd.body == nil
        }

        // CTA Button (Install)
        if let ctaButton = adView.callToActionView as? UIButton {
            ctaButton.setTitle(nativeAd.callToAction, for: .normal)
            let blue = UIColor(red: 63/255, green: 81/255, blue: 181/255, alpha: 1.0)

            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.filled()
                config.baseBackgroundColor = blue
                config.baseForegroundColor = .white
                config.cornerStyle = .medium
                config.title = nativeAd.callToAction
                ctaButton.configuration = config
            } else {
                ctaButton.backgroundColor = blue
                ctaButton.setTitleColor(.white, for: .normal)
                ctaButton.layer.cornerRadius = 8
            }
        }

        // Media View (정사각형 이미지)
        if let mediaView = adView.mediaView {
            mediaView.layer.cornerRadius = 12
            mediaView.clipsToBounds = true

            if #available(iOS 13.0, *) {
                mediaView.backgroundColor = UITraitCollection.current.userInterfaceStyle == .dark ? .black : .white
            } else {
                mediaView.backgroundColor = .white
            }
        }

        // Star Rating View (Unicode 별점 ★★★★☆)
        if let starRating = nativeAd.starRating?.doubleValue,
           let starLabel = adView.starRatingView as? UILabel {
            let clamped = min(max(Int(round(starRating)), 0), 5)
            let stars = String(repeating: "★", count: clamped) + String(repeating: "☆", count: 5 - clamped)
            starLabel.text = stars
            starLabel.textColor = .systemYellow
            starLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        } else {
            adView.starRatingView?.isHidden = true
        }

        // Apply dark/light mode colors
        applyDynamicTextColors(to: adView)
        
        adView.nativeAd = nativeAd
        return adView
    }
    
    private func applyDynamicTextColors(to adView: NativeAdView) {
        let isDark: Bool
        if #available(iOS 13.0, *) {
            isDark = UITraitCollection.current.userInterfaceStyle == .dark
        } else {
            isDark = false
        }

        let primaryColor = isDark ? UIColor.white : UIColor.black
        let secondaryColor = isDark ? UIColor(white: 0.7, alpha: 1.0) : UIColor(white: 0.3, alpha: 1.0)

        (adView.headlineView as? UILabel)?.textColor = primaryColor
        (adView.bodyView as? UILabel)?.textColor = secondaryColor
        (adView.starRatingView as? UILabel)?.textColor = .systemYellow
    }
}
