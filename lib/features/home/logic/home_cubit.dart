import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/calibration_repository.dart';
import '../../../data/repositories/app_lock_repository.dart';
import '../../../data/models/protected_app.dart';
import '../../../data/models/app_lock_session.dart';
import 'home_state.dart';

/// Cubit for managing home screen state.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required this.calibrationRepository,
    required this.appLockRepository,
  }) : super(const HomeInitial());

  final CalibrationRepository calibrationRepository;
  final AppLockRepository appLockRepository;

  // Simulated gait authentication state
  bool _isAuthenticated = false;
  DateTime? _lastAuthTime;
  double _lastConfidence = 0.0;

  /// Initialize home screen with user ID
  Future<void> initialize(int userId) async {
    emit(const HomeLoading(message: 'Loading...'));

    try {
      await _loadHomeData(userId);
    } catch (e) {
      emit(HomeError(message: 'Failed to load data: $e', error: e));
    }
  }

  /// Refresh home screen data
  Future<void> refresh(int userId) async {
    try {
      await _loadHomeData(userId);
    } catch (e) {
      emit(HomeError(message: 'Failed to refresh: $e', error: e));
    }
  }

  /// Simulate gait authentication (for demo purposes)
  Future<void> simulateAuthentication(int userId, {bool success = true}) async {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    // Simulate authentication delay
    emit(const HomeLoading(message: 'Authenticating...'));
    await Future.delayed(const Duration(milliseconds: 800));

    _isAuthenticated = success;
    _lastAuthTime = DateTime.now();
    _lastConfidence = success ? 0.85 : 0.45;

    await _loadHomeData(userId);
  }

  /// Lock all protected apps
  Future<void> lockAllApps(int userId) async {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    try {
      // Lock all protected apps
      for (final app in currentState.protectedApps) {
        final session = AppLockSession(
          userId: userId,
          packageName: app.packageName,
          lockStatus: AppLockStatus.locked,
          lockedAt: DateTime.now(),
        );
        await appLockRepository.createLockSession(session);
      }

      // Update authentication state
      _isAuthenticated = false;
      _lastAuthTime = DateTime.now();
      _lastConfidence = 0.0;

      await _loadHomeData(userId);
    } catch (e) {
      emit(HomeError(message: 'Failed to lock apps: $e', error: e));
    }
  }

  /// Attempt to unlock a specific app
  Future<void> attemptUnlock(int userId, String packageName) async {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    emit(const HomeLoading(message: 'Verifying gait...'));
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      // Simulate successful unlock
      final sessions = await appLockRepository.getActiveLockSessions(userId);
      final session = sessions.firstWhere(
        (s) => s.packageName == packageName,
        orElse: () => throw Exception('No active lock session'),
      );

      // Update session to unlocked
      final unlockedSession = session.copyWith(
        lockStatus: AppLockStatus.unlocked,
        unlockedAt: DateTime.now(),
        unlockConfidence: 0.85,
      );
      await appLockRepository.updateLockSession(unlockedSession);
      _isAuthenticated = true;
      _lastAuthTime = DateTime.now();
      _lastConfidence = 0.85;

      await _loadHomeData(userId);
    } catch (e) {
      emit(HomeError(message: 'Failed to unlock: $e', error: e));
      if (currentState is HomeLoaded) {
        emit(currentState);
      }
    }
  }

  /// Load all home screen data
  Future<void> _loadHomeData(int userId) async {
    try {
      // Get calibration data
      final latestCalibration =
          await calibrationRepository.getLatestSuccessfulCalibration(userId);
      final calibrationStats =
          await calibrationRepository.getCalibrationStatistics(userId);

      // Get app lock data
      final protectedApps = await appLockRepository.getProtectedApps(userId);
      final activeLockSessions =
          await appLockRepository.getActiveLockSessions(userId);
      final stats = await appLockRepository.getAppLockStats(userId);

      // Build locked apps list
      final lockedPackages =
          activeLockSessions.map((s) => s.packageName).toSet();
      final lockedApps = protectedApps
          .where((app) => lockedPackages.contains(app.packageName))
          .map((app) => app.copyWith(isLocked: true))
          .toList();

      // Build gait status
      final hasCalibration = latestCalibration != null;
      final calibrationQuality = latestCalibration?.qualityScore ?? 0.0;

      final successfulUnlocks = stats['successfulUnlocks'] as int? ?? 0;
      final totalLockSessions = stats['totalLockSessions'] as int? ?? 0;
      final successRate = totalLockSessions > 0
          ? successfulUnlocks / totalLockSessions
          : 0.0;

      final gaitStatus = GaitStatus(
        isAuthenticated: _isAuthenticated,
        lastAuthTime: _lastAuthTime,
        confidence: _lastConfidence,
        hasCalibration: hasCalibration,
        calibrationQuality: calibrationQuality,
        successRate: successRate,
        totalDecisions: totalLockSessions,
      );

      emit(HomeLoaded(
        userId: userId,
        gaitStatus: gaitStatus,
        protectedApps: protectedApps,
        lockedApps: lockedApps,
        latestCalibration: latestCalibration,
      ));
    } catch (e) {
      emit(HomeError(message: 'Failed to load home data: $e', error: e));
    }
  }
}
