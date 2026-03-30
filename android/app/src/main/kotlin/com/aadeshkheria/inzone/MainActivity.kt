package com.aadeshkheria.inzone

import android.Manifest
import android.content.pm.PackageManager
import android.provider.Telephony
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterFragmentActivity() {
    private val smsTrackingChannel = "inzone/sms_tracking"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsTrackingChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRecentReferralSmsRecipients" -> {
                        val referralLink = call.argument<String>("referralLink")
                        val lookbackMinutes = call.argument<Int>("lookbackMinutes") ?: 20

                        if (referralLink.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing referralLink", null)
                            return@setMethodCallHandler
                        }

                        val hasReadSms = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!hasReadSms) {
                            result.error("PERMISSION_DENIED", "READ_SMS permission not granted", null)
                            return@setMethodCallHandler
                        }

                        try {
                            result.success(getRecentRecipients(referralLink, lookbackMinutes))
                        } catch (e: Exception) {
                            result.error("SMS_QUERY_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

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

    private fun getRecentRecipients(referralLink: String, lookbackMinutes: Int): List<Map<String, Any?>> {
        val cutoffMs = System.currentTimeMillis() - lookbackMinutes * 60_000L
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )

        val recipients = linkedMapOf<String, Map<String, Any?>>()
        val cursor = contentResolver.query(
            Telephony.Sms.Sent.CONTENT_URI,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC"
        )

        cursor?.use {
            val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)

            while (it.moveToNext()) {
                val timestamp = if (dateIndex >= 0) it.getLong(dateIndex) else 0L
                if (timestamp < cutoffMs) {
                    break
                }

                val address = if (addressIndex >= 0) it.getString(addressIndex) else null
                val body = if (bodyIndex >= 0) it.getString(bodyIndex) else null

                if (!address.isNullOrBlank() && !body.isNullOrBlank() && body.contains(referralLink)) {
                    if (!recipients.containsKey(address)) {
                        recipients[address] = mapOf(
                            "address" to address,
                            "timestamp" to timestamp
                        )
                    }
                }
            }
        }

        return recipients.values.toList()
    }
}
