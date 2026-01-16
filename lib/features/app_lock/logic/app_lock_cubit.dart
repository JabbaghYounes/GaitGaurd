import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/app_lock_service.dart';
import '../../../data/models/protected_app.dart';
import '../../../data/models/authentication_decision.dart';
import 'app_lock_state.dart';

/// Cubit for managing app lock UI state.
class AppLockCubit extends Cubit<AppLockState> {
  AppLockCubit(this._service) : super(const AppLockInitial());

  final AppLockService _service;
  StreamSubscription<AppLockEvent>? _eventSubscription;
  int? _userId;

  /// Initialize the cubit with user ID
  Future<void> initialize(int userId) async {
    _userId = userId;
    emit(const AppLockLoading(message: 'Loading apps...'));

    try {
      // Subscribe to lock events
      _eventSubscription = _service.lockEvents.listen(_handleLockEvent);

      await _loadApps(userId);
    } catch (e) {
      emit(AppLockError(message: 'Failed to initialize: $e', error: e));
    }
  }

  /// Reload app list
  Future<void> refresh() async {
    if (_userId == null) return;

    emit(const AppLockLoading(message: 'Refreshing...'));
    await _loadApps(_userId!);
  }

  /// Toggle protection for an app
  Future<void> toggleAppProtection(String packageName) async {
    if (_userId == null) return;

    final currentState = state;
    if (currentState is! AppLockReady) return;

    try {
      // Find current protection state
      final app = currentState.availableApps.firstWhere(
        (a) => a.packageName == packageName,
        orElse: () => ProtectedApp(
          packageName: packageName,
          displayName: packageName,
        ),
      );

      // Toggle protection
      await _service.setAppProtection(
        _userId!,
        packageName,
        !app.isProtected,
      );

      // Reload apps to get updated state
      await _loadApps(_userId!);
    } catch (e) {
      emit(AppLockError(
        message: 'Failed to toggle protection: $e',
        error: e,
      ));
      // Return to previous state
      emit(currentState);
    }
  }

  /// Lock all protected apps (simulates gait failure)
  Future<void> lockAllApps() async {
    if (_userId == null) return;

    final currentState = state;
    if (currentState is! AppLockReady) return;

    try {
      emit(const AppLockLoading(message: 'Locking apps...'));

      await _service.lockAllProtectedApps(_userId!);

      // Reload to show locked state
      await _loadApps(_userId!);

      // Show locked notification
      final lockedApps = await _service.getLockedApps(_userId!);
      if (lockedApps.isNotEmpty) {
        emit(AppLockAllLocked(
          userId: _userId!,
          lockedCount: lockedApps.length,
          reason: 'Gait authentication failed',
        ));

        // Reload to ready state after brief delay
        await Future.delayed(const Duration(seconds: 2));
        await _loadApps(_userId!);
      }
    } catch (e) {
      emit(AppLockError(message: 'Failed to lock apps: $e', error: e));
    }
  }

  /// Attempt to unlock a specific app
  Future<void> attemptUnlock(String packageName, String displayName) async {
    if (_userId == null) return;

    try {
      emit(AppLockAuthenticating(
        userId: _userId!,
        packageName: packageName,
        displayName: displayName,
      ));

      // Simulate gait recognition (in real app, this would use actual sensor data)
      // For demo, we'll use a mock confidence value
      await Future.delayed(const Duration(seconds: 2));

      // Simulate varying confidence (0.5 - 0.9)
      final mockConfidence = 0.5 + (DateTime.now().millisecond % 40) / 100;

      final result = await _service.attemptUnlock(
        userId: _userId!,
        packageName: packageName,
        confidence: mockConfidence,
      );

      if (result.success) {
        emit(AppLockUnlockSuccess(
          userId: _userId!,
          packageName: packageName,
          displayName: displayName,
          confidence: result.confidence,
          session: result.session,
        ));

        // Return to ready state after showing success
        await Future.delayed(const Duration(seconds: 2));
        await _loadApps(_userId!);
      } else {
        emit(AppLockUnlockFailed(
          userId: _userId!,
          packageName: packageName,
          displayName: displayName,
          reason: result.message ?? 'Unknown error',
          confidence: result.confidence,
          session: result.session,
        ));

        // Return to ready state after showing failure
        await Future.delayed(const Duration(seconds: 2));
        await _loadApps(_userId!);
      }
    } catch (e) {
      emit(AppLockError(message: 'Failed to unlock: $e', error: e));
    }
  }

  /// Update confidence during authentication (for real-time feedback)
  void updateConfidence(double confidence) {
    final currentState = state;
    if (currentState is AppLockAuthenticating) {
      emit(currentState.copyWith(currentConfidence: confidence));
    }
  }

  /// Handle gait authentication result from external source
  Future<void> onGaitAuthenticationResult(AuthenticationDecision decision) async {
    if (_userId == null) return;

    try {
      await _service.onGaitAuthenticationResult(_userId!, decision);
      await _loadApps(_userId!);
    } catch (e) {
      emit(AppLockError(
        message: 'Failed to process authentication: $e',
        error: e,
      ));
    }
  }

  /// Cancel current unlock attempt and return to ready state
  Future<void> cancelUnlock() async {
    if (_userId == null) return;
    await _loadApps(_userId!);
  }

  /// Handle lock events from service
  void _handleLockEvent(AppLockEvent event) {
    // Can add additional handling here if needed
    // For now, events are handled via state emissions in the methods above
  }

  /// Load apps and emit ready state
  Future<void> _loadApps(int userId) async {
    try {
      final availableApps = await _service.getAvailableApps(userId);
      final protectedApps = await _service.getProtectedApps(userId);
      final lockedApps = await _service.getLockedApps(userId);
      final stats = await _service.getLockStats(userId);

      emit(AppLockReady(
        userId: userId,
        availableApps: availableApps,
        protectedApps: protectedApps,
        lockedApps: lockedApps,
        stats: stats,
      ));
    } catch (e) {
      emit(AppLockError(message: 'Failed to load apps: $e', error: e));
    }
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}
