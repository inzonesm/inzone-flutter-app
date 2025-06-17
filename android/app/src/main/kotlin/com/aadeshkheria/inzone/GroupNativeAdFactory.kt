package com.aadeshkheria.inzone

import android.content.Context
import android.view.LayoutInflater
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import java.util.*

class GroupNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
            nativeAd: NativeAd,
            customOptions: Map<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
                .inflate(R.layout.native_ad_group_tile, null) as NativeAdView

        // Associate the native ad view with the ad object.
        nativeAdView.setNativeAd(nativeAd)

        // Find and populate the ad views.
        nativeAdView.mediaView = nativeAdView.findViewById(R.id.ad_media)
        nativeAdView.headlineView = nativeAdView.findViewById(R.id.ad_headline)
        nativeAdView.bodyView = nativeAdView.findViewById(R.id.ad_body)
        nativeAdView.callToActionView = nativeAdView.findViewById(R.id.ad_call_to_action)
        nativeAdView.iconView = nativeAdView.findViewById(R.id.ad_icon)
        nativeAdView.starRatingView = nativeAdView.findViewById(R.id.ad_stars)

        // Populate the views with ad data.
        val mediaContent = nativeAd.mediaContent
        if (mediaContent == null) {
            nativeAdView.mediaView?.visibility = android.view.View.GONE
        } else {
            nativeAdView.mediaView?.mediaContent = mediaContent
            nativeAdView.mediaView?.visibility = android.view.View.VISIBLE
        }
        
        (nativeAdView.headlineView as? TextView)?.text = nativeAd.headline
        (nativeAdView.bodyView as? TextView)?.text = nativeAd.body
        (nativeAdView.callToActionView as? Button)?.text = nativeAd.callToAction
        // (nativeAdView.iconView as? ImageView)?.setImageDrawable(nativeAd.icon?.drawable)
        
        // Star rating
        val starRating = nativeAd.starRating
        if (starRating != null && starRating > 0) {
            (nativeAdView.starRatingView as? TextView)?.text = "★".repeat(starRating.toInt()) + "☆".repeat(5 - starRating.toInt())
        } else {
            nativeAdView.starRatingView?.visibility = android.view.View.GONE
        }
        
        return nativeAdView
    }
}
