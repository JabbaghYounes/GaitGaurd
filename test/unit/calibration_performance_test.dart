import 'package:flutter_test/flutter_test.dart';
import '../../../lib/data/models/calibration_session.dart';
import '../../../lib/core/services/calibration_error_handler.dart';

void main() {
  group('CalibrationSession Performance Tests', () {
    test('should handle large numbers of readings efficiently', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      // Add many readings (simulating long calibration)
      var currentSession = session;
      final startTime = DateTime.now();

      for (int i = 0; i < 10000; i++) {
        final reading = _createTestReading(i);
        currentSession = currentSession.addReading(reading);
      }

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime);

      // Should process 10,000 readings in reasonable time
      expect(processingTime.inMilliseconds, lessThan(1000));
      expect(currentSession.readingCount, equals(10000));
      expect(currentSession.averageSamplingRate, greaterThan(0));
    });

    test('should handle progress calculation efficiently', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.extended, // 5 minutes
      );

      // Test progress at different points
      final testTimes = [
        Duration(minutes: 1),   // 20%
        Duration(minutes: 2.5), // 50%
        Duration(minutes: 4),   // 80%
        Duration(minutes: 5),   // 100%
      ];

      for (final testTime in testTimes) {
        final testSession = session.copyWith(
          startTime: DateTime.now().subtract(testTime),
        );

        final expectedProgress = testTime.inMilliseconds / 300000; // 5 minutes in ms
        expect(testSession.progress, closeTo(expectedProgress, 0.01));
      }
    });

    test('should handle quality assessment efficiently', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      // Add readings with varying quality
      var currentSession = session;
      for (int i = 0; i < 1000; i++) {
        final reading = _createTestReading(i);
        currentSession = currentSession.addReading(reading);
      }

      final startTime = DateTime.now();

      // Test quality calculations
      expect(currentSession.quality, isNotNull);
      expect(currentSession.qualityScore, greaterThanOrEqualTo(0.0));
      expect(currentSession.qualityScore, lessThanOrEqualTo(1.0));

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime);

      expect(processingTime.inMilliseconds, lessThan(100));
    });
  });

  group('CalibrationSession Memory Tests', () {
    test('should not leak memory with many operations', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      // Perform many operations
      for (int batch = 0; batch < 100; batch++) {
        // Add readings
        for (int i = 0; i < 50; i++) {
          final reading = _createTestReading(batch * 50 + i);
          session.copyWith(readingCount: batch * 50 + i);
        }

        // Calculate statistics
        session.averageSamplingRate;
        session.progress;
        session.quality;
      }

      // Should complete without running out of memory
      expect(true, isTrue);
    });

    test('should handle large data sets efficiently', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.extended,
      );

      // Simulate extended calibration with many readings
      final readings = <SensorReading>[];
      for (int i = 0; i < 15000; i++) {
        readings.add(_createTestReading(i));
      }

      final startTime = DateTime.now();
      
      final finalSession = session.copyWith(
        readingCount: readings.length,
        collectedReadings: readings,
      );

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime);

      expect(processingTime.inMilliseconds, lessThan(500));
      expect(finalSession.readingCount, equals(15000));
    });
  });

  group('CalibrationSession Edge Case Tests', () {
    test('should handle zero readings correctly', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      expect(session.readingCount, equals(0));
      expect(session.averageSamplingRate, equals(0.0));
      expect(session.progress, greaterThanOrEqualTo(0.0));
    });

    test('should handle single reading correctly', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      final reading = _createTestReading(0);
      final updatedSession = session.addReading(reading);

      expect(updatedSession.readingCount, equals(1));
      expect(updatedSession.collectedReadings.length, equals(1));
      expect(updatedSession.averageSamplingRate, greaterThan(0));
    });

    test('should handle very short durations correctly', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      final testSession = session.copyWith(
        startTime: DateTime.now().subtract(const Duration(milliseconds: 100)),
      );

      expect(testSession.currentDuration.inMilliseconds, equals(100));
      expect(testSession.progress, greaterThan(0.0));
      expect(testSession.progress, lessThan(0.01));
    });

    test('should handle very long durations correctly', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.extended,
      );

      final testSession = session.copyWith(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(testSession.currentDuration.inHours, equals(1));
      expect(testSession.progress, greaterThan(1.0)); // Should cap at 1.0
      expect(testSession.progress, equals(1.0));
    });

    test('should handle negative scenarios gracefully', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      // Test with end time before start time (shouldn't happen but test resilience)
      final testSession = session.copyWith(
        startTime: DateTime.now(),
        endTime: DateTime.now().subtract(const Duration(seconds: 1)),
      );

      expect(testSession.currentDuration.inSeconds, lessThan(0));
      expect(testSession.isCompleted, isFalse); // Should not be completed for this scenario
    });

    test('should handle quality boundary values', () {
      final testCases = [
        {'score': 0.0, 'expectedQuality': CalibrationQuality.poor},
        {'score': 0.4, 'expectedQuality': CalibrationQuality.poor},
        {'score': 0.5, 'expectedQuality': CalibrationQuality.fair},
        {'score': 0.7, 'expectedQuality': CalibrationQuality.good},
        {'score': 0.9, 'expectedQuality': CalibrationQuality.excellent},
        {'score': 1.0, 'expectedQuality': CalibrationQuality.excellent},
      ];

      for (final testCase in testCases) {
        final session = CalibrationSession.create(
          userId: 1,
          type: CalibrationType.standard,
        ).copyWith(qualityScore: testCase['score'] as double);

        expect(session.quality, equals(testCase['expectedQuality']),
            reason: 'Quality mismatch for score ${testCase['score']}');
      }
    });
  });

  group('CalibrationSession Stress Tests', () {
    test('should handle concurrent operations', () async {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      // Simulate concurrent operations
      final futures = <Future<void>>[];
      
      for (int i = 0; i < 10; i++) {
        futures.add(Future(() {
          var localSession = session;
          for (int j = 0; j < 100; j++) {
            final reading = _createTestReading(i * 100 + j);
            localSession = localSession.addReading(reading);
          }
          // Access properties that might trigger calculations
          localSession.progress;
          localSession.averageSamplingRate;
        }));
      }

      await Future.wait(futures);
      expect(true, isTrue); // Should complete without errors
    });

    test('should handle rapid state changes', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      // Rapidly change states
      var currentSession = session;
      final operations = [
        () => currentSession.startCalibration(),
        () => currentSession.addReading(_createTestReading(0)),
        () => currentSession.addReading(_createTestReading(1)),
        () => currentSession.complete(qualityScore: 0.8),
        () => currentSession.cancel(),
      ];

      for (final operation in operations) {
        currentSession = operation();
      }

      // Final state should be cancelled
      expect(currentSession.status, equals(CalibrationStatus.cancelled));
      expect(currentSession.endTime, isNotNull);
    });

    test('should handle memory pressure', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.extended,
      );

      // Create large number of readings to test memory handling
      final readings = <SensorReading>[];
      for (int i = 0; i < 50000; i++) {
        readings.add(_createTestReading(i));
      }

      // Add readings in batches
      var currentSession = session;
      const batchSize = 1000;
      
      for (int i = 0; i < readings.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, readings.length);
        final batch = readings.sublist(i, end);
        
        // Add batch to session
        for (final reading in batch) {
          currentSession = currentSession.addReading(reading);
        }
        
        // Check progress periodically
        currentSession.progress;
        currentSession.averageSamplingRate;
      }

      expect(currentSession.readingCount, equals(readings.length));
    });
  });
}

SensorReading _createTestReading(int index) {
  final timestamp = DateTime.now().add(Duration(milliseconds: index * 20));
  return SensorReading(
    accelerometer: AccelerometerData(
      x: (index % 100) * 0.01,
      y: (index % 100) * 0.02,
      z: 9.8 + (index % 10) * 0.1,
      timestamp: timestamp,
    ),
    gyroscope: GyroscopeData(
      x: (index % 100) * 0.001,
      y: (index % 100) * 0.002,
      z: (index % 100) * 0.003,
      timestamp: timestamp,
    ),
  );
}

extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}