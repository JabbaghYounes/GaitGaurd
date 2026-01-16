import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/calibration_session.dart';
import '../../../data/models/sensor_reading.dart';
import '../../../core/services/calibration_service.dart';
import '../../../core/services/sensor_service.dart';

/// Calibration state classes
abstract class CalibrationState {
  const CalibrationState();
}

class CalibrationInitial extends CalibrationState {
  const CalibrationInitial();
}

class CalibrationLoading extends CalibrationState {
  const CalibrationLoading();
}

class CalibrationReady extends CalibrationState {
  const CalibrationReady({
    required this.userId,
    required this.availableTypes,
    this.latestCalibration,
    this.canStartCalibration = true,
    this.errorMessage,
  });

  final int userId;
  final List<CalibrationType> availableTypes;
  final CalibrationSession? latestCalibration;
  final bool canStartCalibration;
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalibrationReady &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          canStartCalibration == other.canStartCalibration &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => userId.hashCode ^ canStartCalibration.hashCode ^ errorMessage.hashCode;
}

class CalibrationInProgress extends CalibrationState {
  const CalibrationInProgress({
    required this.session,
    required this.currentProgress,
    required this.estimatedTimeRemaining,
    this.sensorReadings = const [],
    this.averageSamplingRate = 0.0,
    this.dataQuality = 0.0,
  });

  final CalibrationSession session;
  final double currentProgress;
  final Duration estimatedTimeRemaining;
  final List<SensorReading> sensorReadings;
  final double averageSamplingRate;
  final double dataQuality;

  /// Get real-time statistics
  Map<String, dynamic> get statistics {
    return {
      'sessionId': session.id,
      'type': session.type.displayName,
      'duration': session.currentDuration,
      'progress': currentProgress,
      'readingCount': session.readingCount,
      'averageSamplingRate': averageSamplingRate,
      'dataQuality': dataQuality,
      'estimatedTimeRemaining': estimatedTimeRemaining.inSeconds,
      'isSynchronized': sensorReadings.every((r) => r.isTimestampsSynchronized),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalibrationInProgress &&
          runtimeType == other.runtimeType &&
          session == other.session &&
          currentProgress == other.currentProgress &&
          estimatedTimeRemaining == other.estimatedTimeRemaining &&
          sensorReadings.length == other.sensorReadings.length &&
          averageSamplingRate == other.averageSamplingRate &&
          dataQuality == other.dataQuality;

  @override
  int get hashCode =>
      session.hashCode ^
      currentProgress.hashCode ^
      estimatedTimeRemaining.hashCode ^
      sensorReadings.length.hashCode ^
      averageSamplingRate.hashCode ^
      dataQuality.hashCode;
}

class CalibrationCompleted extends CalibrationState {
  const CalibrationCompleted({
    required this.session,
    this.summary,
  });

  final CalibrationSession session;
  final Map<String, dynamic>? summary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalibrationCompleted &&
          runtimeType == other.runtimeType &&
          session == other.session;

  @override
  int get hashCode => session.hashCode;
}

class CalibrationError extends CalibrationState {
  const CalibrationError(this.message, [this.error, this.session]);

  final String message;
  final dynamic error;
  final CalibrationSession? session;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalibrationError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          error == other.error;

  @override
  int get hashCode => message.hashCode ^ error.hashCode;
}

/// Calibration Cubit for managing gait calibration sessions
class CalibrationCubit extends Cubit<CalibrationState> {
  CalibrationCubit(
    this._calibrationService,
    this._sensorService,
  ) : super(const CalibrationInitial());

  final CalibrationService _calibrationService;
  final SensorService _sensorService;

  StreamSubscription<SensorReading>? _sensorSubscription;
  Timer? _progressTimer;
  Timer? _qualityTimer;
  List<SensorReading> _sensorReadings = [];

  /// Initialize calibration system for user
  Future<void> initialize(int userId) async {
    emit(const CalibrationLoading());

    try {
      // Validate requirements
      final canStart = await _calibrationService.validateCalibrationRequirements(userId);

      // Get latest calibration
      final latestCalibration = await _calibrationService.getLatestCalibration(userId);

      // Get available types
      final availableTypes = CalibrationType.values;

      emit(CalibrationReady(
        userId: userId,
        availableTypes: availableTypes,
        latestCalibration: latestCalibration,
        canStartCalibration: canStart,
      ));
    } catch (e) {
      emit(CalibrationError('Failed to initialize calibration', e));
    }
  }

  /// Start a calibration session
  Future<void> startCalibration(CalibrationType type, int userId) async {
    final currentState = state;
    if (currentState is! CalibrationReady) {
      emit(const CalibrationError('Calibration not ready for new session'));
      return;
    }

    if (!currentState.canStartCalibration) {
      emit(const CalibrationError('Cannot start calibration at this time'));
      return;
    }

    try {
      // Start calibration
      final session = await _calibrationService.startCalibration(
        userId: userId,
        type: type,
      );

      // Subscribe to sensor readings
      _sensorSubscription = _sensorService.sensorReadingStream.listen(
        _onSensorReading,
        onError: _onSensorError,
      );

      // Start progress tracking
      _startProgressTracking(session);

      // Start quality monitoring
      _startQualityMonitoring();

      emit(CalibrationInProgress(
        session: session,
        currentProgress: session.progress,
        estimatedTimeRemaining: session.estimatedTimeRemaining ?? Duration.zero,
        sensorReadings: _sensorReadings,
      ));
    } catch (e) {
      emit(CalibrationError('Failed to start calibration', e));
    }
  }

  /// Cancel current calibration session
  Future<void> cancelCalibration() async {
    final currentState = state;
    if (currentState is! CalibrationInProgress) {
      emit(const CalibrationError('No calibration session in progress'));
      return;
    }

    try {
      await _calibrationService.cancelCalibration(currentState.session);

      // Clean up resources
      await _stopProgressTracking();
      await _stopSensorCollection();

      // Return to ready state
      await initialize(currentState.session.userId);
    } catch (e) {
      emit(CalibrationError('Failed to cancel calibration', e));
    }
  }

  /// Retry calibration after error
  Future<void> retryCalibration() async {
    final currentState = state;
    if (currentState is CalibrationError && currentState.session != null) {
      final session = currentState.session!;
      await initialize(session.userId);
      await startCalibration(session.type, session.userId);
    } else {
      emit(const CalibrationError('Cannot retry: no previous session'));
    }
  }

  /// Get calibration history for user
  Future<void> loadCalibrationHistory(int userId) async {
    try {
      final sessions = await _calibrationService.getCalibrationHistory(userId);
      
      // Update current state with history (if ready)
      final currentState = state;
      if (currentState is CalibrationReady) {
        emit(currentState);
      }
    } catch (e) {
      emit(CalibrationError('Failed to load calibration history', e));
    }
  }

  /// Delete a calibration session
  Future<void> deleteCalibration(int sessionId, int userId) async {
    try {
      await _calibrationService.deleteCalibration(sessionId, userId);
      await initialize(userId); // Refresh state
    } catch (e) {
      emit(CalibrationError('Failed to delete calibration', e));
    }
  }

  void _onSensorReading(SensorReading reading) {
    final currentState = state;
    if (currentState is CalibrationInProgress) {
      _sensorReadings.add(reading);

      // Process reading through calibration service
      _calibrationService.processCalibrationReading(
        currentState.session,
        reading,
      ).then((updatedSession) {
        // Update state with new session data
        emit(CalibrationInProgress(
          session: updatedSession,
          currentProgress: updatedSession.progress,
          estimatedTimeRemaining: updatedSession.estimatedTimeRemaining ?? Duration.zero,
          sensorReadings: _sensorReadings,
          averageSamplingRate: updatedSession.averageSamplingRate,
          dataQuality: _calculateRealTimeQuality(_sensorReadings),
        ));

        // Check if calibration is complete
        if (updatedSession.progress >= 1.0) {
          _completeCalibration(updatedSession);
        }
      }).catchError((error) {
        emit(CalibrationError('Error processing sensor reading', error, currentState.session));
      });
    }
  }

  void _onSensorError(dynamic error) {
    final currentState = state;
    if (currentState is CalibrationInProgress) {
      emit(CalibrationError('Sensor error during calibration', error, currentState.session));
      _cleanupResources();
    }
  }

  void _startProgressTracking(CalibrationSession session) {
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        final currentState = state;
        if (currentState is CalibrationInProgress) {
          final updatedSession = currentState.session.copyWith(
            readingCount: _sensorReadings.length,
          );

          emit(CalibrationInProgress(
            session: updatedSession,
            currentProgress: updatedSession.progress,
            estimatedTimeRemaining: updatedSession.estimatedTimeRemaining ?? Duration.zero,
            sensorReadings: _sensorReadings,
            averageSamplingRate: updatedSession.averageSamplingRate,
            dataQuality: _calculateRealTimeQuality(_sensorReadings),
          ));
        }
      },
    );
  }

  void _startQualityMonitoring() {
    _qualityTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        final currentState = state;
        if (currentState is CalibrationInProgress) {
          final quality = _calculateRealTimeQuality(_sensorReadings);
          // Could emit warnings if quality is poor
          if (quality < 0.3) {
            // Could show warning to user
          }
        }
      },
    );
  }

  Future<void> _completeCalibration(CalibrationSession session) async {
    try {
      final completedSession = await _calibrationService.completeCalibration(session);

      await _stopProgressTracking();
      await _stopSensorCollection();

      final summary = {
        'type': completedSession.type.displayName,
        'duration': completedSession.currentDuration,
        'readingCount': completedSession.readingCount,
        'averageSamplingRate': completedSession.averageSamplingRate,
        'qualityScore': completedSession.qualityScore,
        'quality': completedSession.quality.displayName,
      };

      emit(CalibrationCompleted(
        session: completedSession,
        summary: summary,
      ));
    } catch (e) {
      emit(CalibrationError('Failed to complete calibration', e, session));
      _cleanupResources();
    }
  }

  double _calculateRealTimeQuality(List<SensorReading> readings) {
    if (readings.length < 10) return 0.0;

    // Simple real-time quality assessment
    final syncRate = readings.where((r) => r.isTimestampsSynchronized).length / readings.length;
    
    // Check sampling rate stability
    if (readings.length > 20) {
      final intervals = <double>[];
      for (int i = 1; i < 20; i++) {
        final interval = readings[i].timestamp
            .difference(readings[i - 1].timestamp)
            .inMicroseconds / 1000000.0;
        intervals.add(interval);
      }
      
      final meanInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      final targetInterval = 1.0 / 50.0; // 50Hz
      final stability = 1.0 - (meanInterval - targetInterval).abs() / targetInterval;
      
      return ((syncRate + stability.clamp(0.0, 1.0)) / 2.0).clamp(0.0, 1.0);
    }

    return syncRate;
  }

  Future<void> _stopProgressTracking() async {
    _progressTimer?.cancel();
    _progressTimer = null;
    _qualityTimer?.cancel();
    _qualityTimer = null;
  }

  Future<void> _stopSensorCollection() async {
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _sensorReadings.clear();
  }

  void _cleanupResources() {
    _stopProgressTracking();
    _stopSensorCollection();
  }

  @override
  Future<void> close() {
    _cleanupResources();
    return super.close();
  }
}