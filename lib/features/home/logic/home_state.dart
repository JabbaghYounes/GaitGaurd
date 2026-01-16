import 'package:flutter/foundation.dart';

import '../../../data/models/protected_app.dart';
import '../../../data/models/calibration_session.dart';

/// Base state for home screen
@immutable
abstract class HomeState {
  const HomeState();
}

/// Initial state before loading
class HomeInitial extends HomeState {
  const HomeInitial();
}

/// Loading state during async operations
class HomeLoading extends HomeState {
  const HomeLoading({this.message});

  final String? message;
}

/// Gait authentication status
@immutable
class GaitStatus {
  const GaitStatus({
    required this.isAuthenticated,
    required this.lastAuthTime,
    required this.confidence,
    required this.hasCalibration,
    this.calibrationQuality = 0.0,
    this.successRate = 0.0,
    this.totalDecisions = 0,
  });

  /// Whether user is currently authenticated via gait
  final bool isAuthenticated;

  /// Time of last authentication attempt
  final DateTime? lastAuthTime;

  /// Confidence level of last authentication (0.0 - 1.0)
  final double confidence;

  /// Whether user has completed calibration
  final bool hasCalibration;

  /// Quality score of calibration (0.0 - 1.0)
  final double calibrationQuality;

  /// Success rate of recent authentications
  final double successRate;

  /// Total number of authentication decisions
  final int totalDecisions;

  /// Formatted confidence percentage
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(0)}%';

  /// Formatted success rate percentage
  String get successRatePercentage => '${(successRate * 100).toStringAsFixed(0)}%';

  /// Status text for display
  String get statusText {
    if (!hasCalibration) return 'Calibration Required';
    if (isAuthenticated) return 'Authenticated';
    return 'Not Authenticated';
  }

  /// Time since last authentication
  String get timeSinceAuth {
    if (lastAuthTime == null) return 'Never';

    final difference = DateTime.now().difference(lastAuthTime!);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  GaitStatus copyWith({
    bool? isAuthenticated,
    DateTime? lastAuthTime,
    double? confidence,
    bool? hasCalibration,
    double? calibrationQuality,
    double? successRate,
    int? totalDecisions,
  }) {
    return GaitStatus(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      lastAuthTime: lastAuthTime ?? this.lastAuthTime,
      confidence: confidence ?? this.confidence,
      hasCalibration: hasCalibration ?? this.hasCalibration,
      calibrationQuality: calibrationQuality ?? this.calibrationQuality,
      successRate: successRate ?? this.successRate,
      totalDecisions: totalDecisions ?? this.totalDecisions,
    );
  }
}

/// Loaded state with all home data
class HomeLoaded extends HomeState {
  const HomeLoaded({
    required this.userId,
    required this.gaitStatus,
    required this.protectedApps,
    required this.lockedApps,
    this.latestCalibration,
  });

  final int userId;
  final GaitStatus gaitStatus;
  final List<ProtectedApp> protectedApps;
  final List<ProtectedApp> lockedApps;
  final CalibrationSession? latestCalibration;

  /// Whether there are any protected apps
  bool get hasProtectedApps => protectedApps.isNotEmpty;

  /// Whether there are any locked apps
  bool get hasLockedApps => lockedApps.isNotEmpty;

  /// Count of protected apps
  int get protectedCount => protectedApps.length;

  /// Count of locked apps
  int get lockedCount => lockedApps.length;

  HomeLoaded copyWith({
    int? userId,
    GaitStatus? gaitStatus,
    List<ProtectedApp>? protectedApps,
    List<ProtectedApp>? lockedApps,
    CalibrationSession? latestCalibration,
  }) {
    return HomeLoaded(
      userId: userId ?? this.userId,
      gaitStatus: gaitStatus ?? this.gaitStatus,
      protectedApps: protectedApps ?? this.protectedApps,
      lockedApps: lockedApps ?? this.lockedApps,
      latestCalibration: latestCalibration ?? this.latestCalibration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeLoaded &&
          other.userId == userId &&
          other.gaitStatus == gaitStatus &&
          other.protectedCount == protectedCount &&
          other.lockedCount == lockedCount;

  @override
  int get hashCode => Object.hash(
        userId,
        gaitStatus,
        protectedCount,
        lockedCount,
      );
}

/// Error state
class HomeError extends HomeState {
  const HomeError({required this.message, this.error});

  final String message;
  final dynamic error;
}
