import Foundation
import google_mobile_ads
import UIKit

class GroupNativeAdFactory: NSObject, FLTNativeAdFactory {

    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]?) -> NativeAdView {
        guard let nibObjects = Bundle.main.loadNibNamed("groupTileSmall", owner: nil, options: nil),
              let adView = nibObjects.first as? NativeAdView else {
            fatalError("Could not load nib file for native ad view")
        }

        adView.backgroundColor = .clear

        // Headline
        if let headlineLabel = adView.headlineView as? UILabel {
            headlineLabel.text = nativeAd.headline
            headlineLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        }

        // Body
        if let bodyLabel = adView.bodyView as? UILabel {
            bodyLabel.text = nativeAd.body
            bodyLabel.isHidden = nativeAd.body == nil
            bodyLabel.font = UIFont.systemFont(ofSize: 12)
        }

        // CTA Button with gradient background
        if let ctaButton = adView.callToActionView as? UIButton {
            ctaButton.setTitle(nativeAd.callToAction, for: .normal)
            ctaButton.setTitleColor(.white, for: .normal)
            ctaButton.layer.cornerRadius = 8
            ctaButton.clipsToBounds = true

            // Remove previous gradient if exists
            ctaButton.layer.sublayers?.filter { $0.name == "gradientLayer" }.forEach { $0.removeFromSuperlayer() }

            let gradientLayer = CAGradientLayer()
            gradientLayer.name = "gradientLayer"
            gradientLayer.colors = [
                UIColor(red: 33/255, green: 150/255, blue: 243/255, alpha: 1).cgColor,
                UIColor(red: 63/255, green: 81/255, blue: 181/255, alpha: 1).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
            gradientLayer.frame = ctaButton.bounds
            gradientLayer.cornerRadius = 8

            ctaButton.layer.insertSublayer(gradientLayer, at: 0)
            ctaButton.layoutIfNeeded()
        }

        // Media View (ignore warning about video content size)
        if let mediaView = adView.mediaView {
            if nativeAd.mediaContent.hasVideoContent {
                mediaView.isHidden = true
            } else {
                mediaView.layer.cornerRadius = 12
                mediaView.clipsToBounds = true

                if #available(iOS 13.0, *) {
                    mediaView.backgroundColor = UITraitCollection.current.userInterfaceStyle == .dark ? .black : .white
                } else {
                    mediaView.backgroundColor = .white
                }
            }
        }

        // Star Rating
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

        // Dynamic dark/light mode support
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
