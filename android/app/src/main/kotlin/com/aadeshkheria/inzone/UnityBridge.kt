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
 *
 * All Unity classes are referenced by name only, so this file compiles even
 * when the unityLibrary export is absent (see android/app/build.gradle —
 * UnityPlayerActivity.kt is only compiled when android/unityLibrary exists).
 */
object UnityBridge : MethodChannel.MethodCallHandler {

    private const val CHANNEL = "com.inzone/unity"
    private const val UNITY_ACTIVITY = "com.aadeshkheria.inzone.UnityPlayerActivity"
    private const val UNITY_PLAYER = "com.unity3d.player.UnityPlayer"
    private lateinit var channel: MethodChannel
    private lateinit var activity: Activity

    /** True when the Unity export is bundled into this build. */
    private val unityAvailable: Boolean
        get() = try {
            Class.forName(UNITY_ACTIVITY)
            true
        } catch (e: ClassNotFoundException) {
            false
        }

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        this.activity = activity
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    // ── Flutter → Native ────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openUnity" -> {
                if (!unityAvailable) {
                    result.error(
                        "UNITY_NOT_AVAILABLE",
                        "Unity is not bundled into this Android build. " +
                            "Export the Unity project to android/unityLibrary first.",
                        null
                    )
                    return
                }
                val intent = Intent().setClassName(activity, UNITY_ACTIVITY)
                call.argument<String>("sceneName")?.let { intent.putExtra("sceneName", it) }
                call.argument<String>("catalogUrl")?.let { intent.putExtra("catalogUrl", it) }
                call.argument<String>("bundlesDir")?.let { intent.putExtra("bundlesDir", it) }
                activity.startActivity(intent)
                result.success(null)
            }
            "closeUnity" -> {
                // Tell any running UnityPlayerActivity to finish
                activity.sendBroadcast(Intent(UnityActions.CLOSE_UNITY).setPackage(activity.packageName))
                result.success(null)
            }
            "sendToUnity" -> {
                val gameObject = call.argument<String>("gameObject") ?: ""
                val methodName = call.argument<String>("methodName") ?: ""
                val message = call.argument<String>("message") ?: ""
                try {
                    Class.forName(UNITY_PLAYER)
                        .getMethod(
                            "UnitySendMessage",
                            String::class.java, String::class.java, String::class.java
                        )
                        .invoke(null, gameObject, methodName, message)
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

/** Broadcast actions shared between UnityBridge and UnityPlayerActivity. */
object UnityActions {
    const val CLOSE_UNITY = "com.inzone.CLOSE_UNITY"
}
