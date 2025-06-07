package com.aadeshkheria.inzone

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactoryMedium(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?
    ): NativeAdView {

        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ads_medium, null) as NativeAdView

        // Safely get views
        val mediaView = adView.findViewById<MediaView>(R.id.native_ad_media)
        val headlineView = adView.findViewById<TextView>(R.id.native_ad_headline)
        val bodyView = adView.findViewById<TextView>(R.id.native_ad_body)
        val iconView = adView.findViewById<ImageView>(R.id.native_ad_icon)
        val callToActionView = adView.findViewById<Button>(R.id.native_ad_button)

        // Assign views to the NativeAdView
        adView.mediaView = mediaView
        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.iconView = iconView
        adView.callToActionView = callToActionView

        // Set text and images
        headlineView.text = nativeAd.headline
        bodyView.text = nativeAd.body ?: ""

        // Handle the icon safely
        if (nativeAd.icon != null) {
            iconView.setImageDrawable(nativeAd.icon?.drawable)
            iconView.visibility = View.VISIBLE
        } else {
            iconView.visibility = View.GONE
        }

        // Set call to action
        callToActionView.text = nativeAd.callToAction ?: "Install"

        // Associate the NativeAd with the NativeAdView
        adView.setNativeAd(nativeAd)

        return adView
    }
}