import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/gait_features.dart';
import '../../data/models/sensor_reading.dart';
import '../../core/services/ml_pipeline_service.dart';
import '../../core/services/sensor_service.dart';

/// Gait recognition state classes
abstract class GaitRecognitionState {
  const GaitRecognitionState();
}

class GaitRecognitionInitial extends GaitRecognitionState {
  const GaitRecognitionInitial();
}

class GaitRecognitionLoading extends GaitRecognitionState {
  const GaitRecognitionLoading();
}

class GaitRecognitionReady extends GaitRecognitionState {
  const GaitRecognitionReady({
    required this.userId,
    required this.activeModel,
    required this.recognitionHistory,
    this.pipelineStatus = 'ready',
  });

  final int userId;
  final Map<String, dynamic>? activeModel;
  final List<Map<String, dynamic>> recognitionHistory;
  final String pipelineStatus;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaitRecognitionReady &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          activeModel == other.activeModel &&
          pipelineStatus == other.pipelineStatus;

  @override
  int get hashCode =>
      userId.hashCode ^
      activeModel.hashCode ^
      pipelineStatus.hashCode;
}

class GaitRecognitionInProgress extends GaitRecognitionState {
  const GaitRecognitionInProgress({
    required this.isRealTime,
    required this.windowSize,
    required this.features,
    required this.confidence,
    required this.patternType,
  });

  final bool isRealTime;
  final int windowSize;
  final GaitFeatures? features;
  final double? confidence;
  final GaitPatternType? patternType;

  /// Get real-time statistics
  Map<String, dynamic> get statistics {
    return {
      'isRealTime': isRealTime,
      'windowSize': windowSize,
      'currentConfidence': confidence ?? 0.0,
      'patternType': patternType?.name,
      'features': features?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaitRecognitionInProgress &&
          runtimeType == other.runtimeType &&
          isRealTime == other.isRealTime &&
          windowSize == other.windowSize &&
          confidence == other.confidence &&
          patternType == other.patternType;

  @override
  int get hashCode =>
      isRealTime.hashCode ^
      windowSize.hashCode ^
      confidence.hashCode ^
      patternType.hashCode;
}

class GaitRecognitionComplete extends GaitRecognitionState {
  const GaitRecognitionComplete({
    required this.result,
    required this.recognitionTime,
  });

  final GaitRecognitionResult result;
  final DateTime recognitionTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaitRecognitionComplete &&
          runtimeType == other.runtimeType &&
          result == other.result;

  @override
  int get hashCode => result.hashCode;
}

class GaitRecognitionError extends GaitRecognitionState {
  const GaitRecognitionError(this.message, [this.error, this.errorType]);

  final String message;
  final dynamic error;
  final GaitRecognitionErrorType errorType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaitRecognitionError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          errorType == other.errorType;

  @override
  int get hashCode => message.hashCode ^ errorType.hashCode;
}

/// Types of recognition errors
enum GaitRecognitionErrorType {
  sensorUnavailable,
  modelNotTrained,
  recognitionFailed,
  pipelineError,
  insufficientData,
}

/// Gait Recognition Cubit for managing gait recognition
class GaitRecognitionCubit extends Cubit<GaitRecognitionState> {
  GaitRecognitionCubit(this._pipelineService)
      : super(const GaitRecognitionInitial());

  final MLPipelineService _pipelineService;
  List<SensorReading> _sensorBuffer = [];
  Timer? _realtimeTimer;

  /// Initialize recognition system for user
  Future<void> initialize(int userId) async {
    emit(const GaitRecognitionLoading());

    try {
      // Initialize ML pipeline
      await _pipelineService.initialize(userId);

      // Get pipeline status
      final status = await _pipelineService.getPipelineStatus(userId);
      
      // Get recognition history
      final history = await _getRecognitionHistory(userId);

      emit(GaitRecognitionReady(
        userId: userId,
        activeModel: status['recognizer']?['info'],
        recognitionHistory: history,
        pipelineStatus: status['status'] as String,
      ));
    } catch (e) {
      emit(GaitRecognitionError(
        'Failed to initialize recognition',
        e,
        GaitRecognitionErrorType.pipelineError,
      ));
    }
  }

  /// Start real-time gait recognition
  Future<void> startRealtimeRecognition() async {
    final currentState = state;
    if (currentState is! GaitRecognitionReady) {
      emit(const GaitRecognitionError(
        'Recognition not ready for realtime mode',
        GaitRecognitionErrorType.pipelineError,
      ));
      return;
    }

    try {
      await _pipelineService.startRecognition(currentState.userId);
      
      _startRealtimeProcessing();
      
      emit(const GaitRecognitionInProgress(
        isRealTime: true,
        windowSize: 10,
        features: null,
        confidence: null,
        patternType: null,
      ));
    } catch (e) {
      emit(GaitRecognitionError(
        'Failed to start realtime recognition',
        e,
        GaitRecognitionErrorType.recognitionFailed,
      ));
    }
  }

  /// Stop real-time gait recognition
  Future<void> stopRealtimeRecognition() async {
    try {
      await _pipelineService.stopRecognition();
      _stopRealtimeProcessing();
      
      // Return to ready state
      final currentState = state;
      if (currentState is GaitRecognitionReady) {
        emit(currentState);
      }
    } catch (e) {
      emit(GaitRecognitionError(
        'Failed to stop realtime recognition',
        e,
        GaitRecognitionErrorType.pipelineError,
      ));
    }
  }

  /// Perform one-time recognition from sensor readings
  Future<void> recognizeFromReadings(List<SensorReading> readings) async {
    if (readings.isEmpty) {
      emit(const GaitRecognitionError(
        'No sensor readings provided',
        GaitRecognitionErrorType.insufficientData,
      ));
      return;
    }

    emit(const GaitRecognitionLoading());

    try {
      final currentState = state;
      final userId = currentState is GaitRecognitionReady 
          ? currentState.userId 
          : 1; // Fallback

      final result = await _pipelineService.recognizeFromReadings(readings, userId);
      
      // Clear sensor buffer after recognition
      _sensorBuffer.clear();
      
      emit(GaitRecognitionComplete(
        result: result,
        recognitionTime: DateTime.now(),
      ));
    } catch (e) {
      emit(GaitRecognitionError(
        'Failed to recognize from readings',
        e,
        GaitRecognitionErrorType.recognitionFailed,
      ));
    }
  }

  /// Add sensor reading to real-time buffer
  void addSensorReading(SensorReading reading) {
    _sensorBuffer.add(reading);
    
    // Keep buffer size manageable
    const maxBufferSize = 100;
    if (_sensorBuffer.length > maxBufferSize) {
      _sensorBuffer.removeRange(0, _sensorBuffer.length - maxBufferSize);
    }

    // If in real-time mode, update state with new features
    final currentState = state;
    if (currentState is GaitRecognitionInProgress && currentState.isRealTime) {
      _updateRealtimeFeatures();
    }
  }

  /// Train new model from calibration data
  Future<void> trainModel({
    required List<GaitFeatures> trainingData,
    required String modelType,
    required int userId,
  }) async {
    if (trainingData.isEmpty) {
      emit(const GaitRecognitionError(
        'No training data provided',
        GaitRecognitionErrorType.insufficientData,
      ));
      return;
    }

    emit(const GaitRecognitionLoading());

    try {
      await _pipelineService.trainModel(
        trainingData: trainingData,
        modelType: modelType,
        userId: userId,
      );

      // Reinitialize pipeline to use new model
      await initialize(userId);
    } catch (e) {
      emit(GaitRecognitionError(
        'Failed to train model',
        e,
        GaitRecognitionErrorType.pipelineError,
      ));
    }
  }

  /// Switch recognizer type
  Future<void> switchRecognizer(RecognizerType type, int userId) async {
    try {
      await _pipelineService.switchRecognizer(type, userId);
      await initialize(userId);
    } catch (e) {
      emit(GaitRecognitionError(
        'Failed to switch recognizer',
        e,
        GaitRecognitionErrorType.pipelineError,
      ));
    }
  }

  /// Clear recognition history
  Future<void> clearHistory(int userId) async {
    try {
      // This would need to be implemented in MLModelRepository
      emit(const GaitRecognitionError(
        'Clear history not implemented yet',
        GaitRecognitionErrorType.pipelineError,
      ));
    } catch (e) {
      emit(GaitRecognitionError(
        'Failed to clear history',
        e,
        GaitRecognitionErrorType.pipelineError,
      ));
    }
  }

  /// Get pipeline status
  Future<Map<String, dynamic>> getPipelineStatus(int userId) async {
    try {
      return await _pipelineService.getPipelineStatus(userId);
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  // Private helper methods

  void _startRealtimeProcessing() {
    _realtimeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _updateRealtimeFeatures(),
    );
  }

  void _stopRealtimeProcessing() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
  }

  void _updateRealtimeFeatures() {
    if (_sensorBuffer.length < 10) return;

    try {
      final currentState = state;
      if (currentState is! GaitRecognitionInProgress) return;

      // Perform real-time recognition on recent buffer
      final result = _pipelineService.recognizeFromReadings(
        _sensorBuffer,
        currentState is GaitRecognitionReady ? currentState.userId : 1,
      );

      // Update state with new features
      if (result.isMatch) {
        emit(GaitRecognitionInProgress(
          isRealTime: true,
          windowSize: _sensorBuffer.length,
          features: result.features,
          confidence: result.confidence,
          patternType: result.patternType,
        ));
      } else {
        emit(GaitRecognitionInProgress(
          isRealTime: true,
          windowSize: _sensorBuffer.length,
          features: result.features,
          confidence: 0.0, // No match
          patternType: GaitPatternType.unknown,
        ));
      }
    } catch (e) {
      // Error in real-time processing
      print('Real-time recognition error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getRecognitionHistory(int userId) async {
    try {
      // This would need to be implemented in MLModelRepository
      // For now, return empty list
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> close() {
    _stopRealtimeProcessing();
    return super.close();
  }
}