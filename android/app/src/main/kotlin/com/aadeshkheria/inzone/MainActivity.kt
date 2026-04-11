package com.aadeshkheria.inzone

import android.os.Bundle
import com.appodeal.ads.Appodeal
import com.appodeal.ads.initializing.ApdInitializationCallback
import com.appodeal.ads.initializing.ApdInitializationError
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val adTypes = Appodeal.BANNER or Appodeal.INTERSTITIAL or Appodeal.REWARDED_VIDEO
        Appodeal.initialize(
            this,
            "6f0ca10375ecff6b10f7382c618c9991282ecb2e5e5aa1ab",
            adTypes,
            object : ApdInitializationCallback {
                override fun onInitializationFinished(errors: List<ApdInitializationError>?) {
                }
            }
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

         GoogleMobileAdsPlugin.registerNativeAdFactory(
             flutterEngine, "listTileMedium",
             NativeAdFactoryMedium(this)
         )

        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, "groupTileSmall",
            GroupNativeAdFactory(this)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)

        // GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTileMedium")

        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "groupTileSmall")
    }
}
