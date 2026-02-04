package com.example.gait_guard_app

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Manages the state of protected and locked applications.
 *
 * Uses EncryptedSharedPreferences for secure storage of:
 * - Protected apps list (user-selected apps to monitor)
 * - Locked apps list (apps currently requiring authentication)
 *
 * This is a singleton-style manager accessed via companion object methods.
 */
object AppLockManager {

    private const val PREFS_NAME = "gait_guard_app_lock"
    private const val KEY_PROTECTED_APPS = "protected_apps"
    private const val KEY_LOCKED_APPS = "locked_apps"

    private var cachedProtectedApps: MutableSet<String>? = null
    private var cachedLockedApps: MutableSet<String>? = null

    /**
     * Get SharedPreferences instance (encrypted for security).
     */
    private fun getPrefs(context: Context): SharedPreferences {
        return try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                context,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            // Fallback to regular SharedPreferences if encryption fails
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    /**
     * Get the set of protected app package names.
     */
    fun getProtectedApps(context: Context): Set<String> {
        if (cachedProtectedApps == null) {
            val prefs = getPrefs(context)
            cachedProtectedApps = prefs.getStringSet(KEY_PROTECTED_APPS, emptySet())?.toMutableSet()
                ?: mutableSetOf()
        }
        return cachedProtectedApps!!.toSet()
    }

    /**
     * Set the list of protected apps.
     */
    fun setProtectedApps(context: Context, packageNames: Set<String>) {
        cachedProtectedApps = packageNames.toMutableSet()
        getPrefs(context).edit()
            .putStringSet(KEY_PROTECTED_APPS, packageNames)
            .apply()

        // Update accessibility service if running
        GaitGuardAccessibilityService.instance?.updateProtectedApps(packageNames)
    }

    /**
     * Add a single app to protected list.
     */
    fun addProtectedApp(context: Context, packageName: String) {
        val current = getProtectedApps(context).toMutableSet()
        current.add(packageName)
        setProtectedApps(context, current)
    }

    /**
     * Remove an app from protected list.
     */
    fun removeProtectedApp(context: Context, packageName: String) {
        val current = getProtectedApps(context).toMutableSet()
        current.remove(packageName)
        setProtectedApps(context, current)

        // Also unlock if it was locked
        unlockApp(context, packageName)
    }

    /**
     * Check if an app is protected.
     */
    fun isAppProtected(context: Context, packageName: String): Boolean {
        return getProtectedApps(context).contains(packageName)
    }

    /**
     * Get the set of currently locked app package names.
     */
    fun getLockedApps(context: Context): Set<String> {
        if (cachedLockedApps == null) {
            val prefs = getPrefs(context)
            cachedLockedApps = prefs.getStringSet(KEY_LOCKED_APPS, emptySet())?.toMutableSet()
                ?: mutableSetOf()
        }
        return cachedLockedApps!!.toSet()
    }

    /**
     * Lock an app (require authentication to access).
     */
    fun lockApp(context: Context, packageName: String) {
        if (!isAppProtected(context, packageName)) return

        val current = getLockedApps(context).toMutableSet()
        current.add(packageName)
        cachedLockedApps = current
        getPrefs(context).edit()
            .putStringSet(KEY_LOCKED_APPS, current)
            .apply()

        // Update accessibility service
        GaitGuardAccessibilityService.instance?.updateLockedApps(current)
    }

    /**
     * Unlock an app (allow access without authentication).
     */
    fun unlockApp(context: Context, packageName: String) {
        val current = getLockedApps(context).toMutableSet()
        current.remove(packageName)
        cachedLockedApps = current
        getPrefs(context).edit()
            .putStringSet(KEY_LOCKED_APPS, current)
            .apply()

        // Update accessibility service
        GaitGuardAccessibilityService.instance?.updateLockedApps(current)
    }

    /**
     * Lock all protected apps.
     */
    fun lockAllApps(context: Context) {
        val protected = getProtectedApps(context)
        cachedLockedApps = protected.toMutableSet()
        getPrefs(context).edit()
            .putStringSet(KEY_LOCKED_APPS, protected)
            .apply()

        // Update accessibility service
        GaitGuardAccessibilityService.instance?.updateLockedApps(protected)
    }

    /**
     * Unlock all apps.
     */
    fun unlockAllApps(context: Context) {
        cachedLockedApps = mutableSetOf()
        getPrefs(context).edit()
            .putStringSet(KEY_LOCKED_APPS, emptySet())
            .apply()

        // Update accessibility service
        GaitGuardAccessibilityService.instance?.updateLockedApps(emptySet())
    }

    /**
     * Check if an app is currently locked.
     */
    fun isAppLocked(context: Context, packageName: String): Boolean {
        return getLockedApps(context).contains(packageName)
    }

    /**
     * Check if an app should show lock screen (protected AND locked).
     */
    fun shouldShowLockScreen(context: Context, packageName: String): Boolean {
        return isAppProtected(context, packageName) && isAppLocked(context, packageName)
    }

    /**
     * Clear cache and reload from storage.
     */
    fun refreshCache(context: Context) {
        cachedProtectedApps = null
        cachedLockedApps = null
        getProtectedApps(context)
        getLockedApps(context)
    }

    /**
     * Clear all data (for testing or reset).
     */
    fun clearAll(context: Context) {
        cachedProtectedApps = mutableSetOf()
        cachedLockedApps = mutableSetOf()
        getPrefs(context).edit().clear().apply()
    }
}
