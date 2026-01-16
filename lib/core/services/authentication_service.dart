import 'dart:async';
import '../../data/models/gait_features.dart';
import '../../data/models/authentication_decision.dart';
import '../../data/models/calibration_baseline.dart';

/// Configuration for authentication service.
class AuthenticationConfig {
  const AuthenticationConfig({
    this.minConfidence = 0.7,
    this.maxAttempts = 3,
    this.sessionTimeout = const Duration(minutes: 5),
  });

  final double minConfidence;
  final int maxAttempts;
  final Duration sessionTimeout;
}

/// Authentication decision engine for gait-based biometric authentication.
///
/// This is a simplified implementation for demo purposes.
class AuthenticationService {
  AuthenticationService({
    this.config = const AuthenticationConfig(),
  });

  final AuthenticationConfig config;

  bool _isRecognizing = false;
  double _currentConfidence = 0.0;

  /// Check if system is ready for authentication
  Future<bool> isSystemReady() async {
    return true;
  }

  /// Check if user has an active baseline
  Future<bool> hasActiveBaseline(int userId) async {
    // In a real app, this would check the database
    return true;
  }

  /// Start real-time gait recognition
  Future<void> startRecognition(int userId) async {
    _isRecognizing = true;
    _currentConfidence = 0.0;
  }

  /// Stop real-time gait recognition
  Future<void> stopRecognition() async {
    _isRecognizing = false;
  }

  /// Perform authentication decision
  Future<AuthenticationDecision> makeDecision({
    required int userId,
    required GaitFeatures features,
    String? baselineId,
  }) async {
    // Simulate authentication processing
    await Future.delayed(const Duration(milliseconds: 500));

    // Simple heuristic-based authentication for demo
    final confidence = _calculateConfidence(features);

    if (confidence >= config.minConfidence) {
      return AuthenticationDecision.success(
        userId: userId,
        confidence: confidence,
        baselineUsed: baselineId ?? 'default',
        comparison: {
          'stepFrequency': features.stepFrequency,
          'stepRegularity': features.stepRegularity,
        },
      );
    } else {
      return AuthenticationDecision.failure(
        userId: userId,
        confidence: confidence,
        decision: AuthenticationDecisionType.confidenceTooLow,
        baselineUsed: baselineId ?? 'default',
        reason: 'Confidence too low: ${(confidence * 100).toStringAsFixed(0)}%',
      );
    }
  }

  /// Get authentication statistics for a user
  Future<Map<String, dynamic>> getAuthenticationStats(int userId) async {
    return {
      'totalDecisions': 0,
      'successfulDecisions': 0,
      'successRate': 0.0,
      'averageConfidence': 0.0,
      'lastDecision': null,
      'baselineAvailable': true,
    };
  }

  /// Calculate confidence score from gait features
  double _calculateConfidence(GaitFeatures features) {
    // Simple heuristic: combine regularity and reasonable frequency
    final frequencyScore = _scoreFrequency(features.stepFrequency);
    final regularityScore = features.stepRegularity;
    final varianceScore = _scoreVariance(features.accelerationVariance);

    return (frequencyScore * 0.3 + regularityScore * 0.4 + varianceScore * 0.3)
        .clamp(0.0, 1.0);
  }

  double _scoreFrequency(double frequency) {
    // Normal walking frequency is 1.5-2.5 Hz
    if (frequency >= 1.5 && frequency <= 2.5) return 1.0;
    if (frequency >= 1.0 && frequency <= 3.0) return 0.7;
    return 0.3;
  }

  double _scoreVariance(double variance) {
    // Lower variance is better (more consistent)
    if (variance <= 1.0) return 1.0;
    if (variance <= 2.0) return 0.7;
    if (variance <= 3.0) return 0.5;
    return 0.3;
  }
}
