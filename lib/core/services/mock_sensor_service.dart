import 'dart:async';
import 'dart:math';
import '../../data/models/accelerometer_data.dart';
import '../../data/models/gyroscope_data.dart';
import '../../data/models/sensor_reading.dart';
import 'sensor_service.dart';

/// Mock implementation of SensorService for testing and development.
/// 
/// This class generates realistic sensor data based on mathematical
/// patterns that simulate walking motion.
class MockSensorService implements SensorService {
  MockSensorService({
    double samplingRate = 50.0,
    this.mockWalkingPattern = true,
  }) : _samplingRate = samplingRate {
    _initializeStreams();
  }

  final bool mockWalkingPattern;
  
  StreamController<AccelerometerData>? _accelerometerController;
  StreamController<GyroscopeData>? _gyroscopeController;
  StreamController<SensorReading>? _sensorReadingController;
  
  Timer? _collectionTimer;
  double _samplingRate;
  bool _isCollecting = false;

  // Simulation state
  DateTime _startTime = DateTime.now();
  double _phase = 0.0;
  
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
    _accelerometerController = StreamController<AccelerometerData>.broadcast();
    _gyroscopeController = StreamController<GyroscopeData>.broadcast();
    _sensorReadingController = StreamController<SensorReading>.broadcast();
  }

  @override
  Future<bool> isAccelerometerAvailable() async => true;

  @override
  Future<bool> isGyroscopeAvailable() async => true;

  @override
  Future<AccelerometerData?> getCurrentAccelerometerReading() async {
    final timestamp = DateTime.now();
    return AccelerometerData(
      x: _generateAccelerometerX(timestamp),
      y: _generateAccelerometerY(timestamp),
      z: _generateAccelerometerZ(timestamp),
      timestamp: timestamp,
    );
  }

  @override
  Future<GyroscopeData?> getCurrentGyroscopeReading() async {
    final timestamp = DateTime.now();
    return GyroscopeData(
      x: _generateGyroscopeX(timestamp),
      y: _generateGyroscopeY(timestamp),
      z: _generateGyroscopeZ(timestamp),
      timestamp: timestamp,
    );
  }

  @override
  Future<SensorReading?> getCurrentSensorReading() async {
    final timestamp = DateTime.now();
    final accel = AccelerometerData(
      x: _generateAccelerometerX(timestamp),
      y: _generateAccelerometerY(timestamp),
      z: _generateAccelerometerZ(timestamp),
      timestamp: timestamp,
    );
    final gyro = GyroscopeData(
      x: _generateGyroscopeX(timestamp),
      y: _generateGyroscopeY(timestamp),
      z: _generateGyroscopeZ(timestamp),
      timestamp: timestamp,
    );
    
    return SensorReading(accelerometer: accel, gyroscope: gyro);
  }

  @override
  Future<void> startCollection() async {
    if (_isCollecting) return;

    _isCollecting = true;
    _startTime = DateTime.now();
    _phase = 0.0;

    final intervalMs = (1000.0 / _samplingRate).round();
    
    _collectionTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _generateAndEmitReadings(),
    );
  }

  @override
  Future<void> stopCollection() async {
    if (!_isCollecting) return;

    _isCollecting = false;
    _collectionTimer?.cancel();
    _collectionTimer = null;
  }

  void _generateAndEmitReadings() {
    final timestamp = DateTime.now();
    
    // Update phase for walking simulation
    if (mockWalkingPattern) {
      final elapsed = timestamp.difference(_startTime).inMilliseconds / 1000.0;
      _phase = elapsed * 2.0 * pi / 1.2; // ~1.2 second walking cycle
    }

    final accelReading = AccelerometerData(
      x: _generateAccelerometerX(timestamp),
      y: _generateAccelerometerY(timestamp),
      z: _generateAccelerometerZ(timestamp),
      timestamp: timestamp,
    );

    final gyroReading = GyroscopeData(
      x: _generateGyroscopeX(timestamp),
      y: _generateGyroscopeY(timestamp),
      z: _generateGyroscopeZ(timestamp),
      timestamp: timestamp,
    );

    final combinedReading = SensorReading(
      accelerometer: accelReading,
      gyroscope: gyroReading,
    );

    _accelerometerController?.add(accelReading);
    _gyroscopeController?.add(gyroReading);
    _sensorReadingController?.add(combinedReading);
  }

  // Accelerometer simulation methods
  double _generateAccelerometerX(DateTime timestamp) {
    if (mockWalkingPattern) {
      // Simulate lateral sway during walking
      return 0.5 * sin(_phase + pi/4) + Random().nextDouble() * 0.2 - 0.1;
    }
    return Random().nextDouble() * 2.0 - 1.0; // Random -1 to 1
  }

  double _generateAccelerometerY(DateTime timestamp) {
    if (mockWalkingPattern) {
      // Simulate forward-backward motion
      return 1.0 + 0.3 * sin(_phase) + Random().nextDouble() * 0.2 - 0.1;
    }
    return Random().nextDouble() * 2.0 - 1.0;
  }

  double _generateAccelerometerZ(DateTime timestamp) {
    if (mockWalkingPattern) {
      // Simulate vertical motion (up-down during walking)
      return 9.8 + 0.8 * sin(_phase * 2) + Random().nextDouble() * 0.3 - 0.15;
    }
    return 9.8 + Random().nextDouble() * 2.0 - 1.0; // Around gravity
  }

  // Gyroscope simulation methods
  double _generateGyroscopeX(DateTime timestamp) {
    if (mockWalkingPattern) {
      // Simulate pitch (forward/backward tilt)
      return 0.2 * cos(_phase) + Random().nextDouble() * 0.1 - 0.05;
    }
    return Random().nextDouble() * 0.4 - 0.2;
  }

  double _generateGyroscopeY(DateTime timestamp) {
    if (mockWalkingPattern) {
      // Simulate roll (side-to-side tilt)
      return 0.15 * sin(_phase + pi/2) + Random().nextDouble() * 0.1 - 0.05;
    }
    return Random().nextDouble() * 0.4 - 0.2;
  }

  double _generateGyroscopeZ(DateTime timestamp) {
    if (mockWalkingPattern) {
      // Simulate yaw (turning)
      return 0.1 * sin(_phase * 0.5) + Random().nextDouble() * 0.1 - 0.05;
    }
    return Random().nextDouble() * 0.4 - 0.2;
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
    return {
      'accelerometer': {
        'available': true,
        'mock': true,
      },
      'gyroscope': {
        'available': true,
        'mock': true,
      },
      'sampling': {
        'isCollecting': _isCollecting,
        'samplingRate': _samplingRate,
        'mockWalkingPattern': mockWalkingPattern,
      },
    };
  }

  /// Set custom acceleration values for testing specific scenarios
  void setCustomAcceleration(double x, double y, double z) {
    _customAcceleration = Tuple3(x, y, z);
  }
  
  /// Reset to default simulation
  void resetToDefault() {
    _customAcceleration = null;
  }

  Tuple3<double, double, double>? _customAcceleration;

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

/// Simple tuple class for custom acceleration values
class Tuple3<T1, T2, T3> {
  const Tuple3(this.item1, this.item2, this.item3);
  final T1 item1;
  final T2 item2;
  final T3 item3;
}