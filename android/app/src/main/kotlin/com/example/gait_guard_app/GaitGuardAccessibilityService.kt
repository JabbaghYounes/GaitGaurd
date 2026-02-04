package com.example.gait_guard_app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.util.Log

/**
 * Accessibility Service that monitors app launches to detect protected apps.
 *
 * When a protected app is launched, this service:
 * 1. Checks if the app is in the protected and locked list
 * 2. Launches the LockOverlayActivity to block access
 * 3. Notifies Flutter via PlatformChannelHandler
 *
 * The service listens for TYPE_WINDOW_STATE_CHANGED events which fire
 * when a new activity comes to the foreground.
 */
class GaitGuardAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "GaitGuardAccessibility"

        // Singleton instance for external access
        var instance: GaitGuardAccessibilityService? = null
            private set

        // Cached state for quick access
        private var protectedApps: Set<String> = emptySet()
        private var lockedApps: MutableSet<String> = mutableSetOf()

        // Packages to ignore (system UI, launchers, our app)
        private val ignoredPackages = setOf(
            "com.example.gait_guard_app",
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher2",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher", // Samsung
            "com.huawei.android.launcher", // Huawei
            "com.miui.home", // Xiaomi
            "com.oppo.launcher", // Oppo
            "com.vivo.launcher", // Vivo
            "com.oneplus.launcher", // OnePlus
            "com.android.settings",
            "com.android.packageinstaller",
        )
    }

    private var lastBlockedPackage: String? = null
    private var lastBlockedTime: Long = 0
    private val blockCooldown = 1000L // 1 second cooldown to prevent spam

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        Log.d(TAG, "Accessibility service connected")

        // Load protected apps from storage
        loadProtectedApps()
    }

    override fun onDestroy() {
        instance = null
        Log.d(TAG, "Accessibility service destroyed")
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // Skip ignored packages
        if (ignoredPackages.contains(packageName)) return

        // Skip if this is our lock overlay
        if (packageName == "com.example.gait_guard_app") return

        // Check if this app should be blocked
        if (shouldBlockApp(packageName)) {
            blockApp(packageName)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }

    /**
     * Check if an app should be blocked based on protection and lock state.
     */
    private fun shouldBlockApp(packageName: String): Boolean {
        // Must be both protected AND locked
        val isProtected = protectedApps.contains(packageName)
        val isLocked = lockedApps.contains(packageName)

        if (!isProtected || !isLocked) return false

        // Check cooldown to prevent multiple triggers
        val now = System.currentTimeMillis()
        if (packageName == lastBlockedPackage && (now - lastBlockedTime) < blockCooldown) {
            return false
        }

        return true
    }

    /**
     * Block access to an app by showing lock overlay.
     */
    private fun blockApp(packageName: String) {
        lastBlockedPackage = packageName
        lastBlockedTime = System.currentTimeMillis()

        Log.d(TAG, "Blocking app: $packageName")

        // Get display name for the app
        val displayName = getAppDisplayName(packageName)

        // Notify Flutter that a protected app was launched
        PlatformChannelHandler.instance?.notifyProtectedAppLaunched(packageName, displayName)

        // Launch lock overlay activity
        val intent = Intent(this, LockOverlayActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            putExtra("package_name", packageName)
            putExtra("display_name", displayName)
        }
        startActivity(intent)
    }

    /**
     * Get display name for a package.
     */
    private fun getAppDisplayName(packageName: String): String {
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    /**
     * Load protected apps from persistent storage.
     */
    private fun loadProtectedApps() {
        protectedApps = AppLockManager.getProtectedApps(this)
        lockedApps = AppLockManager.getLockedApps(this).toMutableSet()
        Log.d(TAG, "Loaded ${protectedApps.size} protected apps, ${lockedApps.size} locked")
    }

    /**
     * Update the list of protected apps (called from PlatformChannelHandler).
     */
    fun updateProtectedApps(packages: Set<String>) {
        protectedApps = packages
        Log.d(TAG, "Updated protected apps: ${packages.size} apps")
    }

    /**
     * Update the list of locked apps (called from AppLockManager).
     */
    fun updateLockedApps(packages: Set<String>) {
        lockedApps = packages.toMutableSet()
        Log.d(TAG, "Updated locked apps: ${packages.size} apps")
    }

    /**
     * Unlock a specific app (called when gait auth succeeds).
     */
    fun unlockApp(packageName: String) {
        lockedApps.remove(packageName)
        Log.d(TAG, "Unlocked app: $packageName")
    }

    /**
     * Lock all protected apps.
     */
    fun lockAllApps() {
        lockedApps = protectedApps.toMutableSet()
        Log.d(TAG, "Locked all apps: ${lockedApps.size} apps")
    }

    /**
     * Refresh state from storage.
     */
    fun refresh() {
        loadProtectedApps()
    }
}
