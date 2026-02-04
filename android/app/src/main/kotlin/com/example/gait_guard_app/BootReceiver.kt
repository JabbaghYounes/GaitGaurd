package com.example.gait_guard_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Broadcast receiver that handles device boot completion.
 *
 * When the device boots up, this receiver:
 * 1. Refreshes the app lock state from storage
 * 2. The Accessibility Service will restart automatically if it was enabled
 *
 * Note: The Accessibility Service is managed by the system and will restart
 * automatically if it was enabled before reboot. This receiver just ensures
 * our app state is properly initialized.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GaitGuardBootReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON") {

            Log.d(TAG, "Device boot completed, refreshing app lock state")

            // Refresh the app lock state from storage
            AppLockManager.refreshCache(context)

            // Lock all protected apps after boot (security measure)
            AppLockManager.lockAllApps(context)

            Log.d(TAG, "All protected apps locked after boot")
        }
    }
}
