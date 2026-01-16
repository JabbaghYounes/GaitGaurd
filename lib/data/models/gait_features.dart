import 'package:flutter/foundation.dart';
import 'sensor_reading.dart';

/// Gait feature vector extracted from sensor data.
@immutable
class GaitFeatures {
  const GaitFeatures({
    required this.stepFrequency,
    required this.stepRegularity,
    required this.accelerationVariance,
    required this.gyroscopeVariance,
    required this.stepIntensity,
    required this.walkingPattern,
    required this.featuresTimestamp,
    required this.windowDuration,
  });

  /// Average steps per second
  final double stepFrequency;
  
  /// Consistency of step timing (0.0 to 1.0)
  final double stepRegularity;
  
  /// Variance in accelerometer magnitude
  final double accelerationVariance;
  
  /// Variance in gyroscope magnitude
  final double gyroscopeVariance;
  
  /// Average intensity of movement
  final double stepIntensity;
  
  /// Walking pattern classification (0: normal, 1: irregular, 2: limping)
  final int walkingPattern;
  
  /// When features were extracted
  final DateTime featuresTimestamp;
  
  /// Duration of analysis window
  final Duration windowDuration;

  /// Create feature vector for ML model
  List<double> toVector() {
    return [
      stepFrequency,
      stepRegularity,
      accelerationVariance,
      gyroscopeVariance,
      stepIntensity,
      walkingPattern.toDouble(),
    ];
  }

  /// Create a copy with updated values
  GaitFeatures copyWith({
    double? stepFrequency,
    double? stepRegularity,
    double? accelerationVariance,
    double? gyroscopeVariance,
    double? stepIntensity,
    int? walkingPattern,
    DateTime? featuresTimestamp,
    Duration? windowDuration,
  }) {
    return GaitFeatures(
      stepFrequency: stepFrequency ?? this.stepFrequency,
      stepRegularity: stepRegularity ?? this.stepRegularity,
      accelerationVariance: accelerationVariance ?? this.accelerationVariance,
      gyroscopeVariance: gyroscopeVariance ?? this.gyroscopeVariance,
      stepIntensity: stepIntensity ?? this.stepIntensity,
      walkingPattern: walkingPattern ?? this.walkingPattern,
      featuresTimestamp: featuresTimestamp ?? this.featuresTimestamp,
      windowDuration: windowDuration ?? this.windowDuration,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'stepFrequency': stepFrequency,
      'stepRegularity': stepRegularity,
      'accelerationVariance': accelerationVariance,
      'gyroscopeVariance': gyroscopeVariance,
      'stepIntensity': stepIntensity,
      'walkingPattern': walkingPattern,
      'featuresTimestamp': featuresTimestamp.toIso8601String(),
      'windowDuration': windowDuration.inMilliseconds,
    };
  }

  /// Create from JSON
  factory GaitFeatures.fromJson(Map<String, dynamic> json) {
    return GaitFeatures(
      stepFrequency: json['stepFrequency'] as double,
      stepRegularity: json['stepRegularity'] as double,
      accelerationVariance: json['accelerationVariance'] as double,
      gyroscopeVariance: json['gyroscopeVariance'] as double,
      stepIntensity: json['stepIntensity'] as double,
      walkingPattern: json['walkingPattern'] as int,
      featuresTimestamp: DateTime.parse(json['featuresTimestamp'] as String),
      windowDuration: Duration(milliseconds: json['windowDuration'] as int),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GaitFeatures &&
        other.stepFrequency == stepFrequency &&
        other.stepRegularity == stepRegularity &&
        other.accelerationVariance == accelerationVariance &&
        other.gyroscopeVariance == gyroscopeVariance &&
        other.stepIntensity == stepIntensity &&
        other.walkingPattern == walkingPattern;
  }

  @override
  int get hashCode {
    return Object.hash(
      stepFrequency,
      stepRegularity,
      accelerationVariance,
      gyroscopeVariance,
      stepIntensity,
      walkingPattern,
    );
  }

  @override
  String toString() {
    return 'GaitFeatures('
        'stepFrequency: ${stepFrequency.toStringAsFixed(2)}, '
        'stepRegularity: ${stepRegularity.toStringAsFixed(3)}, '
        'accelerationVariance: ${accelerationVariance.toStringAsFixed(3)}, '
        'gyroscopeVariance: ${gyroscopeVariance.toStringAsFixed(3)}, '
        'stepIntensity: ${stepIntensity.toStringAsFixed(3)}, '
        'walkingPattern: $walkingPattern)';
  }
}