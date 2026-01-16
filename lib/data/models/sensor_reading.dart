import 'package:flutter/foundation.dart';
import 'accelerometer_data.dart';
import 'gyroscope_data.dart';

/// Combined sensor reading containing both accelerometer and gyroscope data
/// captured at the same moment for comprehensive motion analysis.
@immutable
class SensorReading {
  const SensorReading({
    required this.accelerometer,
    required this.gyroscope,
    this.id,
  });

  /// Unique identifier for this reading (optional, for database storage)
  final String? id;
  
  /// Accelerometer reading
  final AccelerometerData accelerometer;
  
  /// Gyroscope reading
  final GyroscopeData gyroscope;

  /// Timestamp from accelerometer (should be the same as gyroscope)
  DateTime get timestamp => accelerometer.timestamp;

  /// Check if the timestamp difference between sensors is acceptable
  bool get isTimestampsSynchronized {
    final diff = accelerometer.timestamp.difference(gyroscope.timestamp).abs();
    return diff.inMilliseconds < 50; // Within 50ms is acceptable
  }

  /// Create a copy with updated values
  SensorReading copyWith({
    AccelerometerData? accelerometer,
    GyroscopeData? gyroscope,
    String? id,
  }) {
    return SensorReading(
      accelerometer: accelerometer ?? this.accelerometer,
      gyroscope: gyroscope ?? this.gyroscope,
      id: id ?? this.id,
    );
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accelerometer': accelerometer.toJson(),
      'gyroscope': gyroscope.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'isSynchronized': isTimestampsSynchronized,
    };
  }

  /// Create from JSON
  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['id'] as String?,
      accelerometer: AccelerometerData.fromJson(
        json['accelerometer'] as Map<String, dynamic>,
      ),
      gyroscope: GyroscopeData.fromJson(
        json['gyroscope'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorReading &&
        other.id == id &&
        other.accelerometer == accelerometer &&
        other.gyroscope == gyroscope;
  }

  @override
  int get hashCode {
    return Object.hash(id, accelerometer, gyroscope);
  }

  @override
  String toString() {
    return 'SensorReading(timestamp: $timestamp, accelerometer: $accelerometer, gyroscope: $gyroscope)';
  }
}

/// Buffer for managing sensor readings during collection sessions.
class SensorBuffer {
  SensorBuffer({
    this.maxSize = 1000,
  });

  final int maxSize;
  final List<SensorReading> _readings = [];

  /// Add a reading to the buffer
  void addReading(SensorReading reading) {
    _readings.add(reading);
    if (_readings.length > maxSize) {
      _readings.removeAt(0); // Remove oldest reading
    }
  }

  /// Add multiple readings to the buffer
  void addReadings(List<SensorReading> readings) {
    _readings.addAll(readings);
    if (_readings.length > maxSize) {
      final excess = _readings.length - maxSize;
      _readings.removeRange(0, excess);
    }
  }

  /// Get all readings from buffer
  List<SensorReading> get readings => List.unmodifiable(_readings);

  /// Get readings within a time range
  List<SensorReading> getReadingsInRange(DateTime start, DateTime end) {
    return _readings.where((reading) {
      final timestamp = reading.timestamp;
      return timestamp.isAfter(start) && timestamp.isBefore(end);
    }).toList();
  }

  /// Get recent readings within the last N milliseconds
  List<SensorReading> getRecentReadings(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return getReadingsInRange(cutoff, DateTime.now());
  }

  /// Clear all readings from buffer
  void clear() {
    _readings.clear();
  }

  /// Get buffer statistics
  Map<String, dynamic> get statistics {
    if (_readings.isEmpty) {
      return {
        'count': 0,
        'duration': Duration.zero,
        'firstTimestamp': null,
        'lastTimestamp': null,
      };
    }

    final firstTimestamp = _readings.first.timestamp;
    final lastTimestamp = _readings.last.timestamp;
    final duration = lastTimestamp.difference(firstTimestamp);

    return {
      'count': _readings.length,
      'duration': duration,
      'firstTimestamp': firstTimestamp,
      'lastTimestamp': lastTimestamp,
      'isSynchronized': _readings.every((r) => r.isTimestampsSynchronized),
    };
  }

  /// Check if buffer is empty
  bool get isEmpty => _readings.isEmpty;

  /// Check if buffer has readings
  bool get isNotEmpty => _readings.isNotEmpty;

  /// Get current buffer size
  int get size => _readings.length;
}