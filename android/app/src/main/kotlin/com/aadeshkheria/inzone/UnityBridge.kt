package com.aadeshkheria.inzone

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter ↔ Unity via a MethodChannel.
 *
 * Flutter can call:
 *   openUnity   – launches UnityPlayerActivity
 *   closeUnity  – finishes UnityPlayerActivity
 *   sendToUnity – forwards a message to the Unity runtime
 *
 * Unity can call back into Flutter via the static helpers
 * [onUnityReady], [onUnityQuit], and [sendToFlutter].
 */
object UnityBridge : MethodChannel.MethodCallHandler {

    private const val CHANNEL = "com.inzone/unity"
    private lateinit var channel: MethodChannel
    private lateinit var activity: Activity

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        this.activity = activity
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    // ── Flutter → Native ────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openUnity" -> {
                val sceneName = call.argument<String>("sceneName")
                val intent = Intent(activity, UnityPlayerActivity::class.java)
                if (sceneName != null) {
                    intent.putExtra("sceneName", sceneName)
                }
                activity.startActivity(intent)
                result.success(null)
            }
            "closeUnity" -> {
                // Tell any running UnityPlayerActivity to finish
                activity.sendBroadcast(Intent("com.inzone.CLOSE_UNITY"))
                result.success(null)
            }
            "sendToUnity" -> {
                val gameObject = call.argument<String>("gameObject") ?: ""
                val methodName = call.argument<String>("methodName") ?: ""
                val message = call.argument<String>("message") ?: ""
                try {
                    com.unity3d.player.UnityPlayer.UnitySendMessage(
                        gameObject, methodName, message
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("UNITY_SEND_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    // ── Native → Flutter ────────────────────────────────────────────────

    fun onUnityReady() {
        if (::channel.isInitialized) {
            activity.runOnUiThread {
                channel.invokeMethod("onUnityReady", null)
            }
        }
    }

    fun onUnityQuit() {
        if (::channel.isInitialized) {
            activity.runOnUiThread {
                channel.invokeMethod("onUnityQuit", null)
            }
        }
    }

    /** Called from Unity C# via AndroidJavaObject to send data to Flutter. */
    @JvmStatic
    fun sendToFlutter(message: String) {
        if (::channel.isInitialized) {
            activity.runOnUiThread {
                channel.invokeMethod("onUnityMessage", message)
            }
        }
    }
}
