import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/authentication_decision.dart';
import '../../../data/models/gait_features.dart';
import '../../../core/services/authentication_service.dart';

/// Authentication decision state classes
abstract class AuthenticationState {
  const AuthenticationState();
}

class AuthenticationInitial extends AuthenticationState {
  const AuthenticationInitial();
}

class AuthenticationLoading extends AuthenticationState {
  const AuthenticationLoading();
}

class AuthenticationReady extends AuthenticationState {
  const AuthenticationReady({
    required this.userId,
    required this.baselineAvailable,
    required this.systemReady,
  });

  final int userId;
  final bool baselineAvailable;
  final bool systemReady;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticationReady &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          baselineAvailable == other.baselineAvailable &&
          systemReady == other.systemReady;

  @override
  int get hashCode =>
      userId.hashCode ^ baselineAvailable.hashCode ^ systemReady.hashCode;
}

class AuthenticationInProgress extends AuthenticationState {
  const AuthenticationInProgress({
    required this.userId,
    this.currentConfidence = 0.0,
    this.isRealTime = false,
    this.attempts = 0,
  });

  final int userId;
  final double currentConfidence;
  final bool isRealTime;
  final int attempts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticationInProgress &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          currentConfidence == other.currentConfidence &&
          isRealTime == other.isRealTime &&
          attempts == other.attempts;

  @override
  int get hashCode =>
      userId.hashCode ^
      currentConfidence.hashCode ^
      isRealTime.hashCode ^
      attempts.hashCode;
}

class AuthenticationSuccess extends AuthenticationState {
  const AuthenticationSuccess({
    required this.userId,
    required this.decision,
    this.sessionDuration = const Duration(seconds: 3),
  });

  final int userId;
  final AuthenticationDecision decision;
  final Duration sessionDuration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticationSuccess &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          decision == other.decision;

  @override
  int get hashCode => userId.hashCode ^ decision.hashCode;
}

class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure({
    required this.userId,
    this.decision,
    this.errorMessage,
  });

  final int userId;
  final AuthenticationDecision? decision;
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticationFailure &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          decision == other.decision &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      userId.hashCode ^ decision.hashCode ^ errorMessage.hashCode;
}

/// Authentication cubit for managing biometric authentication decisions
class AuthenticationCubit extends Cubit<AuthenticationState> {
  AuthenticationCubit(this._authenticationService)
      : super(const AuthenticationInitial());

  final AuthenticationService _authenticationService;

  /// Initialize authentication system
  Future<void> initialize(int userId) async {
    emit(const AuthenticationLoading());

    try {
      final systemReady = await _authenticationService.isSystemReady();
      final baselineAvailable =
          await _authenticationService.hasActiveBaseline(userId);

      if (systemReady) {
        emit(AuthenticationReady(
          userId: userId,
          baselineAvailable: baselineAvailable,
          systemReady: systemReady,
        ));
      } else {
        emit(AuthenticationFailure(
          userId: userId,
          errorMessage: 'Authentication system not ready',
        ));
      }
    } catch (e) {
      emit(AuthenticationFailure(
        userId: userId,
        errorMessage: 'Failed to initialize: $e',
      ));
    }
  }

  /// Start real-time gait recognition
  Future<void> startRealtimeRecognition(int userId) async {
    final currentState = state;
    if (currentState is! AuthenticationReady) {
      emit(AuthenticationFailure(
        userId: userId,
        errorMessage: 'Authentication not ready for recognition',
      ));
      return;
    }

    emit(AuthenticationInProgress(
      userId: userId,
      currentConfidence: 0.0,
      isRealTime: true,
      attempts: 1,
    ));

    try {
      await _authenticationService.startRecognition(userId);
    } catch (e) {
      emit(AuthenticationFailure(
        userId: userId,
        errorMessage: 'Failed to start recognition: $e',
      ));
    }
  }

  /// Stop real-time gait recognition
  Future<void> stopRealtimeRecognition(int userId) async {
    try {
      await _authenticationService.stopRecognition();

      emit(AuthenticationReady(
        userId: userId,
        baselineAvailable: true,
        systemReady: true,
      ));
    } catch (e) {
      emit(AuthenticationFailure(
        userId: userId,
        errorMessage: 'Failed to stop recognition: $e',
      ));
    }
  }

  /// Perform one-time recognition
  Future<void> performRecognition({
    required int userId,
    required GaitFeatures features,
    String? baselineId,
  }) async {
    emit(const AuthenticationLoading());

    try {
      final decision = await _authenticationService.makeDecision(
        userId: userId,
        features: features,
        baselineId: baselineId,
      );

      if (decision.isAuthenticated) {
        emit(AuthenticationSuccess(
          userId: userId,
          decision: decision,
          sessionDuration: const Duration(seconds: 2),
        ));
      } else {
        emit(AuthenticationFailure(
          userId: userId,
          decision: decision,
          errorMessage: decision.comparison?['reason'] as String?,
        ));
      }
    } catch (e) {
      emit(AuthenticationFailure(
        userId: userId,
        errorMessage: 'Recognition failed: $e',
      ));
    }
  }

  /// Update confidence from real-time processing
  void updateConfidence(double confidence, int userId) {
    final currentState = state;
    if (currentState is AuthenticationInProgress) {
      emit(AuthenticationInProgress(
        userId: currentState.userId,
        currentConfidence: confidence,
        isRealTime: currentState.isRealTime,
        attempts: currentState.attempts + 1,
      ));
    }
  }
}
