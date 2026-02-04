import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for communicating with native Android code for app detection and locking.
///
/// This service provides:
/// - Installed app enumeration with icons
/// - Permission checking and requesting
/// - App protection state management
/// - Lock/unlock functionality
///
/// On iOS and other platforms, methods return mock/empty data.
class NativeAppService {
  NativeAppService._();

  static final NativeAppService instance = NativeAppService._();

  static const MethodChannel _methodChannel =
      MethodChannel('com.example.gait_guard_app/app_lock');

  static const EventChannel _eventChannel =
      EventChannel('com.example.gait_guard_app/app_lock_events');

  StreamSubscription? _eventSubscription;
  final _eventController = StreamController<AppLockEvent>.broadcast();

  /// Stream of app lock events from native side
  Stream<AppLockEvent> get events => _eventController.stream;

  /// Initialize the service and start listening to native events
  void initialize() {
    if (!Platform.isAndroid) return;

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final eventName = event['event'] as String?;
          final data = event['data'] as Map<dynamic, dynamic>?;

          if (eventName != null) {
            _eventController.add(AppLockEvent(
              name: eventName,
              data: data?.cast<String, dynamic>() ?? {},
            ));
          }
        }
      },
      onError: (error) {
        debugPrint('NativeAppService event error: $error');
      },
    );
  }

  /// Dispose resources
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }

  /// Check if running on Android (native features available)
  bool get isSupported => Platform.isAndroid;

  /// Get list of installed user applications.
  ///
  /// Returns list of [InstalledApp] with package name, display name, and icon.
  /// Returns empty list on non-Android platforms.
  Future<List<InstalledApp>> getInstalledApps() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (result == null) return [];

      return result
          .whereType<Map<dynamic, dynamic>>()
          .map((map) => InstalledApp.fromMap(map.cast<String, dynamic>()))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('Failed to get installed apps: ${e.message}');
      return [];
    }
  }

  /// Update the list of protected apps on native side.
  ///
  /// This tells the Accessibility Service which apps to monitor.
  Future<bool> setProtectedApps(List<String> packageNames) async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setProtectedApps',
        packageNames,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to set protected apps: ${e.message}');
      return false;
    }
  }

  /// Check if Accessibility Service is enabled.
  Future<bool> isAccessibilityServiceEnabled() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isAccessibilityServiceEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to check accessibility service: ${e.message}');
      return false;
    }
  }

  /// Open Android Accessibility Settings.
  ///
  /// User needs to manually enable GaitGuard Accessibility Service.
  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;

    try {
      await _methodChannel.invokeMethod<void>('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('Failed to open accessibility settings: ${e.message}');
    }
  }

  /// Check if overlay permission is granted (draw over other apps).
  Future<bool> isOverlayPermissionGranted() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isOverlayPermissionGranted',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to check overlay permission: ${e.message}');
      return false;
    }
  }

  /// Request overlay permission (opens system settings).
  Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;

    try {
      await _methodChannel.invokeMethod<void>('requestOverlayPermission');
    } on PlatformException catch (e) {
      debugPrint('Failed to request overlay permission: ${e.message}');
    }
  }

  /// Unlock a specific app (dismiss lock screen).
  Future<bool> unlockApp(String packageName) async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'unlockApp',
        packageName,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to unlock app: ${e.message}');
      return false;
    }
  }

  /// Lock all protected apps.
  Future<void> lockAllApps() async {
    if (!Platform.isAndroid) return;

    try {
      await _methodChannel.invokeMethod<void>('lockAllApps');
    } on PlatformException catch (e) {
      debugPrint('Failed to lock all apps: ${e.message}');
    }
  }

  /// Get current service status.
  Future<NativeServiceStatus> getServiceStatus() async {
    if (!Platform.isAndroid) {
      return NativeServiceStatus(
        accessibilityEnabled: false,
        overlayPermission: false,
        protectedAppsCount: 0,
        lockedAppsCount: 0,
      );
    }

    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getServiceStatus',
      );
      if (result == null) {
        return NativeServiceStatus(
          accessibilityEnabled: false,
          overlayPermission: false,
          protectedAppsCount: 0,
          lockedAppsCount: 0,
        );
      }
      return NativeServiceStatus.fromMap(result.cast<String, dynamic>());
    } on PlatformException catch (e) {
      debugPrint('Failed to get service status: ${e.message}');
      return NativeServiceStatus(
        accessibilityEnabled: false,
        overlayPermission: false,
        protectedAppsCount: 0,
        lockedAppsCount: 0,
      );
    }
  }

  /// Get list of protected package names from native storage.
  Future<List<String>> getProtectedPackages() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getProtectedPackages',
      );
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      debugPrint('Failed to get protected packages: ${e.message}');
      return [];
    }
  }

  /// Get list of locked package names from native storage.
  Future<List<String>> getLockedPackages() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getLockedPackages',
      );
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      debugPrint('Failed to get locked packages: ${e.message}');
      return [];
    }
  }
}

/// Represents an installed application from native Android.
@immutable
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.displayName,
    required this.iconBase64,
    required this.isSystemApp,
  });

  final String packageName;
  final String displayName;
  final String iconBase64;
  final bool isSystemApp;

  factory InstalledApp.fromMap(Map<String, dynamic> map) {
    return InstalledApp(
      packageName: map['packageName'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      iconBase64: map['iconBase64'] as String? ?? '',
      isSystemApp: map['isSystemApp'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'displayName': displayName,
      'iconBase64': iconBase64,
      'isSystemApp': isSystemApp,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstalledApp && other.packageName == packageName;
  }

  @override
  int get hashCode => packageName.hashCode;

  @override
  String toString() => 'InstalledApp($displayName, $packageName)';
}

/// Event from native app lock service.
@immutable
class AppLockEvent {
  const AppLockEvent({
    required this.name,
    required this.data,
  });

  final String name;
  final Map<String, dynamic> data;

  String? get packageName => data['packageName'] as String?;
  String? get displayName => data['displayName'] as String?;
  String? get reason => data['reason'] as String?;

  @override
  String toString() => 'AppLockEvent($name, $data)';
}

/// Status of native services.
@immutable
class NativeServiceStatus {
  const NativeServiceStatus({
    required this.accessibilityEnabled,
    required this.overlayPermission,
    required this.protectedAppsCount,
    required this.lockedAppsCount,
  });

  final bool accessibilityEnabled;
  final bool overlayPermission;
  final int protectedAppsCount;
  final int lockedAppsCount;

  /// Check if all required permissions are granted
  bool get isFullyConfigured => accessibilityEnabled && overlayPermission;

  factory NativeServiceStatus.fromMap(Map<String, dynamic> map) {
    return NativeServiceStatus(
      accessibilityEnabled: map['accessibilityEnabled'] as bool? ?? false,
      overlayPermission: map['overlayPermission'] as bool? ?? false,
      protectedAppsCount: map['protectedAppsCount'] as int? ?? 0,
      lockedAppsCount: map['lockedAppsCount'] as int? ?? 0,
    );
  }

  @override
  String toString() =>
      'NativeServiceStatus(accessibility: $accessibilityEnabled, overlay: $overlayPermission)';
}
