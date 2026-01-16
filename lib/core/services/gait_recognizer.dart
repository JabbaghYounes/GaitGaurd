import 'package:flutter/foundation.dart';
import '../../data/models/gait_features.dart';

/// Gait recognition result
@immutable
class GaitRecognitionResult {
  const GaitRecognitionResult({
    required this.userId,
    required this.isMatch,
    required this.confidence,
    required this.patternType,
    required this.recognitionTimestamp,
    this.features,
    this.metadata,
  });

  /// User ID for which recognition was performed
  final int userId;
  
  /// Whether the gait pattern matches the user's baseline
  final bool isMatch;
  
  /// Confidence score (0.0 to 1.0)
  final double confidence;
  
  /// Type of gait pattern detected
  final GaitPatternType patternType;
  
  /// When recognition was performed
  final DateTime recognitionTimestamp;
  
  /// Features used for recognition
  final GaitFeatures? features;
  
  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// Create recognition result with match
  factory GaitRecognitionResult.match({
    required int userId,
    required double confidence,
    required GaitPatternType patternType,
    GaitFeatures? features,
    Map<String, dynamic>? metadata,
  }) {
    return GaitRecognitionResult(
      userId: userId,
      isMatch: true,
      confidence: confidence,
      patternType: patternType,
      recognitionTimestamp: DateTime.now(),
      features: features,
      metadata: metadata,
    );
  }

  /// Create recognition result with no match
  factory GaitRecognitionResult.noMatch({
    required int userId,
    required GaitPatternType patternType,
    GaitFeatures? features,
    Map<String, dynamic>? metadata,
  }) {
    return GaitRecognitionResult(
      userId: userId,
      isMatch: false,
      confidence: 0.0,
      patternType: patternType,
      recognitionTimestamp: DateTime.now(),
      features: features,
      metadata: metadata,
    );
  }

  /// Get confidence category
  String get confidenceCategory {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    if (confidence >= 0.4) return 'Low';
    return 'Very Low';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isMatch': isMatch,
      'confidence': confidence,
      'confidenceCategory': confidenceCategory,
      'patternType': patternType.name,
      'recognitionTimestamp': recognitionTimestamp.toIso8601String(),
      'features': features?.toJson(),
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GaitRecognitionResult &&
        other.userId == userId &&
        other.isMatch == isMatch &&
        other.confidence == confidence &&
        other.patternType == patternType;
  }

  @override
  int get hashCode {
    return Object.hash(userId, isMatch, confidence, patternType);
  }

  @override
  String toString() {
    return 'GaitRecognitionResult('
        'userId: $userId, '
        'isMatch: $isMatch, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
        'patternType: $patternType)';
  }
}

/// Types of gait patterns
enum GaitPatternType {
  normal('Normal Walking'),
  irregular('Irregular Walking'),
  limping('Limping'),
  shuffling('Shuffling'),
  unknown('Unknown Pattern');

  const GaitPatternType(this.displayName);
  final String displayName;
}

/// Gait recognition model interface
abstract class GaitRecognizer {
  /// Recognize gait pattern from features
  Future<GaitRecognitionResult> recognize(
    GaitFeatures features,
    int userId,
  );

  /// Train model with calibration data
  Future<void> train(List<GaitFeatures> trainingData, int userId);

  /// Check if model is trained for user
  Future<bool> isTrained(int userId);

  /// Get model information
  Future<Map<String, dynamic>> getModelInfo(int userId);
}

/// Lightweight heuristic-based gait recognizer
class HeuristicGaitRecognizer implements GaitRecognizer {
  const HeuristicGaitRecognizer();

  @override
  Future<GaitRecognitionResult> recognize(GaitFeatures features, int userId) async {
    // Use simple heuristic rules for recognition
    final matchScore = _calculateHeuristicScore(features);
    final threshold = _getThresholdForPattern(features.walkingPattern);
    
    final isMatch = matchScore >= threshold;
    final confidence = _calculateConfidence(matchScore, threshold);

    final patternType = _classifyPattern(features);

    return GaitRecognitionResult(
      userId: userId,
      isMatch: isMatch,
      confidence: confidence,
      patternType: patternType,
      recognitionTimestamp: DateTime.now(),
      features: features,
      metadata: {
        'method': 'heuristic',
        'matchScore': matchScore,
        'threshold': threshold,
      },
    );
  }

  @override
  Future<void> train(List<GaitFeatures> trainingData, int userId) async {
    // Heuristic recognizer doesn't need training
    // Just validate training data quality
    if (trainingData.isNotEmpty) {
      final avgQuality = trainingData
          .map((f) => f.stepRegularity)
          .reduce((a, b) => a + b) / trainingData.length;
      
      print('Heuristic recognizer trained for user $userId with avg quality: ${avgQuality.toStringAsFixed(3)}');
    }
  }

  @override
  Future<bool> isTrained(int userId) async {
    // Heuristic recognizer is always "trained"
    return true;
  }

  @override
  Future<Map<String, dynamic>> getModelInfo(int userId) async {
    return {
      'type': 'heuristic',
      'version': '1.0.0',
      'trained': true,
      'userId': userId,
      'description': 'Lightweight rule-based gait recognition',
      'features': ['stepFrequency', 'stepRegularity', 'accelerationVariance', 
                  'gyroscopeVariance', 'stepIntensity', 'walkingPattern'],
      'accuracy': 'moderate',
      'performance': 'high',
    };
  }

  /// Calculate heuristic match score
  double _calculateHeuristicScore(GaitFeatures features) {
    double score = 0.0;

    // Step frequency scoring (normal walking is 1.8-2.2 steps/second)
    final freqScore = _scoreFrequency(features.stepFrequency);
    score += freqScore * 0.25;

    // Step regularity scoring
    score += features.stepRegularity * 0.20;

    // Intensity scoring (moderate intensity is good)
    final intensityScore = _scoreIntensity(features.stepIntensity);
    score += intensityScore * 0.15;

    // Pattern scoring
    final patternScore = _scorePattern(features.walkingPattern);
    score += patternScore * 0.20;

    // Variance scoring (lower variance is better)
    final varianceScore = _scoreVariance(features.accelerationVariance, features.gyroscopeVariance);
    score += varianceScore * 0.20;

    return score.clamp(0.0, 1.0);
  }

  /// Score step frequency (ideal: 1.8-2.2 Hz)
  double _scoreFrequency(double frequency) {
    if (frequency >= 1.8 && frequency <= 2.2) return 1.0;
    if (frequency >= 1.5 && frequency <= 2.5) return 0.8;
    if (frequency >= 1.0 && frequency <= 3.0) return 0.6;
    if (frequency >= 0.5 && frequency <= 4.0) return 0.4;
    return 0.2;
  }

  /// Score step intensity (ideal: 0.4-0.7)
  double _scoreIntensity(double intensity) {
    if (intensity >= 0.4 && intensity <= 0.7) return 1.0;
    if (intensity >= 0.3 && intensity <= 0.8) return 0.8;
    if (intensity >= 0.2 && intensity <= 0.9) return 0.6;
    return 0.3;
  }

  /// Score walking pattern
  double _scorePattern(int walkingPattern) {
    switch (walkingPattern) {
      case 0: // Normal walking
        return 1.0;
      case 1: // Irregular walking
        return 0.6;
      case 2: // Limping
        return 0.3;
      default:
        return 0.4;
    }
  }

  /// Score variance (lower is better)
  double _scoreVariance(double accelVariance, double gyroVariance) {
    final totalVariance = accelVariance + gyroVariance;
    
    if (totalVariance < 0.5) return 1.0;
    if (totalVariance < 1.0) return 0.8;
    if (totalVariance < 2.0) return 0.6;
    if (totalVariance < 5.0) return 0.4;
    return 0.2;
  }

  /// Calculate confidence from score and threshold
  double _calculateConfidence(double score, double threshold) {
    if (threshold == 0.0) return 0.0;
    return (score / threshold).clamp(0.0, 1.0);
  }

  /// Get threshold based on walking pattern
  double _getThresholdForPattern(int walkingPattern) {
    switch (walkingPattern) {
      case 0: // Normal walking - lower threshold
        return 0.6;
      case 1: // Irregular walking - medium threshold
        return 0.7;
      case 2: // Limping - higher threshold
        return 0.8;
      default:
        return 0.7;
    }
  }

  /// Classify overall pattern type
  GaitPatternType _classifyPattern(GaitFeatures features) {
    // Combine multiple features for pattern classification
    final regularityScore = features.stepRegularity;
    final patternScore = features.walkingPattern;
    final intensityScore = features.stepIntensity;
    final varianceScore = 1.0 - (features.accelerationVariance + features.gyroscopeVariance).clamp(0.0, 10.0) / 10.0;

    // Weighted scoring for pattern classification
    final combinedScore = (regularityScore * 0.4) + 
                        (patternScore * 0.3) + 
                        (intensityScore * 0.2) + 
                        (varianceScore * 0.1);

    if (combinedScore >= 0.8) {
      return GaitPatternType.normal;
    } else if (combinedScore >= 0.5) {
      return GaitPatternType.irregular;
    } else if (varianceScore < 0.3 && regularityScore < 0.5) {
      return GaitPatternType.limping;
    } else if (varianceScore < 0.4) {
      return GaitPatternType.shuffling;
    } else {
      return GaitPatternType.unknown;
    }
  }
}

/// Simple ML-based recognizer (stub for future implementation)
class MLGaitRecognizer implements GaitRecognizer {
  const MLGaitRecognizer({
    required this.modelPath,
    this.modelVersion = '1.0.0',
  });

  final String modelPath;
  final String modelVersion;

  @override
  Future<GaitRecognitionResult> recognize(GaitFeatures features, int userId) async {
    // Stub implementation - would use real ML model
    await Future.delayed(const Duration(milliseconds: 50)); // Simulate inference time

    // Simple mock ML logic
    final randomScore = 0.7 + (DateTime.now().millisecond % 100) / 300.0;
    final isMatch = randomScore > 0.8;
    
    return GaitRecognitionResult(
      userId: userId,
      isMatch: isMatch,
      confidence: isMatch ? randomScore : 0.0,
      patternType: isMatch ? GaitPatternType.normal : GaitPatternType.irregular,
      recognitionTimestamp: DateTime.now(),
      features: features,
      metadata: {
        'method': 'ml',
        'modelVersion': modelVersion,
        'modelPath': modelPath,
        'inferenceTime': '50ms',
      },
    );
  }

  @override
  Future<void> train(List<GaitFeatures> trainingData, int userId) async {
    // Stub implementation - would train real ML model
    await Future.delayed(const Duration(seconds: 2)); // Simulate training time
    
    print('ML model trained for user $userId with ${trainingData.length} samples');
  }

  @override
  Future<bool> isTrained(int userId) async {
    // Stub implementation - would check if model exists
    return true; // Assume trained for demo
  }

  @override
  Future<Map<String, dynamic>> getModelInfo(int userId) async {
    return {
      'type': 'ml',
      'version': modelVersion,
      'modelPath': modelPath,
      'trained': true,
      'userId': userId,
      'description': 'Machine learning based gait recognition',
      'features': ['stepFrequency', 'stepRegularity', 'accelerationVariance', 
                  'gyroscopeVariance', 'stepIntensity', 'walkingPattern'],
      'accuracy': 'high',
      'performance': 'medium',
    };
  }
}