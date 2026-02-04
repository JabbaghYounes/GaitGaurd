package com.example.gait_guard_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Broadcast receiver that handles app unlock events.
 *
 * When Flutter signals that gait authentication has succeeded,
 * it sends a broadcast that this receiver handles to:
 * 1. Update the lock state
 * 2. Dismiss the lock overlay
 */
class UnlockReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GaitGuardUnlockReceiver"
        const val ACTION_UNLOCK = "com.example.gait_guard_app.UNLOCK_APP"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        if (intent.action == ACTION_UNLOCK) {
            val packageName = intent.getStringExtra("package_name")

            if (packageName != null) {
                Log.d(TAG, "Received unlock broadcast for: $packageName")

                // Update lock state
                AppLockManager.unlockApp(context, packageName)

                // Notify the lock overlay activity to dismiss
                // This is handled by LockOverlayActivity's own receiver
            }
        }
    }
}
