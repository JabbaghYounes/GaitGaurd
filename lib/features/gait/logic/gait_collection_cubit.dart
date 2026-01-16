import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/sensor_service.dart';
import '../../data/models/sensor_reading.dart';

/// Gait collection state classes
abstract class GaitCollectionState {
  const GaitCollectionState();
}

class GaitCollectionInitial extends GaitCollectionState {
  const GaitCollectionInitial();
}

class GaitCollectionLoading extends GaitCollectionState {
  const GaitCollectionLoading();
}

class GaitCollectionReady extends GaitCollectionState {
  const GaitCollectionReady({
    required this.sensorAvailability,
    this.samplingRate = 50.0,
  });

  final SensorAvailability sensorAvailability;
  final double samplingRate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaitCollectionReady &&
          runtimeType == other.runtimeType &&
          sensorAvailability == other.sensorAvailability &&
          samplingRate == other.samplingRate;

  @override
  int get hashCode => sensorAvailability.hashCode ^ samplingRate.hashCode;
}

class GaitCollectionCollecting extends GaitCollectionState {
  const GaitCollectionCollecting({
    required this.buffer,
    required this.duration,
    required this.readingCount,
    required this.samplingRate,
  });

  final SensorBuffer buffer;
  final Duration duration;
  final int readingCount;
  final double samplingRate;

  /// Get real-time statistics
  Map<String, dynamic> get statistics {
    return {
      'duration': duration,
      'readingCount': readingCount,
      'samplingRate': samplingRate,
      'actualRate': readingCount / duration.inSeconds,
      'bufferSize': buffer.size,
      'isSynchronized': buffer.statistics['isSynchronized'] ?? false,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaitCollectionCollecting &&
          runtimeType == other.runtimeType &&
          buffer == other.buffer &&
          duration == other.duration &&
          readingCount == other.readingCount &&
          samplingRate == other.samplingRate;

  @override
  int get hashCode =>
      buffer.hashCode ^
      duration.hashCode ^
      readingCount.hashCode ^
      samplingRate.hashCode;
}

class GaitCollectionStopped extends GaitCollectionState {
  const GaitCollectionStopped({
    required this.collectedData,
    required this.statistics,
  });

  final List<SensorReading> collectedData;
  final Map<String, dynamic> statistics;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaitCollectionStopped &&
          runtimeType == other.runtimeType &&
          collectedData == other.collectedData &&
          statistics == other.statistics;

  @override
  int get hashCode => collectedData.hashCode ^ statistics.hashCode;
}

class GaitCollectionError extends GaitCollectionState {
  const GaitCollectionError(this.message, [this.error]);

  final String message;
  final dynamic error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaitCollectionError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          error == other.error;

  @override
  int get hashCode => message.hashCode ^ error.hashCode;
}

/// Gait Collection Cubit for managing sensor data collection
class GaitCollectionCubit extends Cubit<GaitCollectionState> {
  GaitCollectionCubit(this._sensorService) : super(const GaitCollectionInitial());

  final SensorService _sensorService;
  final SensorBuffer _buffer = SensorBuffer(maxSize: 1000);
  
  DateTime? _collectionStartTime;
  StreamSubscription<SensorReading>? _sensorSubscription;
  Timer? _statisticsTimer;

  /// Initialize the cubit and check sensor availability
  Future<void> initialize() async {
    emit(const GaitCollectionLoading());

    try {
      final accelAvailable = await _sensorService.isAccelerometerAvailable();
      final gyroAvailable = await _sensorService.isGyroscopeAvailable();
      
      final sensorAvailability = SensorAvailability(
        accelerometerAvailable: accelAvailable,
        gyroscopeAvailable: gyroAvailable,
        accelerometerMinDelay: 20000, // 20ms = 50Hz max
        gyroscopeMinDelay: 20000,     // 20ms = 50Hz max
      );

      emit(GaitCollectionReady(
        sensorAvailability: sensorAvailability,
        samplingRate: _sensorService.samplingRate,
      ));
    } catch (e) {
      emit(GaitCollectionError('Failed to initialize sensors', e));
    }
  }

  /// Start collecting gait data
  Future<void> startCollection({double? samplingRate}) async {
    final currentState = state;
    if (currentState is! GaitCollectionReady) {
      emit(const GaitCollectionError('Sensors not ready for collection'));
      return;
    }

    if (!currentState.sensorAvailability.allSensorsAvailable) {
      emit(const GaitCollectionError('Required sensors not available'));
      return;
    }

    try {
      // Set sampling rate if provided
      if (samplingRate != null && samplingRate != currentState.samplingRate) {
        await _sensorService.setSamplingRate(samplingRate);
      }

      // Clear previous data and start fresh
      _buffer.clear();
      _collectionStartTime = DateTime.now();

      // Start sensor collection
      await _sensorService.startCollection();

      // Subscribe to sensor readings
      _sensorSubscription = _sensorService.sensorReadingStream.listen(
        _onSensorReading,
        onError: _onSensorError,
      );

      // Start statistics timer
      _statisticsTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        _updateStatistics,
      );

      // Emit collecting state
      emit(GaitCollectionCollecting(
        buffer: _buffer,
        duration: Duration.zero,
        readingCount: 0,
        samplingRate: samplingRate ?? currentState.samplingRate,
      ));
    } catch (e) {
      emit(GaitCollectionError('Failed to start collection', e));
    }
  }

  /// Stop collecting gait data
  Future<void> stopCollection() async {
    if (state is! GaitCollectionCollecting) return;

    try {
      await _sensorService.stopCollection();
      
      await _sensorSubscription?.cancel();
      _sensorSubscription = null;
      
      _statisticsTimer?.cancel();
      _statisticsTimer = null;

      final collectionDuration = _collectionStartTime != null
          ? DateTime.now().difference(_collectionStartTime!)
          : Duration.zero;

      final statistics = {
        'duration': collectionDuration,
        'readingCount': _buffer.size,
        'samplingRate': _sensorService.samplingRate,
        'actualRate': _buffer.size / collectionDuration.inSeconds,
        'bufferStatistics': _buffer.statistics,
        'isSynchronized': _buffer.statistics['isSynchronized'] ?? false,
      };

      final collectedData = List<SensorReading>.from(_buffer.readings);

      emit(GaitCollectionStopped(
        collectedData: collectedData,
        statistics: statistics,
      ));
    } catch (e) {
      emit(GaitCollectionError('Failed to stop collection', e));
    }
  }

  /// Clear collected data and return to ready state
  Future<void> clearData() async {
    _buffer.clear();
    
    final currentState = state;
    if (currentState is GaitCollectionStopped) {
      try {
        final accelAvailable = await _sensorService.isAccelerometerAvailable();
        final gyroAvailable = await _sensorService.isGyroscopeAvailable();
        
        final sensorAvailability = SensorAvailability(
          accelerometerAvailable: accelAvailable,
          gyroscopeAvailable: gyroAvailable,
          accelerometerMinDelay: 20000,
          gyroscopeMinDelay: 20000,
        );

        emit(GaitCollectionReady(
          sensorAvailability: sensorAvailability,
          samplingRate: _sensorService.samplingRate,
        ));
      } catch (e) {
        emit(GaitCollectionError('Failed to reset to ready state', e));
      }
    }
  }

  /// Set sampling rate during collection
  Future<void> setSamplingRate(double rate) async {
    try {
      await _sensorService.setSamplingRate(rate);
      
      if (state is GaitCollectionReady) {
        final readyState = state as GaitCollectionReady;
        emit(GaitCollectionReady(
          sensorAvailability: readyState.sensorAvailability,
          samplingRate: rate,
        ));
      }
    } catch (e) {
      emit(GaitCollectionError('Failed to set sampling rate', e));
    }
  }

  void _onSensorReading(SensorReading reading) {
    _buffer.addReading(reading);
  }

  void _onSensorError(dynamic error) {
    emit(GaitCollectionError('Sensor error during collection', error));
  }

  void _updateStatistics(Timer timer) {
    final currentState = state;
    if (currentState is GaitCollectionCollecting) {
      final currentDuration = _collectionStartTime != null
          ? DateTime.now().difference(_collectionStartTime!)
          : Duration.zero;

      emit(GaitCollectionCollecting(
        buffer: _buffer,
        duration: currentDuration,
        readingCount: _buffer.size,
        samplingRate: currentState.samplingRate,
      ));
    }
  }

  @override
  Future<void> close() {
    _sensorSubscription?.cancel();
    _statisticsTimer?.cancel();
    return super.close();
  }
}