import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/calibration_repository.dart';
import '../../../data/repositories/app_lock_repository.dart';
import '../../../core/services/database_service.dart';
import 'settings_state.dart';

/// Cubit for managing settings state.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this.calibrationRepository,
    required this.appLockRepository,
    required this.databaseService,
  }) : super(const SettingsInitial());

  final CalibrationRepository calibrationRepository;
  final AppLockRepository appLockRepository;
  final DatabaseService databaseService;

  // In-memory settings (would be persisted in a real app)
  bool _gaitLockEnabled = true;
  double _unlockThreshold = 0.7;
  bool _isDarkMode = false;

  /// Initialize settings with user ID
  Future<void> initialize(int userId) async {
    emit(const SettingsLoading(message: 'Loading settings...'));

    try {
      await _loadSettings(userId);
    } catch (e) {
      emit(SettingsError(message: 'Failed to load settings: $e', error: e));
    }
  }

  /// Refresh settings data
  Future<void> refresh(int userId) async {
    try {
      await _loadSettings(userId);
    } catch (e) {
      emit(SettingsError(message: 'Failed to refresh: $e', error: e));
    }
  }

  /// Toggle gait lock enabled/disabled
  Future<void> setGaitLockEnabled(bool enabled) async {
    final currentState = state;
    if (currentState is! SettingsLoaded) return;

    _gaitLockEnabled = enabled;
    emit(currentState.copyWith(gaitLockEnabled: enabled));
  }

  /// Update unlock threshold (0.5 - 0.95)
  Future<void> setUnlockThreshold(double threshold) async {
    final currentState = state;
    if (currentState is! SettingsLoaded) return;

    _unlockThreshold = threshold.clamp(0.5, 0.95);
    emit(currentState.copyWith(unlockThreshold: _unlockThreshold));
  }

  /// Toggle dark mode
  Future<void> setDarkMode(bool isDark) async {
    final currentState = state;
    if (currentState is! SettingsLoaded) return;

    _isDarkMode = isDark;
    emit(currentState.copyWith(isDarkMode: isDark));
  }

  /// Delete a specific calibration session
  Future<void> deleteCalibration(int sessionId, int userId) async {
    final currentState = state;
    if (currentState is! SettingsLoaded) return;

    try {
      await calibrationRepository.deleteCalibrationSession(sessionId, userId);
      await _loadSettings(userId);
    } catch (e) {
      emit(SettingsError(message: 'Failed to delete calibration: $e', error: e));
      emit(currentState);
    }
  }

  /// Delete all calibration data for user
  Future<void> deleteAllCalibrations(int userId) async {
    final currentState = state;
    if (currentState is! SettingsLoaded) return;

    emit(const SettingsClearing(message: 'Deleting calibration data...'));

    try {
      final sessions = await calibrationRepository.getCalibrationSessions(userId);
      for (final session in sessions) {
        if (session.id != null) {
          await calibrationRepository.deleteCalibrationSession(session.id!, userId);
        }
      }

      emit(const SettingsDataCleared(message: 'Calibration data deleted'));
      await Future.delayed(const Duration(seconds: 1));
      await _loadSettings(userId);
    } catch (e) {
      emit(SettingsError(message: 'Failed to delete calibrations: $e', error: e));
    }
  }

  /// Clear all user data (calibrations, app locks, etc.)
  Future<void> clearAllData(int userId) async {
    emit(const SettingsClearing(message: 'Clearing all data...'));

    try {
      // Delete calibrations
      final sessions = await calibrationRepository.getCalibrationSessions(userId);
      for (final session in sessions) {
        if (session.id != null) {
          await calibrationRepository.deleteCalibrationSession(session.id!, userId);
        }
      }

      // Reset app lock preferences
      final protectedApps = await appLockRepository.getProtectedApps(userId);
      for (final app in protectedApps) {
        await appLockRepository.setAppProtected(userId, app.packageName, false);
      }

      // Reset settings
      _gaitLockEnabled = true;
      _unlockThreshold = 0.7;
      _isDarkMode = false;

      emit(const SettingsDataCleared(message: 'All data cleared'));
      await Future.delayed(const Duration(seconds: 1));
      await _loadSettings(userId);
    } catch (e) {
      emit(SettingsError(message: 'Failed to clear data: $e', error: e));
    }
  }

  /// Load settings and related data
  Future<void> _loadSettings(int userId) async {
    try {
      // Get calibration data
      final latestCalibration =
          await calibrationRepository.getLatestSuccessfulCalibration(userId);
      final calibrationStats =
          await calibrationRepository.getCalibrationStatistics(userId);

      // Get app lock data
      final appLockStats = await appLockRepository.getAppLockStats(userId);

      emit(SettingsLoaded(
        userId: userId,
        gaitLockEnabled: _gaitLockEnabled,
        unlockThreshold: _unlockThreshold,
        isDarkMode: _isDarkMode,
        latestCalibration: latestCalibration,
        calibrationCount: calibrationStats['totalSessions'] as int? ?? 0,
        protectedAppsCount: appLockStats['protectedAppsCount'] as int? ?? 0,
        totalLockEvents: appLockStats['totalLockSessions'] as int? ?? 0,
      ));
    } catch (e) {
      emit(SettingsError(message: 'Failed to load settings: $e', error: e));
    }
  }
}
