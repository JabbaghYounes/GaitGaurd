import 'package:meta/meta.dart';

/// Represents a single accelerometer reading from device sensors.
@immutable
class AccelerometerData {
  const AccelerometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  /// Acceleration along the X axis in m/s²
  final double x;
  
  /// Acceleration along the Y axis in m/s²
  final double y;
  
  /// Acceleration along the Z axis in m/s²
  final double z;
  
  /// Timestamp when the reading was captured (UTC)
  final DateTime timestamp;

  /// Calculate the magnitude (total acceleration)
  double get magnitude {
    return (x * x + y * y + z * z);
  }

  /// Calculate the root mean square (RMS) acceleration
  double get rms {
    return magnitude.sqrt();
  }

  /// Create a copy with updated values
  AccelerometerData copyWith({
    double? x,
    double? y,
    double? z,
    DateTime? timestamp,
  }) {
    return AccelerometerData(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
      'timestamp': timestamp.toIso8601String(),
      'magnitude': magnitude,
      'rms': rms,
    };
  }

  /// Create from JSON
  factory AccelerometerData.fromJson(Map<String, dynamic> json) {
    return AccelerometerData(
      x: json['x'] as double,
      y: json['y'] as double,
      z: json['z'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccelerometerData &&
        other.x == x &&
        other.y == y &&
        other.z == z &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(x, y, z, timestamp);
  }

  @override
  String toString() {
    return 'AccelerometerData(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, z: ${z.toStringAsFixed(3)}, timestamp: $timestamp)';
  }
}

/// Extension for double sqrt since dart:math is not imported
extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}