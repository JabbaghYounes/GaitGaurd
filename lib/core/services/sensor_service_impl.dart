import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../../data/models/accelerometer_data.dart';
import '../../data/models/gyroscope_data.dart';
import '../../data/models/sensor_reading.dart';
import 'sensor_service.dart';

/// Concrete implementation of SensorService using sensors_plus package.
/// 
/// This implementation provides real sensor data collection from device
/// sensors with proper timestamping and synchronization.
class SensorServiceImpl implements SensorService {
  SensorServiceImpl({
    double samplingRate = 50.0, // 50Hz default
  }) : _samplingRate = samplingRate {
    _initializeStreams();
  }

  StreamController<AccelerometerData>? _accelerometerController;
  StreamController<GyroscopeData>? _gyroscopeController;
  StreamController<SensorReading>? _sensorReadingController;
  
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  double _samplingRate;
  bool _isCollecting = false;

  // Buffer for synchronizing sensor readings
  AccelerometerData? _lastAccelerometerReading;
  GyroscopeData? _lastGyroscopeReading;

  @override
  Stream<AccelerometerData> get accelerometerStream {
    return _accelerometerController?.stream ?? Stream.empty();
  }

  @override
  Stream<GyroscopeData> get gyroscopeStream {
    return _gyroscopeController?.stream ?? Stream.empty();
  }

  @override
  Stream<SensorReading> get sensorReadingStream {
    return _sensorReadingController?.stream ?? Stream.empty();
  }

  void _initializeStreams() {
    _accelerometerController = StreamController<AccelerometerData>.broadcast(
      onListen: () {
        if (!_isCollecting) {
          startCollection();
        }
      },
      onCancel: () {
        // Don't stop collection immediately - other listeners might exist
      },
    );

    _gyroscopeController = StreamController<GyroscopeData>.broadcast(
      onListen: () {
        if (!_isCollecting) {
          startCollection();
        }
      },
    );

    _sensorReadingController = StreamController<SensorReading>.broadcast(
      onListen: () {
        if (!_isCollecting) {
          startCollection();
        }
      },
    );
  }

  @override
  Future<bool> isAccelerometerAvailable() async {
    try {
      // Try to get a reading to check availability
      await accelerometerEvents.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Accelerometer not available'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isGyroscopeAvailable() async {
    try {
      await gyroscopeEvents.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Gyroscope not available'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AccelerometerData?> getCurrentAccelerometerReading() async {
    try {
      final event = await accelerometerEvents.first.timeout(
        const Duration(seconds: 1),
      );
      return AccelerometerData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<GyroscopeData?> getCurrentGyroscopeReading() async {
    try {
      final event = await gyroscopeEvents.first.timeout(
        const Duration(seconds: 1),
      );
      return GyroscopeData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<SensorReading?> getCurrentSensorReading() async {
    final accel = await getCurrentAccelerometerReading();
    final gyro = await getCurrentGyroscopeReading();
    
    if (accel == null || gyro == null) return null;
    
    return SensorReading(
      accelerometer: accel,
      gyroscope: gyro,
    );
  }

  @override
  Future<void> startCollection() async {
    if (_isCollecting) return;

    // Check sensor availability first
    final accelAvailable = await isAccelerometerAvailable();
    final gyroAvailable = await isGyroscopeAvailable();
    
    if (!accelAvailable || !gyroAvailable) {
      throw SensorException(
        'Required sensors not available. '
        'Accelerometer: $accelAvailable, Gyroscope: $gyroAvailable',
      );
    }

    _isCollecting = true;

    // Calculate delay for desired sampling rate
    final delayUs = (1000000 / _samplingRate).round();

    _accelerometerSubscription = accelerometerEvents.listen(
      (event) {
        final reading = AccelerometerData(
          x: event.x,
          y: event.y,
          z: event.z,
          timestamp: DateTime.now(),
        );
        
        _lastAccelerometerReading = reading;
        _accelerometerController?.add(reading);
        _tryEmitCombinedReading();
      },
      onError: (error) {
        _accelerometerController?.addError(
          SensorException('Accelerometer error', error),
        );
      },
    );

    _gyroscopeSubscription = gyroscopeEvents.listen(
      (event) {
        final reading = GyroscopeData(
          x: event.x,
          y: event.y,
          z: event.z,
          timestamp: DateTime.now(),
        );
        
        _lastGyroscopeReading = reading;
        _gyroscopeController?.add(reading);
        _tryEmitCombinedReading();
      },
      onError: (error) {
        _gyroscopeController?.addError(
          SensorException('Gyroscope error', error),
        );
      },
    );
  }

  @override
  Future<void> stopCollection() async {
    if (!_isCollecting) return;

    _isCollecting = false;

    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _lastAccelerometerReading = null;
    _lastGyroscopeReading = null;
  }

  void _tryEmitCombinedReading() {
    if (_lastAccelerometerReading == null || _lastGyroscopeReading == null) {
      return;
    }

    // Check if readings are reasonably synchronized (within 50ms)
    final timeDiff = _lastAccelerometerReading!.timestamp
        .difference(_lastGyroscopeReading!.timestamp)
        .abs();
    
    if (timeDiff.inMilliseconds <= 50) {
      final combinedReading = SensorReading(
        accelerometer: _lastAccelerometerReading!,
        gyroscope: _lastGyroscopeReading!,
      );
      
      _sensorReadingController?.add(combinedReading);
    }
  }

  @override
  bool get isCollecting => _isCollecting;

  @override
  double get samplingRate => _samplingRate;

  @override
  Future<void> setSamplingRate(double rate) async {
    if (rate <= 0 || rate > 1000) {
      throw SensorException('Sampling rate must be between 0 and 1000 Hz');
    }
    
    _samplingRate = rate;
    
    // Restart collection with new sampling rate
    if (_isCollecting) {
      await stopCollection();
      await startCollection();
    }
  }

  @override
  Future<Map<String, dynamic>> getSensorInfo() async {
    final accelAvailable = await isAccelerometerAvailable();
    final gyroAvailable = await isGyroscopeAvailable();

    return {
      'accelerometer': {
        'available': accelAvailable,
        'currentReading': _lastAccelerometerReading?.toJson(),
      },
      'gyroscope': {
        'available': gyroAvailable,
        'currentReading': _lastGyroscopeReading?.toJson(),
      },
      'sampling': {
        'isCollecting': _isCollecting,
        'samplingRate': _samplingRate,
      },
    };
  }

  /// Dispose of resources
  void dispose() {
    stopCollection();
    
    _accelerometerController?.close();
    _gyroscopeController?.close();
    _sensorReadingController?.close();
    
    _accelerometerController = null;
    _gyroscopeController = null;
    _sensorReadingController = null;
  }
}