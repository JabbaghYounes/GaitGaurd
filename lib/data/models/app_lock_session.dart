import 'package:flutter/material.dart';

/// Status of an app lock session.
enum AppLockStatus {
  locked('Locked'),
  unlocked('Unlocked'),
  authenticating('Authenticating');

  const AppLockStatus(this.displayName);
  final String displayName;
}

/// Represents a lock/unlock event for a protected app.
///
/// Each time an app is locked or an unlock attempt is made,
/// a new session is created to track the event.
@immutable
class AppLockSession {
  const AppLockSession({
    this.id,
    required this.userId,
    required this.packageName,
    required this.lockStatus,
    required this.lockedAt,
    this.unlockedAt,
    this.unlockConfidence,
    this.unlockAttempts = 0,
    this.metadata,
  });

  /// Database ID
  final int? id;

  /// User who owns this lock session
  final int userId;

  /// Package name of the locked app
  final String packageName;

  /// Current status of the lock
  final AppLockStatus lockStatus;

  /// When the app was locked
  final DateTime lockedAt;

  /// When the app was unlocked (null if still locked)
  final DateTime? unlockedAt;

  /// Confidence score when unlocked (0.0-1.0)
  final double? unlockConfidence;

  /// Number of unlock attempts made
  final int unlockAttempts;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// Create a new locked session
  factory AppLockSession.lock({
    required int userId,
    required String packageName,
  }) {
    return AppLockSession(
      userId: userId,
      packageName: packageName,
      lockStatus: AppLockStatus.locked,
      lockedAt: DateTime.now(),
    );
  }

  /// Duration the app has been locked
  Duration get lockDuration {
    final endTime = unlockedAt ?? DateTime.now();
    return endTime.difference(lockedAt);
  }

  /// Whether the session is currently active (locked or authenticating)
  bool get isActive =>
      lockStatus == AppLockStatus.locked ||
      lockStatus == AppLockStatus.authenticating;

  /// Create a copy with updated fields
  AppLockSession copyWith({
    int? id,
    int? userId,
    String? packageName,
    AppLockStatus? lockStatus,
    DateTime? lockedAt,
    DateTime? unlockedAt,
    double? unlockConfidence,
    int? unlockAttempts,
    Map<String, dynamic>? metadata,
  }) {
    return AppLockSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      packageName: packageName ?? this.packageName,
      lockStatus: lockStatus ?? this.lockStatus,
      lockedAt: lockedAt ?? this.lockedAt,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      unlockConfidence: unlockConfidence ?? this.unlockConfidence,
      unlockAttempts: unlockAttempts ?? this.unlockAttempts,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Mark session as authenticating
  AppLockSession startAuthentication() {
    return copyWith(
      lockStatus: AppLockStatus.authenticating,
      unlockAttempts: unlockAttempts + 1,
    );
  }

  /// Mark session as unlocked
  AppLockSession unlock(double confidence) {
    return copyWith(
      lockStatus: AppLockStatus.unlocked,
      unlockedAt: DateTime.now(),
      unlockConfidence: confidence,
    );
  }

  /// Mark authentication as failed (return to locked)
  AppLockSession failAuthentication() {
    return copyWith(
      lockStatus: AppLockStatus.locked,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'package_name': packageName,
      'lock_status': lockStatus.name,
      'locked_at': lockedAt.toIso8601String(),
      'unlocked_at': unlockedAt?.toIso8601String(),
      'unlock_confidence': unlockConfidence,
      'unlock_attempts': unlockAttempts,
      'metadata': metadata?.toString(),
    };
  }

  /// Create from database map
  factory AppLockSession.fromMap(Map<String, dynamic> map) {
    return AppLockSession(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      packageName: map['package_name'] as String,
      lockStatus: AppLockStatus.values.byName(map['lock_status'] as String),
      lockedAt: DateTime.parse(map['locked_at'] as String),
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.parse(map['unlocked_at'] as String)
          : null,
      unlockConfidence: map['unlock_confidence'] as double?,
      unlockAttempts: map['unlock_attempts'] as int? ?? 0,
      metadata: null, // Would need JSON parsing for full support
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppLockSession &&
        other.id == id &&
        other.userId == userId &&
        other.packageName == packageName &&
        other.lockStatus == lockStatus;
  }

  @override
  int get hashCode => Object.hash(id, userId, packageName, lockStatus);

  @override
  String toString() {
    return 'AppLockSession(id: $id, packageName: $packageName, '
        'status: ${lockStatus.displayName}, attempts: $unlockAttempts)';
  }
}

/// Result of an unlock attempt
@immutable
class AppLockResult {
  const AppLockResult({
    required this.success,
    required this.packageName,
    this.confidence = 0.0,
    this.message,
    this.session,
  });

  final bool success;
  final String packageName;
  final double confidence;
  final String? message;
  final AppLockSession? session;

  factory AppLockResult.success({
    required String packageName,
    required double confidence,
    AppLockSession? session,
  }) {
    return AppLockResult(
      success: true,
      packageName: packageName,
      confidence: confidence,
      message: 'App unlocked successfully',
      session: session,
    );
  }

  factory AppLockResult.failure({
    required String packageName,
    required String reason,
    double confidence = 0.0,
    AppLockSession? session,
  }) {
    return AppLockResult(
      success: false,
      packageName: packageName,
      confidence: confidence,
      message: reason,
      session: session,
    );
  }

  @override
  String toString() {
    return 'AppLockResult(success: $success, packageName: $packageName, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}
