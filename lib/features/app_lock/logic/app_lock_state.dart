import 'package:flutter/foundation.dart';

import '../../../data/models/protected_app.dart';
import '../../../data/models/app_lock_session.dart';

/// Base state for app lock feature
@immutable
abstract class AppLockState {
  const AppLockState();
}

/// Initial state before initialization
class AppLockInitial extends AppLockState {
  const AppLockInitial();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppLockInitial;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Loading state during async operations
class AppLockLoading extends AppLockState {
  const AppLockLoading({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLockLoading && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// Ready state with app lists loaded
class AppLockReady extends AppLockState {
  const AppLockReady({
    required this.userId,
    required this.availableApps,
    required this.protectedApps,
    required this.lockedApps,
    this.stats,
  });

  final int userId;
  final List<ProtectedApp> availableApps;
  final List<ProtectedApp> protectedApps;
  final List<ProtectedApp> lockedApps;
  final Map<String, dynamic>? stats;

  /// Whether any apps are currently locked
  bool get hasLockedApps => lockedApps.isNotEmpty;

  /// Whether any apps are protected
  bool get hasProtectedApps => protectedApps.isNotEmpty;

  /// Count of protected apps
  int get protectedCount => protectedApps.length;

  /// Count of locked apps
  int get lockedCount => lockedApps.length;

  AppLockReady copyWith({
    int? userId,
    List<ProtectedApp>? availableApps,
    List<ProtectedApp>? protectedApps,
    List<ProtectedApp>? lockedApps,
    Map<String, dynamic>? stats,
  }) {
    return AppLockReady(
      userId: userId ?? this.userId,
      availableApps: availableApps ?? this.availableApps,
      protectedApps: protectedApps ?? this.protectedApps,
      lockedApps: lockedApps ?? this.lockedApps,
      stats: stats ?? this.stats,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLockReady &&
          other.userId == userId &&
          listEquals(other.availableApps, availableApps) &&
          listEquals(other.protectedApps, protectedApps) &&
          listEquals(other.lockedApps, lockedApps);

  @override
  int get hashCode => Object.hash(
        userId,
        availableApps.length,
        protectedApps.length,
        lockedApps.length,
      );
}

/// State when attempting to unlock an app
class AppLockAuthenticating extends AppLockState {
  const AppLockAuthenticating({
    required this.userId,
    required this.packageName,
    required this.displayName,
    this.currentConfidence = 0.0,
    this.attempts = 0,
  });

  final int userId;
  final String packageName;
  final String displayName;
  final double currentConfidence;
  final int attempts;

  AppLockAuthenticating copyWith({
    double? currentConfidence,
    int? attempts,
  }) {
    return AppLockAuthenticating(
      userId: userId,
      packageName: packageName,
      displayName: displayName,
      currentConfidence: currentConfidence ?? this.currentConfidence,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLockAuthenticating &&
          other.packageName == packageName &&
          other.currentConfidence == currentConfidence &&
          other.attempts == attempts;

  @override
  int get hashCode => Object.hash(packageName, currentConfidence, attempts);
}

/// State when unlock was successful
class AppLockUnlockSuccess extends AppLockState {
  const AppLockUnlockSuccess({
    required this.userId,
    required this.packageName,
    required this.displayName,
    required this.confidence,
    this.session,
  });

  final int userId;
  final String packageName;
  final String displayName;
  final double confidence;
  final AppLockSession? session;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLockUnlockSuccess &&
          other.packageName == packageName &&
          other.confidence == confidence;

  @override
  int get hashCode => Object.hash(packageName, confidence);
}

/// State when unlock failed
class AppLockUnlockFailed extends AppLockState {
  const AppLockUnlockFailed({
    required this.userId,
    required this.packageName,
    required this.displayName,
    required this.reason,
    this.confidence = 0.0,
    this.session,
  });

  final int userId;
  final String packageName;
  final String displayName;
  final String reason;
  final double confidence;
  final AppLockSession? session;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLockUnlockFailed &&
          other.packageName == packageName &&
          other.reason == reason;

  @override
  int get hashCode => Object.hash(packageName, reason);
}

/// State when all apps have been locked (due to gait failure)
class AppLockAllLocked extends AppLockState {
  const AppLockAllLocked({
    required this.userId,
    required this.lockedCount,
    this.reason,
  });

  final int userId;
  final int lockedCount;
  final String? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLockAllLocked &&
          other.userId == userId &&
          other.lockedCount == lockedCount;

  @override
  int get hashCode => Object.hash(userId, lockedCount);
}

/// Error state
class AppLockError extends AppLockState {
  const AppLockError({
    required this.message,
    this.error,
  });

  final String message;
  final dynamic error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLockError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}
