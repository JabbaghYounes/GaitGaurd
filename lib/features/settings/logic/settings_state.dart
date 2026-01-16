import 'package:flutter/foundation.dart';

import '../../../data/models/calibration_session.dart';

/// Base state for settings feature
@immutable
abstract class SettingsState {
  const SettingsState();
}

/// Initial state before loading
class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

/// Loading state during async operations
class SettingsLoading extends SettingsState {
  const SettingsLoading({this.message});

  final String? message;
}

/// Loaded state with all settings data
class SettingsLoaded extends SettingsState {
  const SettingsLoaded({
    required this.userId,
    required this.gaitLockEnabled,
    required this.unlockThreshold,
    required this.isDarkMode,
    this.latestCalibration,
    this.calibrationCount = 0,
    this.protectedAppsCount = 0,
    this.totalLockEvents = 0,
  });

  final int userId;
  final bool gaitLockEnabled;
  final double unlockThreshold;
  final bool isDarkMode;
  final CalibrationSession? latestCalibration;
  final int calibrationCount;
  final int protectedAppsCount;
  final int totalLockEvents;

  /// Whether user has completed calibration
  bool get hasCalibration => latestCalibration != null;

  /// Formatted threshold percentage
  String get thresholdPercentage => '${(unlockThreshold * 100).toInt()}%';

  SettingsLoaded copyWith({
    int? userId,
    bool? gaitLockEnabled,
    double? unlockThreshold,
    bool? isDarkMode,
    CalibrationSession? latestCalibration,
    int? calibrationCount,
    int? protectedAppsCount,
    int? totalLockEvents,
  }) {
    return SettingsLoaded(
      userId: userId ?? this.userId,
      gaitLockEnabled: gaitLockEnabled ?? this.gaitLockEnabled,
      unlockThreshold: unlockThreshold ?? this.unlockThreshold,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      latestCalibration: latestCalibration ?? this.latestCalibration,
      calibrationCount: calibrationCount ?? this.calibrationCount,
      protectedAppsCount: protectedAppsCount ?? this.protectedAppsCount,
      totalLockEvents: totalLockEvents ?? this.totalLockEvents,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsLoaded &&
          other.userId == userId &&
          other.gaitLockEnabled == gaitLockEnabled &&
          other.unlockThreshold == unlockThreshold &&
          other.isDarkMode == isDarkMode &&
          other.calibrationCount == calibrationCount;

  @override
  int get hashCode => Object.hash(
        userId,
        gaitLockEnabled,
        unlockThreshold,
        isDarkMode,
        calibrationCount,
      );
}

/// State when clearing data
class SettingsClearing extends SettingsState {
  const SettingsClearing({required this.message});

  final String message;
}

/// State after data cleared
class SettingsDataCleared extends SettingsState {
  const SettingsDataCleared({required this.message});

  final String message;
}

/// Error state
class SettingsError extends SettingsState {
  const SettingsError({required this.message, this.error});

  final String message;
  final dynamic error;
}
