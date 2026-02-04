import 'dart:async';

import '../../data/models/protected_app.dart';
import '../../data/models/app_lock_session.dart';
import '../../data/models/authentication_decision.dart';
import '../../data/repositories/app_lock_repository.dart';
import 'native_app_service.dart';

/// Service for managing app locking based on gait authentication.
///
/// Handles:
/// - Listing available apps (real installed apps on Android, mock on other platforms)
/// - Managing app protection settings
/// - Syncing protection state with native Android side
/// - Locking apps on gait authentication failure
/// - Unlocking apps with successful gait authentication
class AppLockService {
  AppLockService({
    required this.repository,
    NativeAppService? nativeService,
    this.unlockThreshold = 0.7,
  }) : _nativeService = nativeService ?? NativeAppService.instance;

  final AppLockRepository repository;
  final NativeAppService _nativeService;

  /// Minimum confidence required to unlock an app
  final double unlockThreshold;

  /// Stream controller for lock events
  final _lockEventController = StreamController<AppLockEvent>.broadcast();

  /// Stream of lock events for UI updates
  Stream<AppLockEvent> get lockEvents => _lockEventController.stream;

  /// Cache for installed apps (to avoid repeated native calls)
  List<ProtectedApp>? _installedAppsCache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Initialize the service
  void initialize() {
    _nativeService.initialize();
  }

  /// Check if native app detection is available
  bool get isNativeSupported => _nativeService.isSupported;

  /// Get service status from native side
  Future<NativeServiceStatus> getServiceStatus() {
    return _nativeService.getServiceStatus();
  }

  /// Check if accessibility service is enabled
  Future<bool> isAccessibilityServiceEnabled() {
    return _nativeService.isAccessibilityServiceEnabled();
  }

  /// Open accessibility settings for user to enable service
  Future<void> openAccessibilitySettings() {
    return _nativeService.openAccessibilitySettings();
  }

  /// Check if overlay permission is granted
  Future<bool> isOverlayPermissionGranted() {
    return _nativeService.isOverlayPermissionGranted();
  }

  /// Request overlay permission
  Future<void> requestOverlayPermission() {
    return _nativeService.requestOverlayPermission();
  }

  /// Get all available apps (real installed apps on Android, merged with saved preferences)
  Future<List<ProtectedApp>> getAvailableApps(int userId) async {
    try {
      // Get user's saved app preferences from database
      final savedApps = await repository.getProtectedApps(userId);
      final savedByPackage = {for (var a in savedApps) a.packageName: a};

      // Try to get real installed apps on Android
      final installedApps = await _getInstalledApps();

      if (installedApps.isNotEmpty) {
        // Merge real apps with saved preferences
        final result = <ProtectedApp>[];

        for (final installed in installedApps) {
          final saved = savedByPackage[installed.packageName];
          if (saved != null) {
            // Use saved preferences with updated icon
            result.add(saved.copyWith(
              iconBase64: installed.iconBase64,
              displayName: installed.displayName,
              isRealApp: true,
            ));
          } else {
            // New app, not yet in database
            result.add(installed);
          }
        }

        return result;
      }

      // Fallback to mock apps if native detection unavailable
      return _getMergedMockApps(savedApps);
    } catch (e) {
      throw AppLockException('Failed to get available apps', e);
    }
  }

  /// Get installed apps from native side (with caching)
  Future<List<ProtectedApp>> _getInstalledApps() async {
    // Check cache
    if (_installedAppsCache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _installedAppsCache!;
    }

    // Fetch from native
    final nativeApps = await _nativeService.getInstalledApps();
    if (nativeApps.isEmpty) return [];

    // Convert to ProtectedApp
    _installedAppsCache = nativeApps
        .map((app) => ProtectedApp.fromInstalledApp(app))
        .toList();
    _cacheTime = DateTime.now();

    return _installedAppsCache!;
  }

  /// Merge mock apps with saved preferences (fallback when native unavailable)
  List<ProtectedApp> _getMergedMockApps(List<ProtectedApp> savedApps) {
    final savedByPackage = {for (var a in savedApps) a.packageName: a};
    final result = <ProtectedApp>[];

    // Add mock apps with saved preferences
    for (final mockApp in ProtectedApp.mockApps) {
      final saved = savedByPackage[mockApp.packageName];
      result.add(saved ?? mockApp);
    }

    // Add any saved apps not in mock list
    for (final saved in savedApps) {
      if (!ProtectedApp.mockApps.any((m) => m.packageName == saved.packageName)) {
        result.add(saved);
      }
    }

    return result;
  }

  /// Refresh the installed apps cache
  Future<void> refreshInstalledApps() async {
    _installedAppsCache = null;
    _cacheTime = null;
    await _getInstalledApps();
  }

  /// Get only the protected apps
  Future<List<ProtectedApp>> getProtectedApps(int userId) async {
    try {
      final allApps = await getAvailableApps(userId);
      return allApps.where((app) => app.isProtected).toList();
    } catch (e) {
      throw AppLockException('Failed to get protected apps', e);
    }
  }

  /// Get currently locked apps
  Future<List<ProtectedApp>> getLockedApps(int userId) async {
    try {
      final allApps = await getAvailableApps(userId);
      return allApps.where((app) => app.isLocked).toList();
    } catch (e) {
      throw AppLockException('Failed to get locked apps', e);
    }
  }

  /// Toggle app protection status
  Future<void> setAppProtection(
    int userId,
    String packageName,
    bool isProtected, {
    ProtectedApp? appInfo,
  }) async {
    try {
      await repository.setAppProtected(
        userId,
        packageName,
        isProtected,
        appInfo: appInfo,
      );

      // Sync with native side
      await _syncProtectedAppsToNative(userId);

      _lockEventController.add(AppLockEvent(
        type: isProtected
            ? AppLockEventType.appProtected
            : AppLockEventType.appUnprotected,
        packageName: packageName,
        userId: userId,
      ));
    } catch (e) {
      throw AppLockException('Failed to set app protection', e);
    }
  }

  /// Sync protected apps list to native Android side
  Future<void> _syncProtectedAppsToNative(int userId) async {
    if (!_nativeService.isSupported) return;

    try {
      final protectedApps = await repository.getProtectedApps(userId);
      final packageNames = protectedApps
          .where((a) => a.isProtected)
          .map((a) => a.packageName)
          .toList();
      await _nativeService.setProtectedApps(packageNames);
    } catch (e) {
      // Don't fail the main operation if sync fails
    }
  }

  /// Lock all protected apps (called on gait authentication failure)
  Future<void> lockAllProtectedApps(int userId) async {
    try {
      await repository.lockAllProtectedApps(userId);

      // Also lock on native side
      await _nativeService.lockAllApps();

      _lockEventController.add(AppLockEvent(
        type: AppLockEventType.allAppsLocked,
        userId: userId,
      ));
    } catch (e) {
      throw AppLockException('Failed to lock protected apps', e);
    }
  }

  /// Lock a specific app
  Future<AppLockSession> lockApp(int userId, String packageName) async {
    try {
      await repository.setAppLocked(userId, packageName, true);

      final session = await repository.createLockSession(
        AppLockSession.lock(userId: userId, packageName: packageName),
      );

      _lockEventController.add(AppLockEvent(
        type: AppLockEventType.appLocked,
        packageName: packageName,
        userId: userId,
        session: session,
      ));

      return session;
    } catch (e) {
      throw AppLockException('Failed to lock app', e);
    }
  }

  /// Attempt to unlock an app using gait features
  ///
  /// Returns [AppLockResult] with success/failure and confidence score
  Future<AppLockResult> attemptUnlock({
    required int userId,
    required String packageName,
    required double confidence,
  }) async {
    try {
      // Get current lock session
      var session = await repository.getActiveLockSession(userId, packageName);

      if (session == null) {
        return AppLockResult.failure(
          packageName: packageName,
          reason: 'App is not locked',
        );
      }

      // Mark as authenticating
      session = session.startAuthentication();
      await repository.updateLockSession(session);

      _lockEventController.add(AppLockEvent(
        type: AppLockEventType.authenticationStarted,
        packageName: packageName,
        userId: userId,
        session: session,
      ));

      // Check if confidence meets threshold
      if (confidence >= unlockThreshold) {
        // Unlock successful
        session = session.unlock(confidence);
        await repository.updateLockSession(session);
        await repository.setAppLocked(userId, packageName, false);

        // Also unlock on native side
        await _nativeService.unlockApp(packageName);

        _lockEventController.add(AppLockEvent(
          type: AppLockEventType.appUnlocked,
          packageName: packageName,
          userId: userId,
          confidence: confidence,
          session: session,
        ));

        return AppLockResult.success(
          packageName: packageName,
          confidence: confidence,
          session: session,
        );
      } else {
        // Unlock failed
        session = session.failAuthentication();
        await repository.updateLockSession(session);

        _lockEventController.add(AppLockEvent(
          type: AppLockEventType.unlockFailed,
          packageName: packageName,
          userId: userId,
          confidence: confidence,
          session: session,
        ));

        return AppLockResult.failure(
          packageName: packageName,
          reason: 'Confidence too low: ${(confidence * 100).toStringAsFixed(1)}% < ${(unlockThreshold * 100).toStringAsFixed(1)}%',
          confidence: confidence,
          session: session,
        );
      }
    } catch (e) {
      throw AppLockException('Failed to attempt unlock', e);
    }
  }

  /// Handle gait authentication result from the authentication service
  ///
  /// Call this method when gait authentication completes to trigger
  /// appropriate lock/unlock behavior
  Future<void> onGaitAuthenticationResult(
    int userId,
    AuthenticationDecision decision,
  ) async {
    try {
      if (!decision.isAuthenticated) {
        // Authentication failed - lock all protected apps
        await lockAllProtectedApps(userId);
      } else {
        // Authentication succeeded - unlock all apps
        await repository.unlockAllApps(userId);

        _lockEventController.add(AppLockEvent(
          type: AppLockEventType.allAppsUnlocked,
          userId: userId,
          confidence: decision.confidence,
        ));
      }
    } catch (e) {
      throw AppLockException('Failed to handle authentication result', e);
    }
  }

  /// Get lock statistics for a user
  Future<Map<String, dynamic>> getLockStats(int userId) async {
    try {
      return await repository.getAppLockStats(userId);
    } catch (e) {
      throw AppLockException('Failed to get lock stats', e);
    }
  }

  /// Get lock history
  Future<List<AppLockSession>> getLockHistory(int userId,
      {int limit = 50}) async {
    try {
      return await repository.getLockHistory(userId, limit: limit);
    } catch (e) {
      throw AppLockException('Failed to get lock history', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _lockEventController.close();
    _nativeService.dispose();
  }
}

/// Types of app lock events
enum AppLockEventType {
  appProtected,
  appUnprotected,
  appLocked,
  appUnlocked,
  allAppsLocked,
  allAppsUnlocked,
  authenticationStarted,
  unlockFailed,
}

/// Event emitted when lock state changes
class AppLockEvent {
  const AppLockEvent({
    required this.type,
    required this.userId,
    this.packageName,
    this.confidence,
    this.session,
  });

  final AppLockEventType type;
  final int userId;
  final String? packageName;
  final double? confidence;
  final AppLockSession? session;

  @override
  String toString() {
    return 'AppLockEvent(type: $type, packageName: $packageName, confidence: $confidence)';
  }
}

/// Exception thrown by AppLockService
class AppLockException implements Exception {
  const AppLockException(this.message, [this.cause]);

  final String message;
  final dynamic cause;

  @override
  String toString() =>
      'AppLockException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}
