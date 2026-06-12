package com.aadeshkheria.inzone

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Unity bridge MethodChannel
        UnityBridge.register(flutterEngine, this)

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
