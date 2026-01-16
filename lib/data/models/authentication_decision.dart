import 'package:flutter/foundation.dart';
import 'gait_features.dart';

/// Authentication decision result
@immutable
class AuthenticationDecision {
  const AuthenticationDecision({
    required this.userId,
    required this.isAuthenticated,
    required this.confidence,
    required this.decision,
    required this.baselineUsed,
    required this.decisionTimestamp,
    this.comparison,
    this.metadata,
  });

  final int userId;
  final bool isAuthenticated;
  final double confidence;
  final AuthenticationDecisionType decision;
  final String baselineUsed; // ID or description of baseline
  final DateTime decisionTimestamp;
  final Map<String, dynamic>? comparison; // Comparison metrics
  final Map<String, dynamic>? metadata;

  factory AuthenticationDecision.success({
    required int userId,
    required double confidence,
    required String baselineUsed,
    Map<String, dynamic>? comparison,
    Map<String, dynamic>? metadata,
  }) {
    return AuthenticationDecision(
      userId: userId,
      isAuthenticated: true,
      confidence: confidence,
      decision: AuthenticationDecisionType.success,
      baselineUsed: baselineUsed,
      decisionTimestamp: DateTime.now(),
      comparison: comparison,
      metadata: metadata,
    );
  }

  factory AuthenticationDecision.failure({
    required int userId,
    required double confidence,
    required AuthenticationDecisionType decision,
    required String baselineUsed,
    required String reason,
    Map<String, dynamic>? comparison,
    Map<String, dynamic>? metadata,
  }) {
    return AuthenticationDecision(
      userId: userId,
      isAuthenticated: false,
      confidence: confidence,
      decision: decision,
      baselineUsed: baselineUsed,
      decisionTimestamp: DateTime.now(),
      comparison: {
        'reason': reason,
        if (comparison != null) ...comparison,
      },
      metadata: {
        'failure': true,
        if (metadata != null) ...metadata,
      },
    );
  }

  /// Get decision category
  String get decisionCategory {
    if (isAuthenticated) {
      if (confidence >= 0.8) return 'High Confidence';
      if (confidence >= 0.6) return 'Medium Confidence';
      return 'Low Confidence';
    } else {
      switch (decision) {
        case AuthenticationDecisionType.confidenceTooLow:
          return 'Confidence Too Low';
        case AuthenticationDecisionType.patternNotMatched:
          return 'Pattern Not Matched';
        case AuthenticationDecisionType.insufficientData:
          return 'Insufficient Data';
        case AuthenticationDecisionType.baselineNotFound:
          return 'Baseline Not Found';
        case AuthenticationDecisionType.calibrationTooOld:
          return 'Calibration Too Old';
        case AuthenticationDecisionType.systemError:
          return 'System Error';
        default:
          return 'Unknown Error';
      }
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isAuthenticated': isAuthenticated,
      'confidence': confidence,
      'decision': decision.name,
      'decisionCategory': decisionCategory,
      'baselineUsed': baselineUsed,
      'decisionTimestamp': decisionTimestamp.toIso8601String(),
      'comparison': comparison,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory AuthenticationDecision.fromJson(Map<String, dynamic> json) {
    return AuthenticationDecision(
      userId: json['userId'] as int,
      isAuthenticated: json['isAuthenticated'] as bool,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      decision: AuthenticationDecisionType.values.firstWhere(
        (e) => e.name == json['decision'],
        orElse: () => AuthenticationDecisionType.systemError,
      ),
      baselineUsed: json['baselineUsed'] as String? ?? '',
      decisionTimestamp: DateTime.parse(json['decisionTimestamp'] as String),
      comparison: json['comparison'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthenticationDecision &&
        other.userId == userId &&
        other.isAuthenticated == isAuthenticated &&
        other.confidence == confidence &&
        other.decision == decision &&
        other.baselineUsed == baselineUsed &&
        other.decisionTimestamp == decisionTimestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      isAuthenticated,
      confidence,
      decision,
      baselineUsed,
      decisionTimestamp,
    );
  }

  @override
  String toString() {
    return 'AuthenticationDecision('
        'userId: $userId, '
        'authenticated: $isAuthenticated, '
        'confidence: ${confidence.toStringAsFixed(3)}, '
        'decision: $decision, '
        'baseline: $baselineUsed)';
  }
}

/// Types of authentication decisions
enum AuthenticationDecisionType {
  success,
  confidenceTooLow,
  patternNotMatched,
  insufficientData,
  baselineNotFound,
  calibrationTooOld,
  systemError,
}

/// Authentication configuration
@immutable
class AuthenticationConfig {
  const AuthenticationConfig({
    this.confidenceThreshold = 0.7,
    this.minCalibrationAge = const Duration(days: 7),
    this.maxCalibrationAge = const Duration(days: 90),
    this.minSamplesForComparison = 500,
    this.aveTimeWindow = const Duration(seconds: 3),
    this.peakSimilarityThreshold = 0.8,
    this.frequencyTolerance = 0.3,
    this.varianceTolerance = 2.0,
  });

  final double confidenceThreshold;
  final Duration minCalibrationAge;
  final Duration maxCalibrationAge;
  final int minSamplesForComparison;
  final Duration aveTimeWindow;
  final double peakSimilarityThreshold;
  final double frequencyTolerance;
  final double varianceTolerance;

  /// Default configuration for production
  static const AuthenticationConfig production = AuthenticationConfig(
    confidenceThreshold: 0.7,
    minCalibrationAge: Duration(days: 7),
    maxCalibrationAge: Duration(days: 90),
    minSamplesForComparison: 500,
    aveTimeWindow: Duration(seconds: 3),
    peakSimilarityThreshold: 0.8,
    frequencyTolerance: 0.3,
    varianceTolerance: 2.0,
  );

  /// Lenient configuration for testing
  static const AuthenticationConfig lenient = AuthenticationConfig(
    confidenceThreshold: 0.5,
    minCalibrationAge: Duration(days: 3),
    maxCalibrationAge: Duration(days: 180),
    minSamplesForComparison: 200,
    aveTimeWindow: Duration(seconds: 2),
    peakSimilarityThreshold: 0.6,
    frequencyTolerance: 0.5,
    varianceTolerance: 3.0,
  );

  /// Strict configuration for high security
  static const AuthenticationConfig strict = AuthenticationConfig(
    confidenceThreshold: 0.85,
    minCalibrationAge: Duration(days: 1),
    maxCalibrationAge: Duration(days: 30),
    minSamplesForComparison: 1000,
    aveTimeWindow: Duration(seconds: 5),
    peakSimilarityThreshold: 0.9,
    frequencyTolerance: 0.2,
    varianceTolerance: 1.5,
  );
}