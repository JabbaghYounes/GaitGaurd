import 'dart:async';
import 'gait_recognizer.dart';
import 'gait_feature_extractor.dart';
import 'sensor_service.dart';
import '../../data/models/gait_features.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/repositories/ml_model_repository.dart';

/// ML Pipeline service for gait recognition
class MLPipelineService {
  const MLPipelineService({
    required this.featureExtractor,
    required this.modelRepository,
    required this.sensorService,
    this.recognizerType = RecognizerType.heuristic,
  });

  final GaitFeatureExtractor featureExtractor;
  final MLModelRepository modelRepository;
  final SensorService sensorService;
  final RecognizerType recognizerType;

  GaitRecognizer? _recognizer;
  StreamSubscription<SensorReading>? _sensorSubscription;

  /// Initialize ML pipeline
  Future<void> initialize(int userId) async {
    try {
      // Get active model for user
      final modelInfo = await modelRepository.getActiveModel(userId);
      
      // Create recognizer based on type and availability
      _recognizer = _createRecognizer(modelInfo);
      
      // Initialize recognizer with model info if available
      if (modelInfo != null) {
        // Train or load model based on recognizer type
        if (!_recognizer!.isTrained(userId)) {
          final trainingData = await modelRepository.getTrainingData(
            modelInfo['id'] as int,
          );
          if (trainingData.isNotEmpty) {
            await _recognizer!.train(trainingData, userId);
          }
        }
      }
    } catch (e) {
      throw MLPipelineException('Failed to initialize ML pipeline', e);
    }
  }

  /// Start real-time gait recognition
  Future<void> startRecognition(int userId) async {
    if (_recognizer == null) {
      throw MLPipelineException('Recognizer not initialized', null);
    }

    try {
      // Start sensor collection
      await sensorService.startCollection();

      // Subscribe to sensor readings
      _sensorSubscription = sensorService.sensorReadingStream.listen(
        (reading) => _processSensorReading(reading, userId),
        onError: _handleSensorError,
      );
    } catch (e) {
      throw MLPipelineException('Failed to start recognition', e);
    }
  }

  /// Stop real-time gait recognition
  Future<void> stopRecognition() async {
    try {
      await _sensorSubscription?.cancel();
      _sensorSubscription = null;
      await sensorService.stopCollection();
    } catch (e) {
      throw MLPipelineException('Failed to stop recognition', e);
    }
  }

  /// Perform one-time gait recognition from sensor readings
  Future<GaitRecognitionResult> recognizeFromReadings(
    List<SensorReading> readings,
    int userId,
  ) async {
    if (_recognizer == null) {
      throw MLPipelineException('Recognizer not initialized', null);
    }

    try {
      // Extract features from readings
      final features = featureExtractor.extractFeatures(readings);
      
      // Perform recognition
      final result = await _recognizer!.recognize(features, userId);
      
      // Save recognition result
      await modelRepository.saveRecognitionResult(
        userId: userId,
        features: features,
        isMatch: result.isMatch,
        confidence: result.confidence,
        patternType: result.patternType,
        modelId: await _getActiveModelId(userId),
        metadata: result.metadata,
      );

      return result;
    } catch (e) {
      throw MLPipelineException('Failed to perform recognition', e);
    }
  }

  /// Train new model from calibration data
  Future<int> trainModel({
    required int userId,
    required List<GaitFeatures> trainingData,
    String modelType = 'heuristic',
    String modelVersion = '1.0.0',
  }) async {
    try {
      // Create recognizer for training
      final recognizer = _createRecognizerForType(modelType, modelVersion);
      
      // Train the model
      await recognizer.train(trainingData, userId);
      
      // Save model metadata
      final modelId = await modelRepository.saveModel(
        userId: userId,
        modelType: modelType,
        modelVersion: modelVersion,
        modelPath: _getModelPath(modelType),
        isActive: true,
        accuracy: _estimateModelAccuracy(trainingData),
        performance: _estimateModelPerformance(trainingData),
        metadata: {
          'trainingSamples': trainingData.length,
          'trainedAt': DateTime.now().toIso8601String(),
          'modelType': modelType,
        },
      );

      // Save training data for future reference
      for (final features in trainingData) {
        await modelRepository.saveTrainingData(
          userId: userId,
          modelId: modelId,
          features: features,
        );
      }

      return modelId;
    } catch (e) {
      throw MLPipelineException('Failed to train model', e);
    }
  }

  /// Get pipeline status and statistics
  Future<Map<String, dynamic>> getPipelineStatus(int userId) async {
    try {
      final modelStats = await modelRepository.getModelStatistics(userId);
      final recognizerInfo = _recognizer != null
          ? await _recognizer!.getModelInfo(userId)
          : null;

      return {
        'recognizer': {
          'type': recognizerType.name,
          'initialized': _recognizer != null,
          'info': recognizerInfo,
        },
        'models': modelStats,
        'status': _recognizer != null ? 'ready' : 'not_initialized',
      };
    } catch (e) {
      throw MLPipelineException('Failed to get pipeline status', e);
    }
  }

  /// Switch recognizer type
  Future<void> switchRecognizer(RecognizerType type, int userId) async {
    if (recognizerType == type) return; // Same type

    try {
      // Stop current recognition
      await stopRecognition();

      // Create new recognizer
      final modelInfo = await modelRepository.getActiveModel(userId);
      _recognizer = _createRecognizer(modelInfo);

      // Update recognizer type
      recognizerType = type;

      // Restart recognition if needed
      if (_sensorSubscription != null) {
        await startRecognition(userId);
      }
    } catch (e) {
      throw MLPipelineException('Failed to switch recognizer', e);
    }
  }

  // Private helper methods

  void _processSensorReading(SensorReading reading, int userId) {
    if (_recognizer == null) return;

    // Use sliding window for real-time processing
    // Note: In a real implementation, this would use a proper sliding window buffer
    // For now, we'll process individual readings with a small window
    
    // Collect recent readings (this would be a proper sliding window in production)
    final recentReadings = <SensorReading>[reading]; // Simplified

    if (recentReadings.length >= 10) {
      // Extract features and perform recognition
      _performRealtimeRecognition(recentReadings, userId);
    }
  }

  Future<void> _performRealtimeRecognition(
    List<SensorReading> readings,
    int userId,
  ) async {
    try {
      final features = featureExtractor.extractRealTimeFeatures(readings);
      final result = await _recognizer!.recognize(features, userId);

      // Save recognition result
      await modelRepository.saveRecognitionResult(
        userId: userId,
        features: features,
        isMatch: result.isMatch,
        confidence: result.confidence,
        patternType: result.patternType,
        metadata: {
          'realtime': true,
          'windowSize': readings.length,
        },
      );

      // Could emit recognition result via stream or callback
      // For now, we'll just save it
    } catch (e) {
      print('Real-time recognition error: $e');
    }
  }

  void _handleSensorError(dynamic error) {
    print('Sensor error during recognition: $error');
    // Could emit error state via stream
  }

  GaitRecognizer _createRecognizer(Map<String, dynamic>? modelInfo) {
    switch (recognizerType) {
      case RecognizerType.heuristic:
        return const HeuristicGaitRecognizer();
      
      case RecognizerType.ml:
        if (modelInfo != null) {
          return MLGaitRecognizer(
            modelPath: modelInfo['modelPath'] as String? ?? '',
            modelVersion: modelInfo['modelVersion'] as String? ?? '1.0.0',
          );
        }
        return const MLGaitRecognizer(
          modelPath: '',
          modelVersion: '1.0.0',
        );
    }
  }

  GaitRecognizer _createRecognizerForType(String modelType, String modelVersion) {
    if (modelType.toLowerCase() == 'ml') {
      return MLGaitRecognizer(
        modelPath: _getModelPath(modelType),
        modelVersion: modelVersion,
      );
    }
    return const HeuristicGaitRecognizer();
  }

  String _getModelPath(String modelType) {
    return '/models/gait_${modelType.toLowerCase()}.tflite';
  }

  Future<int?> _getActiveModelId(int userId) async {
    final modelInfo = await modelRepository.getActiveModel(userId);
    return modelInfo?['id'] as int?;
  }

  double _estimateModelAccuracy(List<GaitFeatures> trainingData) {
    if (trainingData.isEmpty) return 0.0;
    
    // Simple accuracy estimation based on data quality
    final avgQuality = trainingData
        .map((f) => f.stepRegularity)
        .reduce((a, b) => a + b) / trainingData.length;
    
    return (avgQuality * 0.8).clamp(0.0, 1.0);
  }

  double _estimateModelPerformance(List<GaitFeatures> trainingData) {
    if (trainingData.isEmpty) return 0.0;
    
    // Performance based on regularity and consistency
    final avgRegularity = trainingData
        .map((f) => f.stepRegularity)
        .reduce((a, b) => a + b) / trainingData.length;
    final avgVariance = trainingData
        .map((f) => f.accelerationVariance + f.gyroscopeVariance)
        .reduce((a, b) => a + b) / (trainingData.length * 2);
    
    final performance = (avgRegularity * 0.6) + (1.0 - avgVariance) * 0.4;
    return performance.clamp(0.0, 1.0);
  }
}

/// Types of recognizers
enum RecognizerType {
  heuristic,
  ml,
}

/// ML Pipeline exception
class MLPipelineException implements Exception {
  const MLPipelineException(this.message, [this.cause]);

  final String message;
  final dynamic cause;

  @override
  String toString() => 'MLPipelineException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}