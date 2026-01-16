import 'dart:async';
import '../../data/models/accelerometer_data.dart';
import '../../data/models/gyroscope_data.dart';
import '../../data/models/sensor_reading.dart';

/// Abstract interface for sensor data collection.
/// 
/// This interface allows for easy testing with mock implementations
/// and provides a clean separation between UI and sensor logic.
abstract class SensorService {
  /// Stream of accelerometer readings
  Stream<AccelerometerData> get accelerometerStream;

  /// Stream of gyroscope readings  
  Stream<GyroscopeData> get gyroscopeStream;

  /// Stream of combined sensor readings
  Stream<SensorReading> get sensorReadingStream;

  /// Check if accelerometer is available
  Future<bool> isAccelerometerAvailable();

  /// Check if gyroscope is available
  Future<bool> isGyroscopeAvailable();

  /// Get current accelerometer reading (single value)
  Future<AccelerometerData?> getCurrentAccelerometerReading();

  /// Get current gyroscope reading (single value)
  Future<GyroscopeData?> getCurrentGyroscopeReading();

  /// Get current sensor reading (combined)
  Future<SensorReading?> getCurrentSensorReading();

  /// Start collecting sensor data
  Future<void> startCollection();

  /// Stop collecting sensor data
  Future<void> stopCollection();

  /// Check if collection is currently active
  bool get isCollecting;

  /// Get sensor sampling rate (Hz)
  double get samplingRate;

  /// Set sensor sampling rate (Hz)
  /// Note: Not all devices support custom sampling rates
  Future<void> setSamplingRate(double rate);

  /// Get sensor accuracy/quality information
  Future<Map<String, dynamic>> getSensorInfo();
}

/// Exception thrown when sensor operations fail
class SensorException implements Exception {
  const SensorException(this.message, [this.cause]);

  final String message;
  final dynamic cause;

  @override
  String toString() => 'SensorException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Sensor availability information
class SensorAvailability {
  const SensorAvailability({
    required this.accelerometerAvailable,
    required this.gyroscopeAvailable,
    required this.accelerometerMinDelay,
    required this.gyroscopeMinDelay,
  });

  final bool accelerometerAvailable;
  final bool gyroscopeAvailable;
  final int accelerometerMinDelay; // Microseconds
  final int gyroscopeMinDelay; // Microseconds

  /// Check if all required sensors are available
  bool get allSensorsAvailable => accelerometerAvailable && gyroscopeAvailable;

  /// Get minimum sampling rate that works for both sensors
  double get maxSamplingRate {
    final maxDelay = accelerometerMinDelay > gyroscopeMinDelay 
        ? accelerometerMinDelay 
        : gyroscopeMinDelay;
    return 1000000 / maxDelay; // Convert from microseconds to Hz
  }

  @override
  String toString() {
    return 'SensorAvailability('
        'accelerometer: $accelerometerAvailable, '
        'gyroscope: $gyroscopeAvailable, '
        'maxSamplingRate: ${maxSamplingRate.toStringAsFixed(1)}Hz)';
  }
}