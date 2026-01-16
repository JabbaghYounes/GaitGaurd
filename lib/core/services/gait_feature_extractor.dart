import '../../data/models/gait_features.dart';
import '../../data/models/sensor_reading.dart';

/// Feature extractor for gait recognition ML pipeline.
class GaitFeatureExtractor {
  const GaitFeatureExtractor();

  /// Extract features from sensor readings for analysis
  GaitFeatures extractFeatures(List<SensorReading> readings, {
    Duration windowDuration = const Duration(seconds: 5),
  }) {
    if (readings.isEmpty) {
      return _createDefaultFeatures(windowDuration);
    }

    // Filter and validate readings
    final validReadings = _filterValidReadings(readings);
    if (validReadings.length < 10) {
      return _createDefaultFeatures(windowDuration);
    }

    // Extract statistical features
    final stepFrequency = _calculateStepFrequency(validReadings);
    final stepRegularity = _calculateStepRegularity(validReadings);
    final accelerationVariance = _calculateAccelerationVariance(validReadings);
    final gyroscopeVariance = _calculateGyroscopeVariance(validReadings);
    final stepIntensity = _calculateStepIntensity(validReadings);
    final walkingPattern = _classifyWalkingPattern(validReadings);

    return GaitFeatures(
      stepFrequency: stepFrequency,
      stepRegularity: stepRegularity,
      accelerationVariance: accelerationVariance,
      gyroscopeVariance: gyroscopeVariance,
      stepIntensity: stepIntensity,
      walkingPattern: walkingPattern,
      featuresTimestamp: DateTime.now(),
      windowDuration: windowDuration,
    );
  }

  /// Extract real-time features from sliding window
  GaitFeatures extractRealTimeFeatures(List<SensorReading> recentReadings) {
    return extractFeatures(recentReadings, windowDuration: const Duration(seconds: 3));
  }

  /// Get feature extraction statistics
  Map<String, dynamic> getFeatureStatistics(GaitFeatures features) {
    return {
      'extractionTime': features.featuresTimestamp.toIso8601String(),
      'windowDuration': features.windowDuration.inMilliseconds,
      'featureCount': 6, // Number of features extracted
      'features': {
        'stepFrequency': features.stepFrequency,
        'stepRegularity': features.stepRegularity,
        'accelerationVariance': features.accelerationVariance,
        'gyroscopeVariance': features.gyroscopeVariance,
        'stepIntensity': features.stepIntensity,
        'walkingPattern': features.walkingPattern,
      },
    };
  }

  // Private feature extraction methods

  /// Filter out invalid or unsynchronized readings
  List<SensorReading> _filterValidReadings(List<SensorReading> readings) {
    return readings.where((reading) => 
        reading.isTimestampsSynchronized &&
        _isValidReading(reading)
    ).toList();
  }

  /// Validate individual reading
  bool _isValidReading(SensorReading reading) {
    // Check for reasonable sensor values
    final accelMag = reading.accelerometer.magnitude;
    final gyroMag = reading.gyroscope.magnitude;

    // Accelerometer should be around gravity with movement
    if (accelMag < 5.0 || accelMag > 20.0) return false;
    
    // Gyroscope should be reasonable for human movement
    if (gyroMag > 10.0) return false;
    
    return true;
  }

  /// Calculate step frequency from sensor data
  double _calculateStepFrequency(List<SensorReading> readings) {
    if (readings.length < 2) return 0.0;

    // Simple frequency detection using accelerometer peaks
    final accelZValues = readings.map((r) => r.accelerometer.z).toList();
    final peaks = _findPeaks(accelZValues, threshold: 0.5);
    
    if (peaks.isEmpty) return 0.0;

    // Calculate frequency as peaks per second
    final duration = readings.last.timestamp.difference(readings.first.timestamp).inSeconds;
    return peaks.length / duration;
  }

  /// Calculate step regularity (consistency of step timing)
  double _calculateStepRegularity(List<SensorReading> readings) {
    if (readings.length < 10) return 0.0;

    final accelZValues = readings.map((r) => r.accelerometer.z).toList();
    final peaks = _findPeaks(accelZValues, threshold: 0.5);
    
    if (peaks.length < 3) return 0.0;

    // Calculate intervals between peaks
    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add(peaks[i] - peaks[i - 1]);
    }

    if (intervals.isEmpty) return 0.0;

    // Calculate coefficient of variation (lower is more regular)
    final meanInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals
        .map((interval) => (interval - meanInterval) * (interval - meanInterval))
        .reduce((a, b) => a + b) / intervals.length;
    final cv = variance.sqrt() / meanInterval;

    // Convert to regularity score (0.0 to 1.0, higher is more regular)
    return (1.0 / (1.0 + cv)).clamp(0.0, 1.0);
  }

  /// Calculate variance in accelerometer magnitude
  double _calculateAccelerationVariance(List<SensorReading> readings) {
    if (readings.isEmpty) return 0.0;

    final magnitudes = readings
        .map((r) => r.accelerometer.magnitude)
        .toList();

    return _calculateVariance(magnitudes);
  }

  /// Calculate variance in gyroscope magnitude
  double _calculateGyroscopeVariance(List<SensorReading> readings) {
    if (readings.isEmpty) return 0.0;

    final magnitudes = readings
        .map((r) => r.gyroscope.magnitude)
        .toList();

    return _calculateVariance(magnitudes);
  }

  /// Calculate average step intensity
  double _calculateStepIntensity(List<SensorReading> readings) {
    if (readings.isEmpty) return 0.0;

    // Use changes in accelerometer as intensity indicator
    final changes = <double>[];
    for (int i = 1; i < readings.length; i++) {
      final currentMag = readings[i].accelerometer.magnitude;
      final prevMag = readings[i - 1].accelerometer.magnitude;
      changes.add((currentMag - prevMag).abs());
    }

    if (changes.isEmpty) return 0.0;

    // Average absolute change as intensity
    final avgChange = changes.reduce((a, b) => a + b) / changes.length;
    
    // Normalize to 0-1 range based on typical walking intensity
    return (avgChange / 2.0).clamp(0.0, 1.0);
  }

  /// Classify walking pattern (0: normal, 1: irregular, 2: limping)
  int _classifyWalkingPattern(List<SensorReading> readings) {
    if (readings.length < 20) return 1; // Not enough data

    final accelXValues = readings.map((r) => r.accelerometer.x).toList();
    final accelYValues = readings.map((r) => r.accelerometer.y).toList();

    // Detect asymmetry in movement (potential limping)
    final xVariance = _calculateVariance(accelXValues);
    final yVariance = _calculateVariance(accelYValues);
    final xyRatio = xVariance / (yVariance + 0.001);

    // High asymmetry indicates potential limping
    if (xyRatio > 2.0 || xyRatio < 0.5) {
      return 2; // Limping
    }

    // Check for regularity using the step regularity we calculated
    final stepRegularity = _calculateStepRegularity(readings);
    
    if (stepRegularity > 0.7) {
      return 0; // Normal walking
    } else {
      return 1; // Irregular walking
    }
  }

  /// Find peaks in signal for step detection
  List<int> _findPeaks(List<double> values, {double threshold = 0.3}) {
    final peaks = <int>[];
    final thresholded = _calculateVariance(values).sqrt();

    for (int i = 1; i < values.length - 1; i++) {
      if (values[i] > values[i - 1] && 
          values[i] > values[i + 1] && 
          values[i] - _calculateMean(values) > threshold * thresholded) {
        peaks.add(i);
      }
    }

    return peaks;
  }

  /// Calculate variance of a list of values
  double _calculateVariance(List<double> values) {
    if (values.length < 2) return 0.0;

    final mean = _calculateMean(values);
    final squaredDiffs = values
        .map((value) => (value - mean) * (value - mean))
        .toList();
    
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate mean of a list of values
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Create default features when extraction fails
  GaitFeatures _createDefaultFeatures(Duration windowDuration) {
    return GaitFeatures(
      stepFrequency: 0.0,
      stepRegularity: 0.0,
      accelerationVariance: 0.0,
      gyroscopeVariance: 0.0,
      stepIntensity: 0.0,
      walkingPattern: 1, // Irregular
      featuresTimestamp: DateTime.now(),
      windowDuration: windowDuration,
    );
  }

  /// Create default features with specified window duration
  GaitFeatures _createDefaultFeatures(Duration windowDuration) {
    return GaitFeatures(
      stepFrequency: 0.0,
      stepRegularity: 0.0,
      accelerationVariance: 0.0,
      gyroscopeVariance: 0.0,
      stepIntensity: 0.0,
      walkingPattern: 1, // Irregular/unknown
      featuresTimestamp: DateTime.now(),
      windowDuration: windowDuration,
    );
  }
}

extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}