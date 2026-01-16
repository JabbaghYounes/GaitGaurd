import '../../data/models/gait_features.dart';
import '../../data/models/authentication_decision.dart';
import '../../data/models/calibration_baseline.dart';

/// Security level for authentication
enum SecurityLevel {
  low,
  medium,
  high,
  max,
}

/// Confidence threshold manager for authentication decisions
class ConfidenceThresholdManager {
  ConfidenceThresholdManager({
    this.baseThreshold = 0.7,
    this.securityLevel = SecurityLevel.medium,
  });

  final double baseThreshold;
  final SecurityLevel securityLevel;

  /// Get current confidence threshold
  double get currentThreshold {
    switch (securityLevel) {
      case SecurityLevel.low:
        return baseThreshold - 0.1;
      case SecurityLevel.medium:
        return baseThreshold;
      case SecurityLevel.high:
        return baseThreshold + 0.1;
      case SecurityLevel.max:
        return baseThreshold + 0.2;
    }
  }

  /// Adjust threshold based on recent performance
  double adjustThresholdBasedOnPerformance(
    List<AuthenticationDecision> recentDecisions,
    double currentThreshold,
  ) {
    if (recentDecisions.length < 5) return currentThreshold;

    final recentSuccesses =
        recentDecisions.where((d) => d.isAuthenticated).length;
    final successRate = recentSuccesses / recentDecisions.length;

    if (successRate > 0.9) {
      return (currentThreshold + 0.05).clamp(0.5, 0.95);
    } else if (successRate < 0.5) {
      return (currentThreshold - 0.05).clamp(0.3, 0.8);
    }
    return currentThreshold;
  }

  /// Calculate adaptive threshold based on quality
  double calculateAdaptiveThreshold({
    CalibrationBaseline? baseline,
    required GaitFeatures features,
    required double baseThreshold,
  }) {
    if (baseline == null) return baseThreshold;

    final baselineQuality = baseline.qualityScore;
    final currentQuality = _calculateCurrentQuality(features);
    final qualityDiff = currentQuality - baselineQuality;

    if (qualityDiff > 0.3) {
      return (baseThreshold + 0.15).clamp(0.5, 0.95);
    } else if (qualityDiff < -0.3) {
      return (baseThreshold - 0.1).clamp(0.3, 0.8);
    }
    return baseThreshold;
  }

  double _calculateCurrentQuality(GaitFeatures features) {
    final regularityScore = features.stepRegularity;
    final varianceScore = (1.0 -
        (features.accelerationVariance + features.gyroscopeVariance)
                .clamp(0.0, 5.0) /
            5.0);
    final patternScore = features.walkingPattern == 0 ? 1.0 : 0.5;

    return (regularityScore * 0.4) + (varianceScore * 0.3) + (patternScore * 0.3);
  }

  /// Check if threshold should be increased
  bool shouldIncreaseThreshold({
    required int recentAttempts,
    required int recentSuccesses,
    required double currentThreshold,
    required double maxThreshold,
  }) {
    if (recentAttempts < 10) return false;

    final failureRate = (recentAttempts - recentSuccesses) / recentAttempts;
    return failureRate > 0.3 && currentThreshold < maxThreshold;
  }

  /// Check if threshold should be decreased
  bool shouldDecreaseThreshold({
    required int recentAttempts,
    required int recentSuccesses,
    required double currentThreshold,
    required double minThreshold,
  }) {
    if (recentAttempts < 10) return false;

    final failureRate = (recentAttempts - recentSuccesses) / recentAttempts;
    return failureRate > 0.7 && currentThreshold > minThreshold;
  }

  /// Get recommended threshold adjustments
  Map<String, dynamic> getRecommendations({
    required List<AuthenticationDecision> recentDecisions,
    required double currentThreshold,
  }) {
    final recommendations = <String, dynamic>{};

    if (recentDecisions.length < 5) {
      return {'message': 'Not enough data for recommendations'};
    }

    final recentSuccesses =
        recentDecisions.where((d) => d.isAuthenticated).length;
    final successRate = recentSuccesses / recentDecisions.length;

    recommendations['successRate'] = {
      'current': successRate.toStringAsFixed(2),
      'target': '0.75',
      'status': successRate >= 0.75 ? 'Good' : 'Needs Improvement',
    };

    recommendations['thresholdAdjustment'] = {
      'current': currentThreshold.toStringAsFixed(2),
      'recommended':
          _calculateRecommendedThreshold(successRate, currentThreshold),
      'action': _getThresholdAction(successRate),
    };

    return recommendations;
  }

  double _calculateRecommendedThreshold(
      double successRate, double currentThreshold) {
    if (successRate > 0.85) {
      return (currentThreshold - 0.05).clamp(0.4, 0.9);
    } else if (successRate < 0.6) {
      return (currentThreshold + 0.05).clamp(0.5, 0.9);
    }
    return currentThreshold;
  }

  String _getThresholdAction(double successRate) {
    if (successRate > 0.85) {
      return 'consider_decreasing';
    } else if (successRate < 0.6) {
      return 'consider_increasing';
    }
    return 'maintain';
  }
}
