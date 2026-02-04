package com.example.gait_guard_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Lock overlay activity that displays the gait authentication UI.
 *
 * This activity:
 * - Extends FlutterActivity to embed a Flutter view
 * - Routes to the /lock_overlay Flutter screen
 * - Prevents back button from dismissing (goes to home instead)
 * - Listens for unlock broadcasts to dismiss when auth succeeds
 * - Excludes from recent apps for security
 */
class LockOverlayActivity : FlutterActivity() {

    companion object {
        private const val TAG = "LockOverlayActivity"
        private const val LOCK_CHANNEL = "com.example.gait_guard_app/lock_overlay"
    }

    private lateinit var packageName_: String
    private lateinit var displayName: String
    private var lockChannel: MethodChannel? = null

    private val unlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val unlockedPackage = intent?.getStringExtra("package_name")
            if (unlockedPackage == packageName_) {
                Log.d(TAG, "Received unlock for $packageName_, dismissing overlay")
                finishAndAllowAccess()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Get intent extras before super.onCreate
        packageName_ = intent.getStringExtra("package_name") ?: ""
        displayName = intent.getStringExtra("display_name") ?: packageName_

        super.onCreate(savedInstanceState)

        Log.d(TAG, "Lock overlay created for: $displayName ($packageName_)")

        // Register unlock receiver
        val filter = IntentFilter("com.example.gait_guard_app.UNLOCK_APP")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(unlockReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(unlockReceiver, filter)
        }

        // Notify Flutter that overlay is shown
        PlatformChannelHandler.instance?.notifyLockOverlayShown(packageName_)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup method channel for lock overlay communication
        lockChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCK_CHANNEL
        )

        lockChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLockedAppInfo" -> {
                    result.success(mapOf(
                        "packageName" to packageName_,
                        "displayName" to displayName
                    ))
                }
                "onAuthenticationSuccess" -> {
                    onAuthenticationSuccess()
                    result.success(true)
                }
                "onAuthenticationFailed" -> {
                    onAuthenticationFailed()
                    result.success(true)
                }
                "onCancel" -> {
                    onCancel()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getInitialRoute(): String {
        // Route to the lock overlay screen with package info
        return "/lock_overlay?package=$packageName_&name=$displayName"
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(unlockReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
        lockChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }

    /**
     * Handle back button - go to home instead of dismissing.
     */
    override fun onBackPressed() {
        goToHome()
    }

    /**
     * Also intercept hardware back key.
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            goToHome()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    /**
     * Go to home screen (used when user wants to cancel).
     */
    private fun goToHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()

        // Notify Flutter
        PlatformChannelHandler.instance?.notifyLockOverlayDismissed(packageName_, "cancelled")
    }

    /**
     * Called when gait authentication succeeds.
     */
    private fun onAuthenticationSuccess() {
        Log.d(TAG, "Authentication successful for $packageName_")

        // Unlock the app
        AppLockManager.unlockApp(this, packageName_)

        // Finish overlay and let user access the app
        finishAndAllowAccess()
    }

    /**
     * Called when gait authentication fails.
     */
    private fun onAuthenticationFailed() {
        Log.d(TAG, "Authentication failed for $packageName_")
        // Stay on lock screen, user can try again or cancel
    }

    /**
     * Called when user cancels authentication.
     */
    private fun onCancel() {
        Log.d(TAG, "User cancelled authentication for $packageName_")
        goToHome()
    }

    /**
     * Finish the overlay and allow access to the protected app.
     */
    private fun finishAndAllowAccess() {
        Log.d(TAG, "Allowing access to $packageName_")

        // Notify Flutter
        PlatformChannelHandler.instance?.notifyLockOverlayDismissed(packageName_, "authenticated")

        // Just finish - the protected app should still be in the background
        finish()
    }
}
