package com.aadeshkheria.inzone

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.unity3d.player.UnityPlayer
import com.unity3d.player.UnityPlayerActivity as BaseUnityPlayerActivity

/**
 * Thin wrapper around Unity's own UnityPlayerActivity.
 *
 * When the user presses back or Unity calls Application.Quit(),
 * we finish this activity and return to Flutter.
 */
class UnityPlayerActivity : BaseUnityPlayerActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Forward the "ready" event to Flutter via the bridge
        UnityBridge.onUnityReady()

        // If Flutter requested a specific scene, tell the AddressableSceneLoader
        // GameObject inside Unity to load it. We delay so the GO has time to exist.
        val sceneName = intent.getStringExtra("sceneName")
        if (!sceneName.isNullOrEmpty()) {
            Handler(Looper.getMainLooper()).postDelayed({
                UnityPlayer.UnitySendMessage(
                    "AddressableSceneLoader", "LoadScene", sceneName
                )
            }, 2500)
        }
    }

    override fun onDestroy() {
        UnityBridge.onUnityQuit()
        super.onDestroy()
    }

    @Deprecated("Use onBackPressedDispatcher")
    override fun onBackPressed() {
        // Return to Flutter instead of quitting the app
        finish()
    }
}
