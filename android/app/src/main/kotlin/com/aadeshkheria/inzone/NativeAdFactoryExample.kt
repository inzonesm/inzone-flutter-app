package com.aadeshkheria.inzone

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.constraintlayout.widget.ConstraintSet
import androidx.core.content.ContextCompat
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class NativeAdFactoryExample(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val nativeAdView = NativeAdView(context)
        
        // Check if dark mode is enabled
        val isDarkMode = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        
        // Make background transparent to inherit card color
        nativeAdView.setBackgroundColor(Color.TRANSPARENT)
        
        // Create main container
        val mainContainer = ConstraintLayout(context)
        mainContainer.id = View.generateViewId()
        mainContainer.layoutParams = ConstraintLayout.LayoutParams(
            ConstraintLayout.LayoutParams.MATCH_PARENT,
            ConstraintLayout.LayoutParams.MATCH_PARENT
        )
        nativeAdView.addView(mainContainer)
        
        // Create headline TextView
        val headlineView = TextView(context).apply {
            id = View.generateViewId()
            text = nativeAd.headline
            textSize = 14f
            setTypeface(null, android.graphics.Typeface.BOLD)
            maxLines = 2
            setTextColor(if (isDarkMode) Color.WHITE else Color.BLACK)
            setPadding(32, 32, 32, 8)
        }
        mainContainer.addView(headlineView)
        nativeAdView.headlineView = headlineView
        
        // Create body TextView if available
        var bodyView: TextView? = null
        if (!nativeAd.body.isNullOrEmpty()) {
            bodyView = TextView(context).apply {
                id = View.generateViewId()
                text = nativeAd.body
                textSize = 12f
                maxLines = 2
                setTextColor(if (isDarkMode) Color.parseColor("#B3B3B3") else Color.parseColor("#666666"))
                setPadding(32, 0, 32, 16)
            }
            mainContainer.addView(bodyView)
            nativeAdView.bodyView = bodyView
        }
        
        // Create media view if available
        var mediaView: com.google.android.gms.ads.nativead.MediaView? = null
        if (nativeAd.mediaContent != null) {
            mediaView = com.google.android.gms.ads.nativead.MediaView(context).apply {
                id = View.generateViewId()
                mediaContent = nativeAd.mediaContent
                
                // Create rounded corners with margin
                val drawable = GradientDrawable()
                drawable.cornerRadius = 24f
                drawable.setColor(Color.TRANSPARENT)
                background = drawable
                clipToOutline = true
                
                // Add increased margin around media view for more padding
                val layoutParams = ConstraintLayout.LayoutParams(
                    ConstraintLayout.LayoutParams.MATCH_CONSTRAINT,
                    ConstraintLayout.LayoutParams.WRAP_CONTENT
                )
                layoutParams.setMargins(48, 24, 48, 24)
                this.layoutParams = layoutParams
            }
            mainContainer.addView(mediaView)
            nativeAdView.mediaView = mediaView
        }
        
        // Create CTA button if available
        var ctaButton: Button? = null
        if (!nativeAd.callToAction.isNullOrEmpty()) {
            ctaButton = Button(context).apply {
                id = View.generateViewId()
                text = nativeAd.callToAction
                textSize = 12f
                setTypeface(null, android.graphics.Typeface.BOLD)
                setTextColor(Color.WHITE)
                
                // Create rounded button background
                val buttonDrawable = GradientDrawable()
                buttonDrawable.cornerRadius = 20f
                buttonDrawable.setColor(Color.parseColor("#4286F4"))
                background = buttonDrawable
                
                // Better button sizing and padding
                setPadding(32, 16, 32, 16)
                minWidth = 200
                minHeight = 80
                
                // Add margin to button
                val layoutParams = ConstraintLayout.LayoutParams(
                    ConstraintLayout.LayoutParams.WRAP_CONTENT,
                    ConstraintLayout.LayoutParams.WRAP_CONTENT
                )
                layoutParams.setMargins(32, 16, 32, 32)
                this.layoutParams = layoutParams
            }
            mainContainer.addView(ctaButton)
            nativeAdView.callToActionView = ctaButton
        }
        
        // Set up constraints
        val constraintSet = ConstraintSet()
        constraintSet.clone(mainContainer)
        
        // Headline constraints
        constraintSet.connect(headlineView.id, ConstraintSet.TOP, ConstraintSet.PARENT_ID, ConstraintSet.TOP)
        constraintSet.connect(headlineView.id, ConstraintSet.START, ConstraintSet.PARENT_ID, ConstraintSet.START)
        constraintSet.connect(headlineView.id, ConstraintSet.END, ConstraintSet.PARENT_ID, ConstraintSet.END)
        
        // Body constraints (if exists)
        if (bodyView != null) {
            constraintSet.connect(bodyView.id, ConstraintSet.TOP, headlineView.id, ConstraintSet.BOTTOM)
            constraintSet.connect(bodyView.id, ConstraintSet.START, ConstraintSet.PARENT_ID, ConstraintSet.START)
            constraintSet.connect(bodyView.id, ConstraintSet.END, ConstraintSet.PARENT_ID, ConstraintSet.END)
        }
        
        // Media view constraints (if exists)
        if (mediaView != null) {
            val topAnchor = bodyView?.id ?: headlineView.id
            constraintSet.connect(mediaView.id, ConstraintSet.TOP, topAnchor, ConstraintSet.BOTTOM)
            constraintSet.connect(mediaView.id, ConstraintSet.START, ConstraintSet.PARENT_ID, ConstraintSet.START)
            constraintSet.connect(mediaView.id, ConstraintSet.END, ConstraintSet.PARENT_ID, ConstraintSet.END)
            
            if (ctaButton != null) {
                constraintSet.connect(mediaView.id, ConstraintSet.BOTTOM, ctaButton.id, ConstraintSet.TOP)
            } else {
                constraintSet.connect(mediaView.id, ConstraintSet.BOTTOM, ConstraintSet.PARENT_ID, ConstraintSet.BOTTOM)
            }
        }
        
        // CTA button constraints (if exists)
        if (ctaButton != null) {
            constraintSet.connect(ctaButton.id, ConstraintSet.END, ConstraintSet.PARENT_ID, ConstraintSet.END)
            constraintSet.connect(ctaButton.id, ConstraintSet.BOTTOM, ConstraintSet.PARENT_ID, ConstraintSet.BOTTOM)
        }
        
        constraintSet.applyTo(mainContainer)
        
        // Associate the native ad with the view
        nativeAdView.setNativeAd(nativeAd)
        
        return nativeAdView
    }
} 