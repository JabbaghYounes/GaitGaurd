import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:math';
import '../../../lib/data/models/sensor_reading.dart';
import '../../../lib/data/models/accelerometer_data.dart';
import '../../../lib/data/models/gyroscope_data.dart';

void main() {
  group('SensorReading Stream Integration Tests', () {
    test('should handle high-frequency sensor data', () async {
      final readings = <SensorReading>[];
      final controller = StreamController<SensorReading>();
      
      controller.stream.listen(readings.add);
      
      // Simulate high-frequency data (100 Hz for 1 second)
      final now = DateTime.now();
      for (int i = 0; i < 100; i++) {
        final timestamp = now.add(Duration(milliseconds: i * 10));
        controller.add(SensorReading(
          accelerometer: AccelerometerData(
            x: sin(i * 0.1),
            y: cos(i * 0.1),
            z: 9.8 + sin(i * 0.2),
            timestamp: timestamp,
          ),
          gyroscope: GyroscopeData(
            x: sin(i * 0.05),
            y: cos(i * 0.05),
            z: sin(i * 0.03),
            timestamp: timestamp,
          ),
        ));
      }
      
      await controller.close();
      
      expect(readings.length, equals(100));
      
      // Verify data integrity
      for (final reading in readings) {
        expect(reading.accelerometer.z.abs(), lessThan(15.0));
        expect(reading.gyroscope.x.abs(), lessThan(2.0));
        expect(reading.isTimestampsSynchronized, isTrue);
      }
    });

    test('should handle bursty sensor data with gaps', () async {
      final readings = <SensorReading>[];
      final controller = StreamController<SensorReading>();
      
      controller.stream.listen(readings.add);
      
      final now = DateTime.now();
      
      // First burst
      for (int i = 0; i < 10; i++) {
        controller.add(_createTestReading(now.add(Duration(milliseconds: i * 10))));
      }
      
      // Gap of 500ms
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Second burst
      for (int i = 0; i < 10; i++) {
        controller.add(_createTestReading(
          now.add(Duration(milliseconds: 500 + i * 10))
        ));
      }
      
      await controller.close();
      
      expect(readings.length, equals(20));
      
      // Check that we have the expected time gap
      final firstBurstEnd = readings[9].timestamp;
      final secondBurstStart = readings[10].timestamp;
      final gap = secondBurstStart.difference(firstBurstEnd);
      
      expect(gap.inMilliseconds, greaterThan(400)); // Should be around 500ms
    });

    test('should handle mixed synchronized and unsynchronized readings', () async {
      final synchronized = <SensorReading>[];
      final unsynchronized = <SensorReading>[];
      final controller = StreamController<SensorReading>();
      
      controller.stream.listen((reading) {
        if (reading.isTimestampsSynchronized) {
          synchronized.add(reading);
        } else {
          unsynchronized.add(reading);
        }
      });
      
      final now = DateTime.now();
      
      // Add synchronized readings
      for (int i = 0; i < 5; i++) {
        final timestamp = now.add(Duration(milliseconds: i * 20));
        controller.add(SensorReading(
          accelerometer: AccelerometerData(x: 0, y: 0, z: 9.8, timestamp: timestamp),
          gyroscope: GyroscopeData(x: 0, y: 0, z: 0, timestamp: timestamp),
        ));
      }
      
      // Add unsynchronized reading
      controller.add(SensorReading(
        accelerometer: AccelerometerData(
          x: 0, y: 0, z: 9.8, 
          timestamp: now.add(const Duration(milliseconds: 100))
        ),
        gyroscope: GyroscopeData(
          x: 0, y: 0, z: 0, 
          timestamp: now.add(const Duration(milliseconds: 200)) // 100ms gap
        ),
      ));
      
      // Add more synchronized readings
      for (int i = 0; i < 5; i++) {
        final timestamp = now.add(Duration(milliseconds: 300 + i * 20));
        controller.add(SensorReading(
          accelerometer: AccelerometerData(x: 0, y: 0, z: 9.8, timestamp: timestamp),
          gyroscope: GyroscopeData(x: 0, y: 0, z: 0, timestamp: timestamp),
        ));
      }
      
      await controller.close();
      
      expect(synchronized.length, equals(10));
      expect(unsynchronized.length, equals(1));
    });

    test('should buffer high-frequency data correctly', () async {
      final buffer = SensorBuffer(maxSize: 50);
      final readings = <SensorReading>[];
      
      // Generate 100 readings at high frequency
      final now = DateTime.now();
      for (int i = 0; i < 100; i++) {
        final timestamp = now.add(Duration(milliseconds: i * 5)); // 200 Hz
        readings.add(_createTestReading(timestamp));
      }
      
      // Add to buffer
      buffer.addReadings(readings);
      
      expect(buffer.size, equals(50)); // Should be at max size
      
      // Should contain the most recent 50 readings
      final bufferReadings = buffer.readings;
      expect(bufferReadings.length, equals(50));
      
      // Should contain the last reading
      expect(bufferReadings.last, equals(readings.last));
      
      // Should not contain the first 50 readings
      for (int i = 0; i < 50; i++) {
        expect(bufferReadings, isNot(contains(readings[i])));
      }
    });

    test('should handle time-based filtering correctly', () async {
      final buffer = SensorBuffer();
      final now = DateTime.now();
      
      // Add readings over a 5-second period
      for (int i = 0; i < 50; i++) {
        final timestamp = now.add(Duration(milliseconds: i * 100)); // 10 Hz
        buffer.addReading(_createTestReading(timestamp));
      }
      
      // Get readings from the last 2 seconds
      final recentReadings = buffer.getReadingsInRange(
        now.add(const Duration(seconds: 3)),
        now.add(const Duration(seconds: 5)),
      );
      
      expect(recentReadings.length, equals(20)); // 2 seconds at 10 Hz
      
      // Verify timestamps are in correct range
      for (final reading in recentReadings) {
        expect(
          reading.timestamp.isAfter(now.add(const Duration(seconds: 2))),
          isTrue,
        );
        expect(
          reading.timestamp.isBefore(now.add(const Duration(seconds: 5, milliseconds: 100))),
          isTrue,
        );
      }
      
      // Test getRecentReadings helper
      final lastSecondReadings = buffer.getRecentReadings(const Duration(seconds: 1));
      expect(lastSecondReadings.length, equals(10)); // 1 second at 10 Hz
    });

    test('should calculate buffer statistics accurately', () async {
      final buffer = SensorBuffer();
      final now = DateTime.now();
      
      // Add readings with known timing
      final readings = <SensorReading>[];
      for (int i = 0; i < 30; i++) {
        final timestamp = now.add(Duration(milliseconds: i * 50)); // 20 Hz
        final reading = _createTestReading(timestamp);
        readings.add(reading);
        buffer.addReading(reading);
      }
      
      final stats = buffer.statistics;
      
      expect(stats['count'], equals(30));
      
      final duration = stats['duration'] as Duration;
      expect(duration.inMilliseconds, equals(1450)); // 29 intervals * 50ms
      
      expect(stats['firstTimestamp'], equals(readings.first.timestamp));
      expect(stats['lastTimestamp'], equals(readings.last.timestamp));
      expect(stats['isSynchronized'], isTrue);
    });

    test('should handle concurrent operations safely', () async {
      final buffer = SensorBuffer(maxSize: 1000);
      final futures = <Future<void>>[];
      
      // Simulate concurrent additions from multiple "sensors"
      for (int thread = 0; thread < 5; thread++) {
        futures.add(Future(() async {
          for (int i = 0; i < 100; i++) {
            final reading = _createTestReading(DateTime.now());
            buffer.addReading(reading);
            // Small delay to simulate real sensor timing
            await Future.delayed(const Duration(microseconds: 100));
          }
        }));
      }
      
      // Wait for all concurrent operations to complete
      await Future.wait(futures);
      
      expect(buffer.size, lessThanOrEqualTo(1000)); // Should not exceed max size
      expect(buffer.size, greaterThan(0)); // Should have data
    });

    test('should handle stream errors gracefully', () async {
      final readings = <SensorReading>[];
      final errors = <dynamic>[];
      final controller = StreamController<SensorReading>();
      
      controller.stream.listen(
        readings.add,
        onError: errors.add,
      );
      
      // Add some valid readings
      controller.add(_createTestReading());
      controller.add(_createTestReading());
      
      // Add an error
      controller.addError('Sensor malfunction');
      
      // Add more valid readings after error
      controller.add(_createTestReading());
      
      await controller.close();
      
      expect(readings.length, equals(3));
      expect(errors.length, equals(1));
      expect(errors.first, equals('Sensor malfunction'));
    });

    test('should maintain data consistency during rapid updates', () async {
      final buffer = SensorBuffer();
      final controller = StreamController<SensorReading>();
      
      // Subscribe to buffer updates
      controller.stream.listen(buffer.addReading);
      
      final now = DateTime.now();
      final allReadings = <SensorReading>[];
      
      // Rapidly generate readings
      for (int i = 0; i < 200; i++) {
        final reading = SensorReading(
          accelerometer: AccelerometerData(
            x: sin(i * 0.1),
            y: cos(i * 0.1),
            z: 9.8 + sin(i * 0.2),
            timestamp: now.add(Duration(microseconds: i * 5000)), // 200 Hz
          ),
          gyroscope: GyroscopeData(
            x: sin(i * 0.05),
            y: cos(i * 0.05),
            z: sin(i * 0.03),
            timestamp: now.add(Duration(microseconds: i * 5000)),
          ),
        );
        allReadings.add(reading);
        controller.add(reading);
      }
      
      await controller.close();
      
      // Verify buffer maintained data integrity
      expect(buffer.size, greaterThan(0));
      
      final bufferReadings = buffer.readings;
      expect(bufferReadings.length, equals(allReadings.length));
      
      // Verify all readings are properly synchronized
      expect(
        bufferReadings.every((r) => r.isTimestampsSynchronized),
        isTrue,
      );
      
      // Verify timestamps are monotonic
      for (int i = 1; i < bufferReadings.length; i++) {
        expect(
          bufferReadings[i].timestamp.isAfter(bufferReadings[i - 1].timestamp),
          isTrue,
        );
      }
    });
  });
}

SensorReading _createTestReading([DateTime? timestamp]) {
  final ts = timestamp ?? DateTime.now();
  return SensorReading(
    accelerometer: AccelerometerData(
      x: 1.0 + sin(ts.millisecondsSinceEpoch * 0.001),
      y: 2.0 + cos(ts.millisecondsSinceEpoch * 0.001),
      z: 9.8 + sin(ts.millisecondsSinceEpoch * 0.002),
      timestamp: ts,
    ),
    gyroscope: GyroscopeData(
      x: sin(ts.millisecondsSinceEpoch * 0.0005),
      y: cos(ts.millisecondsSinceEpoch * 0.0005),
      z: sin(ts.millisecondsSinceEpoch * 0.0003),
      timestamp: ts,
    ),
  );
}

extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}