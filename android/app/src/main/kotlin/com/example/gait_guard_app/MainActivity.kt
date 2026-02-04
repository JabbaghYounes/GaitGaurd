package com.example.gait_guard_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Main activity for GaitGuard app.
 *
 * Initializes the platform channel for native Android communication.
 */
class MainActivity : FlutterActivity() {

    private var platformChannelHandler: PlatformChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize platform channel handler for app lock functionality
        platformChannelHandler = PlatformChannelHandler(this, flutterEngine)

        // Refresh app lock state from storage
        AppLockManager.refreshCache(this)
    }

    override fun onResume() {
        super.onResume()
        // Refresh state when app comes to foreground
        // This ensures we pick up any changes made in settings
        AppLockManager.refreshCache(this)
    }
}
