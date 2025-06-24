package com.aadeshkheria.inzone

import android.content.Context
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

class GroupNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(nativeAd: NativeAd, customOptions: Map<String, Any>?): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_group_tile, null) as NativeAdView

        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        val ctaView = adView.findViewById<Button>(R.id.ad_call_to_action)
        val starsView = adView.findViewById<TextView>(R.id.ad_stars)

        // Apply round clipping if supported
        val mediaCard = adView.findViewById<View>(R.id.media_card_view)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mediaCard.clipToOutline = true
            mediaCard.outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    val radius = context.resources.displayMetrics.density * 12
                    outline.setRoundRect(0, 0, view.width, view.height, radius)
                }
            }
        }

        // Set data
        headlineView.text = nativeAd.headline
        bodyView.text = nativeAd.body ?: ""
        ctaView.text = nativeAd.callToAction ?: "Install"

        val mediaContent = nativeAd.mediaContent
        if (mediaContent != null) {
            mediaView.mediaContent = mediaContent
            mediaView.visibility = View.VISIBLE
        } else {
            mediaView.visibility = View.GONE
        }


        val rating = nativeAd.starRating
        if (rating != null && rating > 0) {
            starsView.text = "★".repeat(rating.toInt()) + "☆".repeat(5 - rating.toInt())
            starsView.visibility = View.VISIBLE
        } else {
            starsView.visibility = View.GONE
        }

        adView.mediaView = mediaView
        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.callToActionView = ctaView
        adView.starRatingView = starsView

        adView.setNativeAd(nativeAd)
        return adView
    }
}
