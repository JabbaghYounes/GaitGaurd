import 'package:flutter_test/flutter_test.dart';
import '../../../lib/data/models/authentication_decision.dart';
import '../../../lib/core/services/authentication_service.dart';
import '../../../lib/core/services/confidence_threshold_manager.dart';
import '../../../lib/data/models/gait_features.dart';
import '../../../lib/data/models/calibration_baseline.dart';
import '../../../lib/core/services/gait_feature_extractor.dart';
import '../../../lib/core/services/mock_gait_recognizer.dart';

void main() {
  group('AuthenticationDecision Model Tests', () {
    test('should create success decision correctly', () {
      const decision = AuthenticationDecision.success(
        userId: 1,
        confidence: 0.85,
        decision: AuthenticationDecisionType.success,
        baselineUsed: 'baseline-123',
        decisionTimestamp: DateTime.parse('2023-01-01T12:00:00.000Z'),
        comparison: {
          'similarityScore': 0.92,
          'stepFrequency': {'baseline': 2.0, 'current': 2.1},
          'walkingPattern': {'match': true},
        },
      );

      expect(decision.userId, equals(1));
      expect(decision.isAuthenticated, isTrue);
      expect(decision.confidence, closeTo(0.85));
      expect(decision.decision, equals(AuthenticationDecisionType.success));
      expect(decision.baselineUsed, equals('baseline-123'));
      expect(decision.decisionTimestamp.isAt(DateTime.parse('2023-01-01T12:00:00.000Z')), isTrue);
    });

    test('should create failure decision correctly', () {
      const decision = AuthenticationDecision.failure(
        userId: 1,
        confidence: 0.0,
        decision: AuthenticationDecisionType.confidenceTooLow,
        baselineUsed: 'baseline-123',
        decisionTimestamp: DateTime.parse('2023-01-01T12:00:00.000Z'),
        reason: 'Confidence too low: 0.3 < threshold 0.7',
        comparison: {
          'similarityScore': 0.4,
          'stepFrequency': {'baseline': 2.0, 'current': 3.5},
        'walkingPattern': {'match': true},
        },
      );

      expect(decision.userId, equals(1));
      expect(decision.isAuthenticated, isFalse);
      expect(decision.confidence, equals(0.0));
      expect(decision.decision, equals(AuthenticationDecisionType.confidenceTooLow));
      expect(decision.baselineUsed, equals('baseline-123'));
    });

    test('should calculate confidence category correctly', () {
      expect(AuthenticationDecision.success(
        confidence: 0.95,
        decision: AuthenticationDecisionType.success,
      ).decisionCategory, equals('High Confidence'));
      
      expect(AuthenticationDecision.success(
        confidence: 0.75,
        decision: AuthenticationDecisionType.success,
      ).decisionCategory, equals('Medium Confidence'));
      
      expect(AuthenticationDecision.success(
        confidence: 0.6,
        decision: AuthenticationDecisionType.success,
      ).decisionCategory, equals('Low Confidence'));
      
      expect(AuthenticationDecision.success(
        confidence: 0.4,
        decision: AuthenticationDecisionType.success,
      ).decisionCategory, equals('Very Low Confidence'));
    });
  });

  group('AuthenticationConfig Tests', () {
    test('should have correct default values', () {
      const config = AuthenticationConfig.production;
      
      expect(config.confidenceThreshold, equals(0.7));
      expect(config.minCalibrationAge.inDays, equals(7));
      expect(config.maxCalibrationAge.inDays, equals(90));
      expect(config.minSamplesForComparison, equals(500));
      expect(config.aveTimeWindow.inSeconds, equals(3));
      expect(config.peakSimilarityThreshold, closeTo(0.8));
      expect(config.frequencyTolerance, equals(0.3));
      expect(config.varianceTolerance, equals(2.0));
    });
  });

    test('should have lenient configuration', () {
      const config = AuthenticationConfig.lenient;
      
      expect(config.confidenceThreshold, equals(0.5));
      expect(config.minCalibrationAge.inDays, equals(3));
      expect(config.maxCalibrationAge.inDays, equals(180));
      expect(config.minSamplesForComparison, equals(200));
      expect(config.aveTimeWindow.inSeconds, equals(2));
      expect(config.peakSimilarityThreshold, closeTo(0.6));
      expect(config.frequencyTolerance, equals(0.5));
      expect(config.varianceTolerance, equals(3.0));
    });

    test('should have strict configuration', () {
      const config = AuthenticationConfig.strict;
      
      expect(config.confidenceThreshold, equals(0.85));
      expect(config.minCalibrationAge.inDays, equals(1));
      expect(config.maxCalibrationAge.inDays, equals(30));
      expect(config.minSamplesForComparison, equals(1000));
      expect(config.aveTimeWindow.inSeconds, equals(5));
      expect(config.peakSimilarityThreshold, closeTo(0.9));
      expect(config.frequencyTolerance, equals(0.2));
      expect(config.varianceTolerance, equals(1.5));
    });

    test('should have max configuration', () {
      const config = AuthenticationConfig.max;
      
      expect(config.confidenceThreshold, equals(0.9));
      expect(config.minCalibrationAge.inDays, equals(0));
      expect(config.maxCalibrationAge.inDays, equals(1));
      expect(config.minSamplesForComparison, equals(1000));
      expect(config.aveTimeWindow.inSeconds, equals(10));
      expect(config.peakSimilarityThreshold, closeTo(1.0));
      expect(config.frequencyTolerance, equals(0.1));
      expect(config.varianceTolerance, equals(1.0));
    });
  });

  group('CalibrationBaseline Tests', () {
    test('should create baseline correctly', () {
      const baseline = CalibrationBaseline(
        id: 1,
        userId: 1,
        features: GaitFeatures(
          stepFrequency: 2.0,
          stepRegularity: 0.8,
          accelerationVariance: 1.2,
          gyroscopeVariance: 0.8,
          stepIntensity: 0.6,
          walkingPattern: 0,
          featuresTimestamp: DateTime.parse('2023-01-01T12:00:00.000Z'),
          qualityScore: 0.75,
          createdAt: DateTime.now(),
        isActive: true,
      );

      expect(baseline.userId, equals(1));
      expect(baseline.isActive, isTrue);
      expect(baseline.qualityScore, equals(0.75));
    });

    test('should calculate similarity correctly', () {
      final baseline1 = CalibrationBaseline(
        id: 1,
        userId: 1,
        features: GaitFeatures(
          stepFrequency: 2.0,
          stepRegularity: 0.8,
          accelerationVariance: 1.2,
          gyroscopeVariance: 0.8,
          stepIntensity: 0.6,
          walkingPattern: 0,
          featuresTimestamp: DateTime.now(),
          qualityScore: 0.75,
          createdAt: DateTime.now(),
          isActive: true,
      );

      final baseline2 = CalibrationBaseline(
        id: 2,
        userId: 1,
        features: GaitFeatures(
          stepFrequency: 2.2, // Slightly different
          stepRegularity: 0.7,
          accelerationVariance: 1.1,
          gyroscopeVariance: 0.7,
          stepIntensity: 0.5,
          walkingPattern: 0,
          featuresTimestamp: DateTime.now(),
          qualityScore: 0.8,
          createdAt: DateTime.now(),
          isActive: true,
      );

      // Calculate similarity from baseline1 to baseline2
      final similarity1 = baseline1.calculateSimilarity(baseline2);
      final similarity2 = baseline2.calculateSimilarity(baseline1);

      expect(similarity1, closeTo(1.0));
      expect(similarity2, closeTo(1.0));
    });

    test('should handle edge cases in comparison', () {
      final baseline = CalibrationBaseline(
        id: 1,
        userId: 1,
        features: GaitFeatures(
          stepFrequency: 0.0, // No frequency
          stepRegularity: 0.0,
          accelerationVariance: 0.0,
          gyroscopeVariance: 0.0,
          stepIntensity: 0.0,
          walkingPattern: 0,
          featuresTimestamp: DateTime.now(),
          qualityScore: 0.0,
          createdAt: DateTime.now(),
          isActive: true,
      );

      final invalidFeatures = GaitFeatures(
        stepFrequency: 0.0,
        stepRegularity: 0.0,
        accelerationVariance: 50.0, // Invalid variance
        gyroscopeVariance: 50.0, // Invalid variance
        stepIntensity: 0.0,
        walkingPattern: 0,
        featuresTimestamp: DateTime.now(),
        qualityScore: 0.0,
        createdAt: DateTime.now(),
        isActive: true,
      );

      final similarity = baseline.calculateSimilarity(invalidFeatures);
      
      expect(similarity, equals(0.0)); // Should return 0 for invalid features
    });

    test('should check age constraints correctly', () async {
      const config = AuthenticationConfig.production;
      const manager = ConfidenceThresholdManager(config);
      
      final recentBaseline = CalibrationBaseline(
        id: 1,
        userId: 1,
        features: GaitFeatures(
          stepFrequency: 2.0,
          qualityScore: 0.75,
          createdAt: DateTime.now().subtract(const Duration(days: 100)), // Too old
          isActive: true,
      );

      final isTooOld = recentBaseline.isTooOld(config.maxCalibrationAge);

      expect(isTooOld, isTrue);
    });
  });

  group('BaselineComparison Tests', () {
    test('should generate comparison report', () {
      const baseline = CalibrationBaseline(
        id: 1,
        userId: 1,
        features: GaitFeatures(
          stepFrequency: 2.0,
          stepRegularity: 0.8,
          accelerationVariance: 1.2,
          gyroscopeVariance: 0.8,
          stepIntensity: 0.6,
          walkingPattern: 0,
          featuresTimestamp: DateTime.now(),
          qualityScore: 0.75,
        createdAt: DateTime.now(),
          isActive: true,
      );

      final newFeatures = GaitFeatures(
        stepFrequency: 2.1,
        stepRegularity: 0.6,
        accelerationVariance: 1.5,
        gyroscopeVariance: 0.9,
        stepIntensity: 0.4,
        walkingPattern: 0,
        featuresTimestamp: DateTime.now(),
        qualityScore: 0.8,
        windowDuration: const Duration(seconds: 3),
      );

      final comparison = BaselineComparison.create(
        baselineId: baseline.id,
        baselineFeatures: baseline.features,
        newFeatures: newFeatures,
        similarityScore: baseline.calculateSimilarity(newFeatures),
        comparison: {
          'stepFrequency': {
            'baseline': 2.0,
            'current': 2.1,
            'difference': 0.1,
          },
          'stepRegularity': {
            'baseline': 0.8,
            'current': 0.6,
            'difference': 0.2,
          },
          'accelerationVariance': {
            'baseline': 1.2,
            'current': 1.5,
            'difference': 0.3,
          },
          'gyroscopeVariance': {
            'baseline': 0.8,
            'current': 0.9,
            'difference': 0.1,
          },
          'walkingPattern': {
            'baseline': 0,
            'current': 0,
            'match': true,
          },
        },
      },
    );

      final report = comparison.getComparisonReport();

      expect(report.contains('Similarity Score: 95%'), isTrue);
      expect(report.contains('✓ Step frequency matches well'), isTrue);
      expect(report.contains('✓ Step regularity matches well'), isTrue);
      expect(report.contains('⚠ Acceleration variance differs significantly'), isTrue);
      expect(report.contains('✓ Gyroscope variance is acceptable'), isTrue);
    });
  });

  group('ConfidenceThresholdManager Tests', () {
    test('should calculate threshold recommendations', () {
      const config = AuthenticationConfig.production;
      const manager = ConfidenceThresholdManager(config);

      // Test increasing threshold
      final recentDecisions = List.generate(10, (i) => AuthenticationDecision.failure(
        userId: 1,
        confidence: 0.6,
        decision: AuthenticationDecisionType.confidenceTooLow,
        reason: 'Test low confidence',
      ));

      final increaseRecommendation = manager.getRecommendations(
        recentDecisions,
        config.currentThreshold,
      );

      expect(increaseRecommendation['action'], equals('consider_increasing'));
    });

    test('should calculate decreasing threshold recommendations', () {
      const config = AuthenticationConfig.production;
      const manager = ConfidenceThresholdManager(config);

      // Test decreasing threshold
      final recentDecisions = List.generate(10, (i) => AuthenticationDecision.failure(
        userId: 1,
        confidence: 0.4,
        decision: AuthenticationDecisionType.confidenceTooLow,
        reason: 'Test very low confidence',
      ));

      final decreaseRecommendation = manager.getRecommendations(
        recentDecisions,
        config.currentThreshold,
      );

      expect(decreaseRecommendation['action'], equals('consider_decreasing'));
    });

    test('should maintain threshold for good success rate', () {
      const config = AuthenticationConfig.production;
      const manager = ConfidenceThresholdManager(config);

      // Test balanced success rate
      final recentDecisions = List.generate(10, (i) => AuthenticationDecision.success(
        userId: 1,
        confidence: 0.75 + (i * 0.05), // Varying success rates
        decision: AuthenticationDecisionType.success,
        decisionTimestamp: DateTime.now().subtract(Duration(minutes: i * 5)),
      ));

      final maintainRecommendation = manager.getRecommendations(
        recentDecisions,
        config.currentThreshold,
      );

      expect(maintainRecommendation['action'], equals('maintain'));
    });
  });

  group('AuthenticationService Tests', () {
    late AuthenticationService service;

    setUp() {
      final featureExtractor = GaitFeatureExtractor();
      final mlService = MLPipelineService(
        featureExtractor,
        MLModelRepositoryImpl(DatabaseService.instance),
        MockSensorService(),
        RecognizerType.heuristic,
      );
      final thresholdManager = ConfidenceThresholdManager(AuthenticationConfig.production);
      
      service = AuthenticationService(
        featureExtractor: featureExtractor,
        mlPipelineService: mlService,
        thresholdManager: thresholdManager,
        config: AuthenticationConfig.production,
      );
    }

    test('should authenticate successfully with good match', () async {
      final features = GaitFeatures(
        stepFrequency: 2.0,
        stepRegularity: 0.8,
        accelerationVariance: 1.2,
        gyroscopeVariance: 0.8,
        stepIntensity: 0.6,
        walkingPattern: 0,
        featuresTimestamp: DateTime.now(),
        windowDuration: const Duration(seconds: 3),
      );

      final decision = await service.makeDecision(
        userId: 1,
        features: features,
      );

      expect(decision.isAuthenticated, isTrue);
      expect(decision.confidence, greaterThan(0.7));
      expect(decision.decision, equals(AuthenticationDecisionType.success));
    });

    test('should fail with low confidence', () async {
      final features = GaitFeatures(
        stepFrequency: 2.0,
        stepRegularity: 0.3, // Poor regularity
        accelerationVariance: 3.5, // High variance
        gyroscopeVariance: 2.8, // High variance
        stepIntensity: 0.8,
        walkingPattern: 1, // Irregular
        featuresTimestamp: DateTime.now(),
        windowDuration: const Duration(seconds: 3),
      );

      final decision = await service.makeDecision(
        userId: 1,
        features: features,
      );

      expect(decision.isAuthenticated, isFalse);
      expect(decision.confidence, lessThan(0.7));
      expect(decision.decision, equals(AuthenticationDecisionType.confidenceTooLow));
    });

    test('should detect insufficient data', () async {
      final invalidFeatures = GaitFeatures(
        stepFrequency: 0.0, // No steps detected
        stepRegularity: 0.0,
        accelerationVariance: 0.1,
        gyroscopeVariance: 0.1,
        stepIntensity: 0.0,
        walkingPattern: 1,
        featuresTimestamp: DateTime.now(),
        windowDuration: const Duration(seconds: 1), // Too short window
      );

      final decision = await service.makeDecision(
        userId: 1,
        features: invalidFeatures,
      );

      expect(decision.isAuthenticated, isFalse);
      expect(decision.decision, equals(AuthenticationDecisionType.insufficientData));
    });

    test('should handle no baseline', () async {
      final features = GaitFeatures(
        stepFrequency: 2.0,
        stepRegularity: 0.8,
        accelerationVariance: 1.2,
        gyroscopeVariance: 0.8,
        stepIntensity: 0.6,
        featuresTimestamp: DateTime.now(),
        windowDuration: const Duration(seconds: 3),
      );

      final decision = await service.makeDecision(
        userId: 1,
        features: features,
      );

      expect(decision.isAuthenticated, isFalse);
      expect(decision.decision, equals(AuthenticationDecisionType.baselineNotFound));
    });

    test('should handle old baseline', () async {
      const oldBaseline = CalibrationBaseline(
        id: 1,
        userId: 1,
        features: GaitFeatures(
          stepFrequency: 2.0,
          qualityScore: 0.7,
          createdAt: DateTime.now().subtract(const Duration(days: 100)), // Too old
          isActive: true,
      );

      final features = GaitFeatures(
        stepFrequency: 2.0,
        stepRegularity: 0.8,
        accelerationVariance: 1.2,
        gyroscopeVariance: 0.8,
        stepIntensity: 0.6,
        walkingPattern: 0,
        featuresTimestamp: DateTime.now(),
        windowDuration: const Duration(seconds: 3),
      );

      final decision = await service.makeDecision(
        userId: 1,
        features: features,
        baselineId: oldBaseline.id,
      );

      expect(decision.isAuthenticated, isFalse);
      expect(decision.decision, equals(AuthenticationDecisionType.calibrationTooOld));
    });
  });

  group('Integration Tests', () {
    test('should handle complete authentication flow', () async {
      final service = AuthenticationService(
        GaitFeatureExtractor(),
        MLPipelineService(
          GaitFeatureExtractor(),
          MLModelRepositoryImpl(DatabaseService.instance),
          MockSensorService(),
          RecognizerType.heuristic,
        ),
        ConfidenceThresholdManager(AuthenticationConfig.production),
        AuthenticationConfig.production,
      );

      // Simulate successful calibration
      await service.resetAndRetrain(1, [
        GaitFeatures(stepFrequency: 2.0, stepRegularity: 0.8),
      ]);

      // Perform successful recognition
      final recognitionFeatures = GaitFeatures(
        stepFrequency: 2.1,
        stepRegularity: 0.85,
        accelerationVariance: 1.1,
        gyroscopeVariance: 0.9,
        stepIntensity: 0.5,
        walkingPattern: 0,
        featuresTimestamp: DateTime.now(),
        windowDuration: const Duration(seconds: 3),
      );

      final decision = await service.makeDecision(
        userId: 1,
        features: recognitionFeatures,
      );

      expect(decision.isAuthenticated, isTrue);
      expect(decision.confidence, greaterThan(0.8)); // Should be high confidence
    });
  });
}

// Mock services for testing
class MockGaitFeatureExtractor extends GaitFeatureExtractor {}
class MockMLPipelineService extends MLPipelineService {
  MockMLPipelineService() : super(
    MockGaitFeatureExtractor(),
    MLModelRepositoryImpl(DatabaseService.instance),
    MockSensorService(),
    RecognizerType.heuristic,
  );

  @override
  Future<Map<String, dynamic>> getPipelineStatus(int userId) async {
    return {
      'recognizer': 'mock',
      'models': [
        {
          'id': 'mock-1',
          'type': 'heuristic',
          'trained': true,
          'userId': userId,
        },
      ],
      'recognitions': [
        {
          'total': 0,
          'successful': 0,
          'averageConfidence': 0.0,
          'successRate': 0.0,
        'lastRecognition': null,
        },
      ],
    };
  }
}

class MockConfidenceThresholdManager {
  MockConfidenceManager(AuthenticationConfig config) : super(config);

  @override
  double get currentThreshold => config.confidenceThreshold;

  @override
  Future<void> resetThreshold(int userId) async {}

  @override
  Map<String, dynamic> getRecommendations(
    List<AuthenticationDecision> recentDecisions,
    double currentThreshold,
  ) {
    return {
      'action': 'test_mock',
      'recommendation': 'Test recommendation',
    };
  }
}

extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}