package com.example.gait_guard_app

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

/**
 * Handles platform channel communication between Flutter and Android native code.
 *
 * This class manages:
 * - Method calls from Flutter (getInstalledApps, permissions, etc.)
 * - Event streams to Flutter (app launch events)
 */
class PlatformChannelHandler(
    private val context: Context,
    flutterEngine: FlutterEngine
) {
    companion object {
        const val METHOD_CHANNEL = "com.example.gait_guard_app/app_lock"
        const val EVENT_CHANNEL = "com.example.gait_guard_app/app_lock_events"

        // Singleton instance for accessibility service to communicate
        var instance: PlatformChannelHandler? = null
    }

    private val methodChannel: MethodChannel
    private val eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private val appListManager: AppListManager = AppListManager(context)

    init {
        instance = this

        // Setup Method Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call.method, call.arguments, result)
        }

        // Setup Event Channel for native -> Flutter communication
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun handleMethodCall(method: String, arguments: Any?, result: MethodChannel.Result) {
        when (method) {
            "getInstalledApps" -> {
                try {
                    val apps = appListManager.getInstalledUserApps()
                    result.success(apps)
                } catch (e: Exception) {
                    result.error("APP_LIST_ERROR", e.message, null)
                }
            }

            "setProtectedApps" -> {
                try {
                    @Suppress("UNCHECKED_CAST")
                    val packageNames = arguments as? List<String> ?: emptyList()
                    AppLockManager.setProtectedApps(context, packageNames.toSet())
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SET_PROTECTED_ERROR", e.message, null)
                }
            }

            "isAccessibilityServiceEnabled" -> {
                val enabled = isAccessibilityServiceEnabled()
                result.success(enabled)
            }

            "openAccessibilitySettings" -> {
                openAccessibilitySettings()
                result.success(null)
            }

            "isOverlayPermissionGranted" -> {
                val granted = Settings.canDrawOverlays(context)
                result.success(granted)
            }

            "requestOverlayPermission" -> {
                requestOverlayPermission()
                result.success(null)
            }

            "unlockApp" -> {
                try {
                    val packageName = arguments as? String ?: ""
                    AppLockManager.unlockApp(context, packageName)
                    // Send broadcast to dismiss overlay if showing
                    val intent = Intent("com.example.gait_guard_app.UNLOCK_APP").apply {
                        putExtra("package_name", packageName)
                        setPackage(context.packageName)
                    }
                    context.sendBroadcast(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNLOCK_ERROR", e.message, null)
                }
            }

            "lockAllApps" -> {
                try {
                    AppLockManager.lockAllApps(context)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("LOCK_ERROR", e.message, null)
                }
            }

            "getServiceStatus" -> {
                val status = mapOf(
                    "accessibilityEnabled" to isAccessibilityServiceEnabled(),
                    "overlayPermission" to Settings.canDrawOverlays(context),
                    "protectedAppsCount" to AppLockManager.getProtectedApps(context).size,
                    "lockedAppsCount" to AppLockManager.getLockedApps(context).size
                )
                result.success(status)
            }

            "getProtectedPackages" -> {
                val packages = AppLockManager.getProtectedApps(context).toList()
                result.success(packages)
            }

            "getLockedPackages" -> {
                val packages = AppLockManager.getLockedApps(context).toList()
                result.success(packages)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Check if GaitGuard Accessibility Service is enabled
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "${context.packageName}/${GaitGuardAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.split(':').any {
            it.equals(serviceName, ignoreCase = true)
        }
    }

    /**
     * Open Android Accessibility Settings
     */
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /**
     * Request overlay permission (draws over other apps)
     */
    private fun requestOverlayPermission() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}")
        ).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /**
     * Send event to Flutter (called from AccessibilityService)
     */
    fun sendEvent(eventName: String, data: Map<String, Any?>) {
        eventSink?.success(mapOf(
            "event" to eventName,
            "data" to data
        ))
    }

    /**
     * Notify Flutter that a protected app was launched
     */
    fun notifyProtectedAppLaunched(packageName: String, displayName: String) {
        sendEvent("onProtectedAppLaunched", mapOf(
            "packageName" to packageName,
            "displayName" to displayName
        ))
    }

    /**
     * Notify Flutter that lock overlay was shown
     */
    fun notifyLockOverlayShown(packageName: String) {
        sendEvent("onLockOverlayShown", mapOf(
            "packageName" to packageName
        ))
    }

    /**
     * Notify Flutter that lock overlay was dismissed
     */
    fun notifyLockOverlayDismissed(packageName: String, reason: String) {
        sendEvent("onLockOverlayDismissed", mapOf(
            "packageName" to packageName,
            "reason" to reason
        ))
    }
}
