import 'dart:async';

import '../../data/models/protected_app.dart';
import '../../data/models/app_lock_session.dart';
import '../../data/models/authentication_decision.dart';
import '../../data/repositories/app_lock_repository.dart';

/// Service for managing app locking based on gait authentication.
///
/// Handles:
/// - Listing available apps (simulated)
/// - Managing app protection settings
/// - Locking apps on gait authentication failure
/// - Unlocking apps with successful gait authentication
class AppLockService {
  AppLockService({
    required this.repository,
    this.unlockThreshold = 0.7,
  });

  final AppLockRepository repository;

  /// Minimum confidence required to unlock an app
  final double unlockThreshold;

  /// Stream controller for lock events
  final _lockEventController = StreamController<AppLockEvent>.broadcast();

  /// Stream of lock events for UI updates
  Stream<AppLockEvent> get lockEvents => _lockEventController.stream;

  /// Get all available apps (mock + user's saved apps merged)
  Future<List<ProtectedApp>> getAvailableApps(int userId) async {
    try {
      // Get user's saved app preferences
      final savedApps = await repository.getProtectedApps(userId);
      final savedPackages = savedApps.map((a) => a.packageName).toSet();

      // Merge with mock apps
      final result = <ProtectedApp>[];

      // Add mock apps with saved preferences if they exist
      for (final mockApp in ProtectedApp.mockApps) {
        final savedApp = savedApps.firstWhere(
          (a) => a.packageName == mockApp.packageName,
          orElse: () => mockApp,
        );
        result.add(savedApp);
      }

      // Add any user-saved apps not in mock list
      for (final savedApp in savedApps) {
        if (!ProtectedApp.mockApps
            .any((m) => m.packageName == savedApp.packageName)) {
          result.add(savedApp);
        }
      }

      return result;
    } catch (e) {
      throw AppLockException('Failed to get available apps', e);
    }
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
    bool isProtected,
  ) async {
    try {
      await repository.setAppProtected(userId, packageName, isProtected);

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

  /// Lock all protected apps (called on gait authentication failure)
  Future<void> lockAllProtectedApps(int userId) async {
    try {
      await repository.lockAllProtectedApps(userId);

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
