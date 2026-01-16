import 'dart:async';
import 'dart:math';
import 'gait_recognizer.dart';
import '../../data/models/gait_features.dart';
import '../../data/models/sensor_reading.dart';

/// Mock gait recognizer for testing and development.
/// 
/// Provides predictable results for testing ML pipeline functionality
/// while simulating realistic recognition behavior.
class MockGaitRecognizer implements GaitRecognizer {
  const MockGaitRecognizer({
    this.recognitionDelay = const Duration(milliseconds: 100),
    this.baseConfidence = 0.85,
    this.confidenceVariation = 0.15,
    this.simulationMode = MockSimulationMode.normal,
  });

  final Duration recognitionDelay;
  final double baseConfidence;
  final double confidenceVariation;
  final MockSimulationMode simulationMode;

  @override
  Future<GaitRecognitionResult> recognize(GaitFeatures features, int userId) async {
    // Simulate recognition processing time
    await Future.delayed(recognitionDelay);

    // Generate deterministic but realistic results
    final confidence = _generateConfidence(features);
    final isMatch = _determineMatch(features, confidence);
    final patternType = _determinePattern(features, isMatch);
    
    return GaitRecognitionResult.match(
      userId: userId,
      confidence: isMatch ? confidence : 0.0,
      patternType: patternType,
      features: features,
      metadata: {
        'simulator': 'mock',
        'recognitionTime': DateTime.now().toIso8601String(),
        'baseConfidence': baseConfidence,
        'confidenceVariation': confidenceVariation,
        'simulationMode': simulationMode.name,
      },
    );
  }

  @override
  Future<void> train(List<GaitFeatures> trainingData, int userId) async {
    // Simulate training process
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock training would "learn" from the data
    final avgQuality = trainingData.isNotEmpty
        ? trainingData.map((f) => f.stepRegularity).reduce((a, b) => a + b) / trainingData.length
        : 0.0;
    
    print('MockGaitRecognizer: Trained with ${trainingData.length} samples');
    print('MockGaitRecognizer: Average quality score: ${avgQuality.toStringAsFixed(3)}');
  }

  @override
  Future<bool> isTrained(int userId) async {
    // Mock recognizer is always "trained" after init
    await Future.delayed(const Duration(milliseconds: 50));
    return true;
  }

  @override
  Future<Map<String, dynamic>> getModelInfo(int userId) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    return {
      'type': 'mock',
      'version': '1.0.0-mock',
      'trained': true,
      'userId': userId,
      'description': 'Mock recognizer for testing and development',
      'features': ['stepFrequency', 'stepRegularity', 'accelerationVariance', 
                  'gyroscopeVariance', 'stepIntensity', 'walkingPattern'],
      'accuracy': 'mock-85%',
      'performance': 'high',
      'simulationMode': simulationMode.name,
      'recognitionDelay': recognitionDelay.inMilliseconds,
      'baseConfidence': baseConfidence,
      'confidenceVariation': confidenceVariation,
    };
  }

  /// Generate confidence based on features and simulation mode
  double _generateConfidence(GaitFeatures features) {
    final baseRandom = Random(DateTime.now().millisecondsSinceEpoch);
    
    switch (simulationMode) {
      case MockSimulationMode.alwaysMatch:
        return baseConfidence + (baseRandom.nextDouble() * confidenceVariation);
        
      case MockSimulationMode.alwaysReject:
        return (baseRandom.nextDouble() * 0.3); // Always low confidence
        
      case MockSimulationMode.random:
        return baseRandom.nextDouble();
        
      case MockSimulationMode.qualityBased:
        // Higher confidence for better features
        final qualityScore = (features.stepRegularity * 0.3) +
                          (features.stepIntensity * 0.2) +
                          ((1.0 - features.accelerationVariance) * 0.3) +
                          ((1.0 - features.gyroscopeVariance) * 0.2);
        
        return (baseConfidence * 0.7) + (qualityScore * 0.3);
        
      case MockSimulationMode.normal:
      default:
        // Normal behavior based on multiple factors
        final factors = [
          features.stepRegularity,
          features.stepFrequency,
          features.stepIntensity,
        ];
        
        final avgFactor = factors.reduce((a, b) => a + b) / factors.length;
        final confidence = (avgFactor * 0.5) + (baseRandom.nextDouble() * 0.5);
        
        return confidence.clamp(0.0, 1.0);
    }
  }

  /// Determine if recognition should match
  bool _determineMatch(GaitFeatures features, double confidence) {
    switch (simulationMode) {
      case MockSimulationMode.alwaysMatch:
        return true;
        
      case MockSimulationMode.alwaysReject:
        return false;
        
      case MockSimulationMode.random:
        return Random().nextDouble() > 0.3;
        
      case MockSimulationMode.qualityBased:
        return confidence > (baseConfidence - 0.2);
        
      case MockSimulationMode.normal:
      default:
        // Normal logic: match if features are reasonable
        final regularityScore = features.stepRegularity;
        final intensityScore = features.stepIntensity.clamp(0.0, 1.0);
        final patternScore = features.walkingPattern == 0 ? 1.0 : 0.5; // Normal is better
        
        final combinedScore = (regularityScore * 0.4) + (intensityScore * 0.3) + (patternScore * 0.3);
        return combinedScore > 0.6;
    }
  }

  /// Determine pattern type based on features
  GaitPatternType _determinePattern(GaitFeatures features, bool isMatch) {
    if (!isMatch) {
      return features.walkingPattern <= 2 
          ? features.walkingPattern 
          : GaitPatternType.unknown;
    }

    // If it matches, use the detected walking pattern
    switch (features.walkingPattern) {
      case 0: return GaitPatternType.normal;
      case 1: return GaitPatternType.irregular;
      case 2: return GaitPatternType.limping;
      default: return GaitPatternType.normal;
    }
  }

  /// Set simulation mode for testing
  void setSimulationMode(MockSimulationMode mode) {
    // This would need to be stored in a real implementation
    // For now, we'll log it
    print('MockGaitRecognizer: Simulation mode changed to ${mode.name}');
  }

  /// Reset mock state
  void reset() {
    // Reset any internal state for testing
    print('MockGaitRecognizer: Mock state reset');
  }

  /// Generate deterministic results for testing
  GaitRecognitionResult generateDeterministicResult({
    required int userId,
    required GaitFeatures features,
    required bool shouldMatch,
    double? confidence,
    GaitPatternType? patternType,
  }) {
    final finalConfidence = confidence ?? baseConfidence;
    final finalPatternType = patternType ?? GaitPatternType.normal;
    
    return GaitRecognitionResult.match(
      userId: userId,
      confidence: shouldMatch ? finalConfidence : 0.0,
      patternType: finalPatternType,
      features: features,
      metadata: {
        'simulator': 'mock',
        'deterministic': true,
        'shouldMatch': shouldMatch,
        'generatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Generate time-based results for testing
  GaitRecognitionResult generateTimeBasedResult({
    required int userId,
    required GaitFeatures features,
    required DateTime timestamp,
  }) {
    // Generate results based on time of day for reproducible testing
    final hour = timestamp.hour;
    final isMatch = hour >= 8 && hour <= 18; // Business hours
    final confidence = isMatch 
        ? baseConfidence + (hour >= 12 && hour <= 16 ? 0.1 : -0.1)
        : 0.0;
    
    return GaitRecognitionResult.match(
      userId: userId,
      confidence: confidence,
      patternType: isMatch ? GaitPatternType.normal : GaitPatternType.irregular,
      features: features,
      metadata: {
        'simulator': 'mock',
        'timeBased': true,
        'hour': hour,
        'isBusinessHours': isMatch,
        'generatedAt': DateTime.now().toIso8601String(),
      },
    );
  }
}

/// Simulation modes for mock recognizer
enum MockSimulationMode {
  normal,
  alwaysMatch,
  alwaysReject,
  random,
  qualityBased,
}

/// Utility class for creating mock data for testing
class MockGaitDataFactory {
  /// Create mock gait features for testing
  static GaitFeatures createFeatures({
    double stepFrequency = 2.0,
    double stepRegularity = 0.8,
    double accelerationVariance = 1.2,
    double gyroscopeVariance = 0.8,
    double stepIntensity = 0.6,
    int walkingPattern = 0,
    DateTime? featuresTimestamp,
    Duration windowDuration = const Duration(seconds: 5),
  }) {
    return GaitFeatures(
      stepFrequency: stepFrequency,
      stepRegularity: stepRegularity,
      accelerationVariance: accelerationVariance,
      gyroscopeVariance: gyroscopeVariance,
      stepIntensity: stepIntensity,
      walkingPattern: walkingPattern,
      featuresTimestamp: featuresTimestamp ?? DateTime.now(),
      windowDuration: windowDuration,
    );
  }

  /// Create mock sensor readings
  static List<SensorReading> createSensorReadings({
    int count = 100,
    double frequency = 50.0,
    DateTime? startTime,
    bool simulateWalking = true,
  }) {
    final readings = <SensorReading>[];
    final start = startTime ?? DateTime.now();
    
    for (int i = 0; i < count; i++) {
      final timestamp = start.add(Duration(milliseconds: (i * 1000 / frequency).round()));
      
      if (simulateWalking) {
        final reading = _createWalkingReading(timestamp, i);
        readings.add(reading);
      } else {
        final reading = _createStationaryReading(timestamp, i);
        readings.add(reading);
      }
    }
    
    return readings;
  }

  /// Create readings that simulate walking
  static SensorReading _createWalkingReading(DateTime timestamp, int index) {
    final t = index * 0.1;
    
    return SensorReading(
      accelerometer: AccelerometerData(
        x: sin(t) * 1.5,
        y: cos(t) * 1.2,
        z: 9.8 + sin(t * 2) * 0.8,
        timestamp: timestamp,
      ),
      gyroscope: GyroscopeData(
        x: cos(t * 1.5) * 0.1,
        y: sin(t * 1.2) * 0.1,
        z: sin(t * 0.5) * 0.05,
        timestamp: timestamp,
      ),
    );
  }

  /// Create readings that simulate being stationary
  static SensorReading _createStationaryReading(DateTime timestamp, int index) {
    final noise = Random(index).nextDouble() * 0.1;
    
    return SensorReading(
      accelerometer: AccelerometerData(
        x: noise,
        y: noise,
        z: 9.8 + noise,
        timestamp: timestamp,
      ),
      gyroscope: GyroscopeData(
        x: noise,
        y: noise,
        z: noise,
        timestamp: timestamp,
      ),
    );
  }

  /// Create mock recognition result batch
  static List<GaitRecognitionResult> createRecognitionResults({
    int userId = 1,
    int count = 10,
    double matchRate = 0.7,
    DateTime? startDate,
  }) {
    final results = <GaitRecognitionResult>[];
    final start = startDate ?? DateTime.now();
    
    for (int i = 0; i < count; i++) {
      final timestamp = start.add(Duration(seconds: i * 10));
      final shouldMatch = Random().nextDouble() < matchRate;
      
      final result = shouldMatch
          ? GaitRecognitionResult.match(
              userId: userId,
              confidence: 0.7 + Random().nextDouble() * 0.3,
              patternType: GaitPatternType.normal,
              recognitionTimestamp: timestamp,
              metadata: {'batch_index': i},
            )
          : GaitRecognitionResult.noMatch(
              userId: userId,
              patternType: GaitPatternType.unknown,
              recognitionTimestamp: timestamp,
              metadata: {'batch_index': i},
            );
      
      results.add(result);
    }
    
    return results;
  }
}

extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}