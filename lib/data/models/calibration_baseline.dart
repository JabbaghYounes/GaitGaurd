import '../models/gait_features.dart';

/// Calibration baseline for gait pattern matching
@immutable
class CalibrationBaseline {
  const CalibrationBaseline({
    required this.id,
    required this.userId,
    required this.features,
    required this.createdAt,
    this.isActive = true,
    this.qualityScore = 0.0,
    this.metadata,
  });

  final int id;
  final int userId;
  final GaitFeatures features;
  final DateTime createdAt;
  final bool isActive;
  final double qualityScore;
  final Map<String, dynamic>? metadata;

  /// Calculate similarity score with another baseline
  double calculateSimilarity(CalibrationBaseline other) {
    return _calculateFeatureSimilarity(features, other.features);
  }

  /// Calculate similarity score with new features
  double calculateSimilarityWithFeatures(GaitFeatures newFeatures) {
    return _calculateFeatureSimilarity(features, newFeatures);
  }

  /// Check if baseline is too old for use
  bool isTooOld(Duration maxAge) {
    return DateTime.now().difference(createdAt) > maxAge;
  }

  /// Check if baseline has sufficient quality
  bool hasSufficientQuality(double minScore) {
    return qualityScore >= minScore;
  }

  /// Create copy with updated values
  CalibrationBaseline copyWith({
    int? id,
    int? userId,
    GaitFeatures? features,
    DateTime? createdAt,
    bool? isActive,
    double? qualityScore,
    Map<String, dynamic>? metadata,
  }) {
    return CalibrationBaseline(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      features: features ?? this.features,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      qualityScore: qualityScore ?? this.qualityScore,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'features': features.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'qualityScore': qualityScore,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory CalibrationBaseline.fromJson(Map<String, dynamic> json) {
    return CalibrationBaseline(
      id: json['id'] as int?,
      userId: json['userId'] as int,
      features: GaitFeatures.fromJson(json['features'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: (json['isActive'] as int?) == 1,
      qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to database map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'features': features.toJson(),
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'quality_score': qualityScore,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  /// Create from database map
  factory CalibrationBaseline.fromMap(Map<String, Object?> map) {
    return CalibrationBaseline(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      features: GaitFeatures.fromJson(map['features'] as Map<String, dynamic>),
      createdAt: DateTime.parse(map['created_at'] as String),
      isActive: (map['is_active'] as int) == 1,
      qualityScore: (map['quality_score'] as num?)?.toDouble() ?? 0.0,
      metadata: map['metadata'] != null
          ? _decodeMetadata(map['metadata'] as String)
          : null,
    );
  }

  /// Private method to calculate feature similarity
  double _calculateFeatureSimilarity(GaitFeatures features1, GaitFeatures features2) {
    double totalScore = 0.0;
    int featureCount = 0;

    // Step frequency similarity (weight: 0.25)
    final freqScore = _calculateSimilarityScore(
        features1.stepFrequency, 
        features2.stepFrequency,
        tolerance: 0.3,
    );
    totalScore += freqScore * 0.25;
    featureCount++;

    // Step regularity similarity (weight: 0.20)
    final regularityScore = _calculateSimilarityScore(
        features1.stepRegularity, 
        features2.stepRegularity,
        tolerance: 0.2,
    );
    totalScore += regularityScore * 0.20;
    featureCount++;

    // Acceleration variance similarity (weight: 0.20)
    final accelScore = _calculateSimilarityScore(
        features1.accelerationVariance, 
        features2.accelerationVariance,
        tolerance: 0.5,
    );
    totalScore += accelScore * 0.20;
    featureCount++;

    // Gyroscope variance similarity (weight: 0.15)
    final gyroScore = _calculateSimilarityScore(
        features1.gyroscopeVariance, 
        features2.gyroscopeVariance,
        tolerance: 0.5,
    );
    totalScore += gyroScore * 0.15;
    featureCount++;

    // Step intensity similarity (weight: 0.10)
    final intensityScore = _calculateSimilarityScore(
        features1.stepIntensity, 
        features2.stepIntensity,
        tolerance: 0.2,
    );
    totalScore += intensityScore * 0.10;
    featureCount++;

    // Walking pattern similarity (weight: 0.10)
    final patternScore = features1.walkingPattern == features2.walkingPattern ? 1.0 : 0.0;
    totalScore += patternScore * 0.10;
    featureCount++;

    return featureCount > 0 ? totalScore / featureCount : 0.0;
  }

  /// Calculate similarity score for two values with tolerance
  double _calculateSimilarityScore(double value1, double value2, double tolerance) {
    final difference = (value1 - value2).abs();
    final maxVal = value1.abs() > value2.abs() ? value1.abs() : value2.abs();
    
    if (maxVal == 0.0) return 1.0; // Both zero
    
    final normalizedDiff = difference / maxVal;
    return (1.0 - normalizedDiff).clamp(0.0, tolerance) / 1.0;
  }

  /// Encode metadata for storage
  String _encodeMetadata(Map<String, dynamic> metadata) {
    // Simple JSON encoding - in production, use dart:convert
    return metadata.toString();
  }

  /// Decode metadata from storage
  Map<String, dynamic> _decodeMetadata(String encoded) {
    // Simple JSON decoding - in production, use dart:convert
    // For now, return empty map as placeholder
    return {};
  }
}

/// Baseline comparison result
@immutable
class BaselineComparison {
  const BaselineComparison({
    required this.baselineId,
    required this.baselineFeatures,
    required this.newFeatures,
    required this.similarityScore,
    required this.comparison,
  });

  final int baselineId;
  final GaitFeatures baselineFeatures;
  final GaitFeatures newFeatures;
  final double similarityScore;
  final Map<String, dynamic> comparison;

  /// Create comparison result
  factory BaselineComparison.create({
    required int baselineId,
    required GaitFeatures baselineFeatures,
    required GaitFeatures newFeatures,
    double similarityScore = 0.7,
  }) {
    final comparison = {
      'stepFrequency': {
        'baseline': baselineFeatures.stepFrequency,
        'current': newFeatures.stepFrequency,
        'difference': (newFeatures.stepFrequency - baselineFeatures.stepFrequency).abs(),
      },
      'stepRegularity': {
        'baseline': baselineFeatures.stepRegularity,
        'current': newFeatures.stepRegularity,
        'difference': (newFeatures.stepRegularity - baselineFeatures.stepRegularity).abs(),
      },
      'accelerationVariance': {
        'baseline': baselineFeatures.accelerationVariance,
        'current': newFeatures.accelerationVariance,
        'difference': (newFeatures.accelerationVariance - baselineFeatures.accelerationVariance).abs(),
      },
      'gyroscopeVariance': {
        'baseline': baselineFeatures.gyroscopeVariance,
        'current': newFeatures.gyroscopeVariance,
        'difference': (newFeatures.gyroscopeVariance - baselineFeatures.gyroscopeVariance).abs(),
      },
      'walkingPattern': {
        'baseline': baselineFeatures.walkingPattern,
        'current': newFeatures.walkingPattern,
        'match': baselineFeatures.walkingPattern == newFeatures.walkingPattern,
      },
    };

    return BaselineComparison(
      baselineId: baselineId,
      baselineFeatures: baselineFeatures,
      newFeatures: newFeatures,
      similarityScore: similarityScore,
      comparison: comparison,
    );
  }

  /// Get detailed comparison report
  String getComparisonReport() {
    final report = <String>[];
    
    report.add('Similarity Score: ${(similarityScore * 100).toStringAsFixed(1)}%');
    report.add('');
    
    final comp = comparison;
    
    if (comp['stepFrequency']['difference'] > 0.5) {
      report.add('⚠ Step frequency differs significantly');
    } else {
      report.add('✓ Step frequency matches well');
    }
    
    if (comp['stepRegularity']['difference'] > 0.3) {
      report.add('⚠ Step regularity differs');
    } else {
      report.add('✓ Step regularity matches well');
    }
    
    if (comp['walkingPattern']['match']) {
      report.add('✓ Walking pattern matches');
    } else {
      report.add('⚠ Walking pattern differs');
    }
    
    if (comp['accelerationVariance']['difference'] > 1.0) {
      report.add('⚠ Acceleration variance differs significantly');
    } else {
      report.add('✓ Acceleration variance is acceptable');
    }
    
    return report.join('\n');
  }

  @override
  String toString() {
    return 'BaselineComparison('
        'similarity: ${(similarityScore * 100).toStringAsFixed(1)}%, '
        'baselineId: $baselineId)';
  }
}