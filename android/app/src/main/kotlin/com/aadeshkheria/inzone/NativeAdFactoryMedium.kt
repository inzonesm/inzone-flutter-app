package com.aadeshkheria.inzone

import android.content.Context
import android.content.res.Configuration
import android.graphics.Outline
import android.os.Build
import android.view.LayoutInflater
import android.view.View
import android.view.ViewOutlineProvider
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
        val callToActionView = adView.findViewById<Button>(R.id.native_ad_button)
        val advertiserView = adView.findViewById<TextView>(R.id.ad_advertiser)
        
        // Apply rounded corners to MediaView
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                // Get the CardView that wraps the MediaView
                val cardView = adView.findViewById<View>(R.id.media_card_view)
                
                // Only proceed if cardView is not null
                if (cardView != null) {
                    // Ensure the cardView clips its content
                    cardView.clipToOutline = true
                    
                    // Add outline provider for clipping
                    cardView.outlineProvider = object : ViewOutlineProvider() {
                        override fun getOutline(view: View, outline: Outline) {
                            // Round all corners by 12dp
                            val cornerRadius = context.resources.displayMetrics.density * 12
                            outline.setRoundRect(0, 0, view.width, view.height, cornerRadius)
                        }
                    }
                    
                    // Force the view to redraw with the new outline
                    cardView.invalidateOutline()
                }
            } catch (e: Exception) {
                // Log the error but don't crash
                e.printStackTrace()
            }
        }
        
        // Determine if we're in dark mode
        val isDarkMode = (context.resources.configuration.uiMode and 
            Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        // Explicitly set text colors based on theme
        try {
            if (isDarkMode) {
                headlineView?.setTextColor(context.resources.getColor(R.color.ad_text_primary_dark))
                bodyView?.setTextColor(context.resources.getColor(R.color.ad_text_secondary_dark))
                advertiserView?.setTextColor(context.resources.getColor(R.color.ad_text_secondary_dark))
                callToActionView?.setTextColor(context.resources.getColor(R.color.ad_button_text_dark))
            } else {
                headlineView?.setTextColor(context.resources.getColor(R.color.ad_text_primary_light))
                bodyView?.setTextColor(context.resources.getColor(R.color.ad_text_secondary_light))
                advertiserView?.setTextColor(context.resources.getColor(R.color.ad_text_secondary_light))
                callToActionView?.setTextColor(context.resources.getColor(R.color.ad_button_text_light))
            }
        } catch (e: Exception) {
            // Log the error but don't crash
            e.printStackTrace()
        }

        // Assign views to the NativeAdView
        adView.mediaView = mediaView
        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.callToActionView = callToActionView
        adView.advertiserView = advertiserView

        // Set text and images
        headlineView?.text = nativeAd.headline
        bodyView?.text = nativeAd.body ?: ""
        
        // Set advertiser if available
        if (nativeAd.advertiser != null) {
            advertiserView?.text = nativeAd.advertiser
            advertiserView?.visibility = View.VISIBLE
        } else {
            advertiserView?.visibility = View.GONE
        }

        // Set call to action
        callToActionView?.text = nativeAd.callToAction ?: "Install"
        
        // Associate the NativeAd with the NativeAdView
        adView.setNativeAd(nativeAd)

        return adView
    }
}