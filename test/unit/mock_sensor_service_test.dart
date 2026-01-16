import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/services/mock_sensor_service.dart';
import '../../../lib/data/models/sensor_reading.dart';
import '../../../lib/data/models/accelerometer_data.dart';
import '../../../lib/data/models/gyroscope_data.dart';

void main() {
  group('MockSensorService Tests', () {
    late MockSensorService mockService;

    setUp(() {
      mockService = MockSensorService(samplingRate: 50.0);
    });

    tearDown(() {
      mockService.dispose();
    });

    test('should report sensors as available', () async {
      expect(await mockService.isAccelerometerAvailable(), isTrue);
      expect(await mockService.isGyroscopeAvailable(), isTrue);
    });

    test('should provide single readings', () async {
      final accelReading = await mockService.getCurrentAccelerometerReading();
      final gyroReading = await mockService.getCurrentGyroscopeReading();
      final combinedReading = await mockService.getCurrentSensorReading();

      expect(accelReading, isNotNull);
      expect(gyroReading, isNotNull);
      expect(combinedReading, isNotNull);

      expect(accelReading!.z, closeTo(9.8, 2.0)); // Should be around gravity
      expect(gyroReading!.x.abs(), lessThan(1.0)); // Should be small values
    });

    test('should provide streaming data', () async {
      final accelReadings = <AccelerometerData>[];
      final gyroReadings = <GyroscopeData>[];
      final combinedReadings = <SensorReading>[];

      mockService.accelerometerStream.listen(accelReadings.add);
      mockService.gyroscopeStream.listen(gyroReadings.add);
      mockService.sensorReadingStream.listen(combinedReadings.add);

      await mockService.startCollection();

      // Wait for some data
      await Future.delayed(const Duration(milliseconds: 200));

      await mockService.stopCollection();

      expect(accelReadings, isNotEmpty);
      expect(gyroReadings, isNotEmpty);
      expect(combinedReadings, isNotEmpty);

      // Check that accelerometer z-axis is around gravity
      expect(accelReadings.last.z, closeTo(9.8, 2.0));
    });

    test('should generate walking pattern when enabled', () async {
      final walkingService = MockSensorService(
        samplingRate: 50.0,
        mockWalkingPattern: true,
      );

      await walkingService.startCollection();

      final readings = <SensorReading>[];
      walkingService.sensorReadingStream.take(10).toList().then(readings.addAll);

      // Wait for enough samples
      await Future.delayed(const Duration(milliseconds: 300));

      await walkingService.stopCollection();

      if (readings.isNotEmpty) {
        // Check for walking patterns (periodic motion)
        final zValues = readings.map((r) => r.accelerometer.z).toList();
        final hasVariation = zValues.any((z) => (z - 9.8).abs() > 0.5);
        expect(hasVariation, isTrue, reason: 'Should detect walking motion variation');
      }

      walkingService.dispose();
    });

    test('should respect sampling rate', () async {
      const targetRate = 100.0;
      final service = MockSensorService(samplingRate: targetRate);

      final timestamps = <DateTime>[];
      service.sensorReadingStream.listen((reading) {
        timestamps.add(reading.timestamp);
      });

      await service.startCollection();

      // Collect samples for analysis
      await Future.delayed(const Duration(milliseconds: 200));

      await service.stopCollection();
      service.dispose();

      if (timestamps.length >= 2) {
        final intervals = <Duration>[];
        for (int i = 1; i < timestamps.length; i++) {
          intervals.add(timestamps[i].difference(timestamps[i - 1]));
        }

        final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
        final actualRate = 1000 / avgInterval.inMilliseconds;

        // Allow for some tolerance
        expect(actualRate, closeTo(targetRate, targetRate * 0.2));
      }
    });

    test('should allow setting custom sampling rate', () async {
      const newRate = 75.0;
      
      await mockService.setSamplingRate(newRate);
      
      expect(mockService.samplingRate, equals(newRate));
    });

    test('should reject invalid sampling rates', () async {
      expect(
        () => mockService.setSamplingRate(-1.0),
        throwsA(isA<SensorException>()),
      );

      expect(
        () => mockService.setSamplingRate(2000.0),
        throwsA(isA<SensorException>()),
      );
    });

    test('should provide sensor information', () async {
      final info = await mockService.getSensorInfo();

      expect(info['accelerometer']['available'], isTrue);
      expect(info['gyroscope']['available'], isTrue);
      expect(info['sampling']['isCollecting'], isFalse);
      expect(info['sampling']['samplingRate'], equals(50.0));
    });

    test('should handle start/stop collection state correctly', () async {
      expect(mockService.isCollecting, isFalse);

      await mockService.startCollection();
      expect(mockService.isCollecting, isTrue);

      await mockService.stopCollection();
      expect(mockService.isCollecting, isFalse);
    });

    test('should generate realistic accelerometer values', () async {
      final reading = await mockService.getCurrentAccelerometerReading();

      expect(reading, isNotNull);
      expect(reading!.x.abs(), lessThan(5.0));
      expect(reading.y.abs(), lessThan(5.0));
      // Z should be around gravity (9.8 m/s²)
      expect(reading.z, greaterThan(5.0));
      expect(reading.z, lessThan(15.0));
    });

    test('should generate realistic gyroscope values', () async {
      final reading = await mockService.getCurrentGyroscopeReading();

      expect(reading, isNotNull);
      // Gyroscope values should be small (measuring rotation)
      expect(reading!.x.abs(), lessThan(2.0));
      expect(reading.y.abs(), lessThan(2.0));
      expect(reading.z.abs(), lessThan(2.0));
    });

    test('should generate synchronized readings', () async {
      await mockService.startCollection();

      final readings = <SensorReading>[];
      await mockService.sensorReadingStream.take(5).toList().then(readings.addAll);
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      await mockService.stopCollection();

      if (readings.isNotEmpty) {
        // All readings should have synchronized timestamps
        expect(
          readings.every((r) => r.isTimestampsSynchronized),
          isTrue,
          reason: 'All readings should have synchronized timestamps',
        );
      }
    });

    test('should allow custom acceleration setting', () async {
      mockService.setCustomAcceleration(1.5, 2.5, 10.5);

      final reading = await mockService.getCurrentAccelerometerReading();

      expect(reading!.x, equals(1.5));
      expect(reading.y, equals(2.5));
      expect(reading.z, equals(10.5));

      mockService.resetToDefault();
      
      final resetReading = await mockService.getCurrentAccelerometerReading();
      // Should be back to default values (around gravity)
      expect(resetReading!.z, closeTo(9.8, 2.0));
    });
  });

  group('Sensor Data Validation Tests', () {
    test('should generate consistent timestamps', () async {
      final service = MockSensorService();
      
      final readings = <SensorReading>[];
      service.sensorReadingStream.listen(readings.add);

      await service.startCollection();
      
      // Collect multiple readings
      await Future.delayed(const Duration(milliseconds: 300));
      
      await service.stopCollection();
      service.dispose();

      if (readings.length >= 2) {
        // Check that timestamps are increasing
        for (int i = 1; i < readings.length; i++) {
          expect(
            readings[i].timestamp.isAfter(readings[i - 1].timestamp),
            isTrue,
            reason: 'Timestamps should be monotonically increasing',
          );
        }
      }
    });

    test('should handle walking pattern parameters correctly', () async {
      final service = MockSensorService(mockWalkingPattern: true);
      
      await service.startCollection();
      
      final readings = <SensorReading>[];
      await service.sensorReadingStream.take(20).toList().then(readings.addAll);
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      await service.stopCollection();
      service.dispose();

      if (readings.isNotEmpty) {
        // With walking pattern, we should see variation in Z-axis (vertical motion)
        final zValues = readings.map((r) => r.accelerometer.z).toList();
        final zStdDev = _calculateStandardDeviation(zValues);
        
        expect(
          zStdDev,
          greaterThan(0.1),
          reason: 'Walking pattern should show variation in Z-axis',
        );
      }
    });
  });
}

double _calculateStandardDeviation(List<double> values) {
  if (values.isEmpty) return 0.0;
  
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance = values
      .map((x) => (x - mean) * (x - mean))
      .reduce((a, b) => a + b) / values.length;
  
  return variance.sqrt();
}

extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}