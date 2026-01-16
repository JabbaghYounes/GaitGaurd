import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../lib/data/models/calibration_session.dart';
import '../../../lib/data/models/sensor_reading.dart';
import '../../../lib/data/models/accelerometer_data.dart';
import '../../../lib/data/models/gyroscope_data.dart';
import '../../../lib/data/repositories/calibration_repository.dart';
import '../../../lib/data/datasources/local/calibration_local_data_source.dart';
import '../../../lib/core/services/database_service.dart';

void main() {
  group('CalibrationSession Model Tests', () {
    test('should create calibration session correctly', () {
      const session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      expect(session.userId, equals(1));
      expect(session.type, equals(CalibrationType.standard));
      expect(session.status, equals(CalibrationStatus.pending));
      expect(session.expectedDuration, equals(const Duration(minutes: 2)));
    });

    test('should calculate progress correctly', () {
      final now = DateTime.now();
      final session = CalibrationSession(
        userId: 1,
        type: CalibrationType.fast,
        status: CalibrationStatus.inProgress,
        startTime: now.subtract(const Duration(seconds: 15)),
        expectedDuration: const Duration(seconds: 30),
      );

      expect(session.progress, equals(0.5));
      expect(session.currentDuration.inSeconds, equals(15));
    });

    test('should handle completion correctly', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      final completed = session.complete(qualityScore: 0.85);

      expect(completed.status, equals(CalibrationStatus.completed));
      expect(completed.qualityScore, equals(0.85));
      expect(completed.quality, equals(CalibrationQuality.good));
      expect(completed.endTime, isNotNull);
    });

    test('should calculate quality rating correctly', () {
      final excellent = CalibrationSession.create(userId: 1, type: CalibrationType.fast)
          .copyWith(qualityScore: 0.95);
      final good = CalibrationSession.create(userId: 1, type: CalibrationType.fast)
          .copyWith(qualityScore: 0.75);
      final fair = CalibrationSession.create(userId: 1, type: CalibrationType.fast)
          .copyWith(qualityScore: 0.6);
      final poor = CalibrationSession.create(userId: 1, type: CalibrationType.fast)
          .copyWith(qualityScore: 0.3);

      expect(excellent.quality, equals(CalibrationQuality.excellent));
      expect(good.quality, equals(CalibrationQuality.good));
      expect(fair.quality, equals(CalibrationQuality.fair));
      expect(poor.quality, equals(CalibrationQuality.poor));
    });

    test('should serialize and deserialize correctly', () {
      final original = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      final json = original.toJson();
      final restored = CalibrationSession.fromJson(json);

      expect(restored.userId, equals(original.userId));
      expect(restored.type, equals(original.type));
      expect(restored.status, equals(original.status));
    });

    test('should convert to and from database map', () {
      final original = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      final map = original.toMap();
      final restored = CalibrationSession.fromMap(map);

      expect(restored.userId, equals(original.userId));
      expect(restored.type, equals(original.type));
      expect(restored.status, equals(original.status));
    });
  });

  group('CalibrationRepository Tests', () {
    late DatabaseService databaseService;
    late CalibrationRepositoryImpl repository;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      databaseService = DatabaseService();
      final db = await databaseService.database;
      
      // Create test user
      await db.insert('users', {
        'email': 'test@example.com',
        'password_hash': 'test_hash',
        'password_salt': 'test_salt',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      repository = CalibrationRepositoryImpl(databaseService);
    });

    tearDown(() async {
      final db = await databaseService.database;
      await db.close();
    });

    test('should create and retrieve calibration session', () async {
      const session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      final created = await repository.createCalibrationSession(session);
      expect(created.id, isNotNull);

      final retrieved = await repository.getCalibrationSession(created.id!, 1);
      expect(retrieved, isNotNull);
      expect(retrieved!.userId, equals(1));
      expect(retrieved.type, equals(CalibrationType.fast));
    });

    test('should save and retrieve sensor readings', () async {
      const session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      final createdSession = await repository.createCalibrationSession(session);
      
      final readings = [
        SensorReading(
          accelerometer: AccelerometerData(
            x: 1.0, y: 2.0, z: 3.0,
            timestamp: DateTime.now(),
          ),
          gyroscope: GyroscopeData(
            x: 0.1, y: 0.2, z: 0.3,
            timestamp: DateTime.now(),
          ),
        ),
        SensorReading(
          accelerometer: AccelerometerData(
            x: 1.1, y: 2.1, z: 3.1,
            timestamp: DateTime.now(),
          ),
          gyroscope: GyroscopeData(
            x: 0.11, y: 0.21, z: 0.31,
            timestamp: DateTime.now(),
          ),
        ),
      ];

      await repository.saveCalibrationReadings(createdSession.id!, readings);

      final retrievedReadings = await repository.getCalibrationReadings(createdSession.id!);
      expect(retrievedReadings.length, equals(2));
      
      final first = retrievedReadings.first;
      expect(first.accelerometer.x, equals(1.0));
      expect(first.gyroscope.x, equals(0.1));
    });

    test('should get user calibration history', () async {
      // Create multiple sessions
      for (final type in CalibrationType.values) {
        final session = CalibrationSession.create(userId: 1, type: type);
        await repository.createCalibrationSession(session);
      }

      final history = await repository.getCalibrationSessions(1);
      expect(history.length, equals(CalibrationType.values.length));
    });

    test('should delete calibration session', () async {
      const session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      final created = await repository.createCalibrationSession(session);
      
      // Verify it exists
      final exists = await repository.getCalibrationSession(created.id!, 1);
      expect(exists, isNotNull);

      // Delete it
      await repository.deleteCalibrationSession(created.id!, 1);

      // Verify it's gone
      final deleted = await repository.getCalibrationSession(created.id!, 1);
      expect(deleted, isNull);
    });

    test('should get calibration statistics', () async {
      // Create sessions with different statuses
      final completedSession = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      ).complete(qualityScore: 0.8);
      
      final failedSession = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      ).fail('Test failure');

      await repository.createCalibrationSession(completedSession);
      await repository.createCalibrationSession(failedSession);

      final stats = await repository.getCalibrationStatistics(1);
      
      expect(stats['totalSessions'], equals(2));
      expect(stats['completedSessions'], equals(1));
      expect(stats['failedSessions'], equals(1));
      expect(stats['averageQualityScore'], equals(0.8));
    });

    test('should get latest successful calibration', () async {
      // Create sessions with different times
      final firstSession = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      ).complete(qualityScore: 0.7);
      
      final secondSession = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      ).complete(qualityScore: 0.8);

      await repository.createCalibrationSession(firstSession);
      await Future.delayed(const Duration(milliseconds: 100));
      await repository.createCalibrationSession(secondSession);

      final latest = await repository.getLatestSuccessfulCalibration(1);
      expect(latest, isNotNull);
      expect(latest!.type, equals(CalibrationType.standard));
    });
  });

  group('Calibration Type Enum Tests', () {
    test('should have correct display names and durations', () {
      expect(CalibrationType.fast.displayName, equals('Fast'));
      expect(CalibrationType.fast.duration, equals(const Duration(seconds: 30)));
      
      expect(CalibrationType.standard.displayName, equals('Standard'));
      expect(CalibrationType.standard.duration, equals(const Duration(minutes: 2)));
      
      expect(CalibrationType.extended.displayName, equals('Extended'));
      expect(CalibrationType.extended.duration, equals(const Duration(minutes: 5)));
    });

    test('should have all required types', () {
      final types = CalibrationType.values;
      expect(types.length, equals(3));
      expect(types, contains(CalibrationType.fast));
      expect(types, contains(CalibrationType.standard));
      expect(types, contains(CalibrationType.extended));
    });
  });

  group('Calibration Status Enum Tests', () {
    test('should have correct display names', () {
      expect(CalibrationStatus.pending.displayName, equals('Pending'));
      expect(CalibrationStatus.inProgress.displayName, equals('In Progress'));
      expect(CalibrationStatus.completed.displayName, equals('Completed'));
      expect(CalibrationStatus.failed.displayName, equals('Failed'));
      expect(CalibrationStatus.cancelled.displayName, equals('Cancelled'));
    });
  });

  group('Calibration Quality Enum Tests', () {
    test('should have correct thresholds', () {
      expect(CalibrationQuality.poor.threshold, equals(0.0));
      expect(CalibrationQuality.fair.threshold, equals(0.5));
      expect(CalibrationQuality.good.threshold, equals(0.7));
      expect(CalibrationQuality.excellent.threshold, equals(0.9));
    });

    test('should have correct display names', () {
      expect(CalibrationQuality.poor.displayName, equals('Poor'));
      expect(CalibrationQuality.fair.displayName, equals('Fair'));
      expect(CalibrationQuality.good.displayName, equals('Good'));
      expect(CalibrationQuality.excellent.displayName, equals('Excellent'));
    });
  });

  group('Sensor Reading Integration Tests', () {
    test('should handle large numbers of readings efficiently', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      // Add many readings
      var currentSession = session;
      for (int i = 0; i < 1000; i++) {
        final reading = SensorReading(
          accelerometer: AccelerometerData(
            x: i * 0.001,
            y: i * 0.002,
            z: 9.8 + (i % 10) * 0.1,
            timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
          ),
          gyroscope: GyroscopeData(
            x: (i % 100) * 0.01,
            y: (i % 100) * 0.02,
            z: (i % 100) * 0.03,
            timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
          ),
        );
        currentSession = currentSession.addReading(reading);
      }

      expect(currentSession.readingCount, equals(1000));
      expect(currentSession.averageSamplingRate, greaterThan(0));
    });

    test('should calculate average sampling rate correctly', () {
      final now = DateTime.now();
      final readings = <SensorReading>[];
      
      // Create readings at 50Hz (20ms intervals)
      for (int i = 0; i < 100; i++) {
        readings.add(SensorReading(
          accelerometer: AccelerometerData(
            x: 0, y: 0, z: 9.8,
            timestamp: now.add(Duration(milliseconds: i * 20)),
          ),
          gyroscope: GyroscopeData(
            x: 0, y: 0, z: 0,
            timestamp: now.add(Duration(milliseconds: i * 20)),
          ),
        ));
      }

      final session = CalibrationSession(
        userId: 1,
        type: CalibrationType.fast,
        status: CalibrationStatus.inProgress,
        startTime: now,
        endTime: now.add(const Duration(seconds: 2)), // 2 seconds for 100 readings at 50Hz
        collectedReadings: readings,
      );

      final expectedRate = 100.0 / 2.0; // 50Hz
      expect(session.averageSamplingRate, closeTo(expectedRate, 5.0));
    });

    test('should handle timestamp synchronization correctly', () {
      final now = DateTime.now();
      
      // Synchronized reading (same timestamp)
      final synchronized = SensorReading(
        accelerometer: AccelerometerData(
          x: 1, y: 2, z: 3,
          timestamp: now,
        ),
        gyroscope: GyroscopeData(
          x: 0.1, y: 0.2, z: 0.3,
          timestamp: now,
        ),
      );

      // Unsynchronized reading (different timestamps)
      final unsynchronized = SensorReading(
        accelerometer: AccelerometerData(
          x: 1, y: 2, z: 3,
          timestamp: now,
        ),
        gyroscope: GyroscopeData(
          x: 0.1, y: 0.2, z: 0.3,
          timestamp: now.add(const Duration(milliseconds: 100)),
        ),
      );

      expect(synchronized.isTimestampsSynchronized, isTrue);
      expect(unsynchronized.isTimestampsSynchronized, isFalse);
    });
  });
}

extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}