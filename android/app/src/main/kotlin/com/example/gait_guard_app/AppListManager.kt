package com.example.gait_guard_app

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream

/**
 * Manages querying and processing installed applications.
 *
 * Uses PackageManager to enumerate installed user apps (not system apps)
 * and converts app icons to base64 for transmission to Flutter.
 */
class AppListManager(private val context: Context) {

    companion object {
        private const val ICON_SIZE = 96 // Icon size in pixels
        private const val ICON_QUALITY = 85 // PNG compression quality
    }

    /**
     * Get list of installed user applications (excluding system apps).
     *
     * @return List of maps containing app info (packageName, displayName, iconBase64)
     */
    fun getInstalledUserApps(): List<Map<String, Any?>> {
        val pm = context.packageManager

        // Query apps that have a launcher activity
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)

        return resolveInfos
            .asSequence()
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { !isSystemApp(it) }
            .filter { it.packageName != context.packageName } // Exclude our own app
            .map { appInfo ->
                mapOf(
                    "packageName" to appInfo.packageName,
                    "displayName" to pm.getApplicationLabel(appInfo).toString(),
                    "iconBase64" to getIconAsBase64(appInfo, pm),
                    "isSystemApp" to false
                )
            }
            .sortedBy { (it["displayName"] as String).lowercase() }
            .toList()
    }

    /**
     * Get all installed apps including system apps.
     *
     * @return List of maps containing app info
     */
    fun getAllInstalledApps(): List<Map<String, Any?>> {
        val pm = context.packageManager

        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)

        return resolveInfos
            .asSequence()
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != context.packageName }
            .map { appInfo ->
                mapOf(
                    "packageName" to appInfo.packageName,
                    "displayName" to pm.getApplicationLabel(appInfo).toString(),
                    "iconBase64" to getIconAsBase64(appInfo, pm),
                    "isSystemApp" to isSystemApp(appInfo)
                )
            }
            .sortedBy { (it["displayName"] as String).lowercase() }
            .toList()
    }

    /**
     * Get app info for a specific package.
     *
     * @param packageName The package name to look up
     * @return Map containing app info, or null if not found
     */
    fun getAppInfo(packageName: String): Map<String, Any?>? {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)

            mapOf(
                "packageName" to appInfo.packageName,
                "displayName" to pm.getApplicationLabel(appInfo).toString(),
                "iconBase64" to getIconAsBase64(appInfo, pm),
                "isSystemApp" to isSystemApp(appInfo)
            )
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    /**
     * Get display name for a package.
     *
     * @param packageName The package name
     * @return Display name or package name if not found
     */
    fun getAppDisplayName(packageName: String): String {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    /**
     * Check if an app is installed.
     *
     * @param packageName The package name to check
     * @return true if installed, false otherwise
     */
    fun isAppInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    /**
     * Check if application is a system app.
     */
    private fun isSystemApp(appInfo: ApplicationInfo): Boolean {
        return (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
    }

    /**
     * Convert app icon to base64 encoded PNG string.
     *
     * @param appInfo Application info
     * @param pm Package manager
     * @return Base64 encoded icon string, or empty string on failure
     */
    private fun getIconAsBase64(appInfo: ApplicationInfo, pm: PackageManager): String {
        return try {
            val drawable = pm.getApplicationIcon(appInfo)
            val bitmap = drawableToBitmap(drawable)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, ICON_QUALITY, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            "" // Return empty string on failure
        }
    }

    /**
     * Convert Drawable to Bitmap with specified size.
     *
     * @param drawable The drawable to convert
     * @return Bitmap representation
     */
    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
        drawable.draw(canvas)
        return bitmap
    }
}
