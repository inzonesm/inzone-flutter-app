package com.aadeshkheria.inzone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.unity3d.player.UnityPlayer
import com.unity3d.player.UnityPlayerActivity as BaseUnityPlayerActivity
import org.json.JSONObject

/**
 * Thin wrapper around Unity's own UnityPlayerActivity.
 *
 * Lives in android/app/unity-src/, which is only added as a source dir when
 * the unityLibrary export exists (see build.gradle) — that keeps Android
 * builds working before the Unity project has been exported.
 *
 * When the user presses back or Unity calls Application.Quit(),
 * we finish this activity and return to Flutter.
 */
class UnityPlayerActivity : BaseUnityPlayerActivity() {

    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Let UnityBridge.closeUnity() finish this activity from Flutter
        val filter = IntentFilter(UnityActions.CLOSE_UNITY)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(closeReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(closeReceiver, filter)
        }

        // Forward the "ready" event to Flutter via the bridge
        UnityBridge.onUnityReady()

        // If Flutter requested a specific scene, send the LoadScene message
        // to Unity as a JSON payload. Delay so the GameObject has time to exist.
        val sceneName = intent.getStringExtra("sceneName")
        val catalogUrl = intent.getStringExtra("catalogUrl")
        val bundlesDir = intent.getStringExtra("bundlesDir")
        if (!sceneName.isNullOrEmpty()) {
            val payload = JSONObject().apply {
                put("sceneName", sceneName)
                if (!catalogUrl.isNullOrEmpty()) put("catalogUrl", catalogUrl)
                if (!bundlesDir.isNullOrEmpty()) put("bundlesDir", bundlesDir)
            }.toString()
            Handler(Looper.getMainLooper()).postDelayed({
                UnityPlayer.UnitySendMessage(
                    "AddressableSceneLoader", "LoadScene", payload
                )
            }, 2500)
        }
    }

    override fun onDestroy() {
        unregisterReceiver(closeReceiver)
        UnityBridge.onUnityQuit()
        super.onDestroy()
    }

    @Deprecated("Use onBackPressedDispatcher")
    override fun onBackPressed() {
        // Return to Flutter instead of quitting the app
        finish()
    }
}
