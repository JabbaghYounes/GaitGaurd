import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../lib/features/gait/logic/gait_collection_cubit.dart';
import '../../../lib/core/services/sensor_service.dart';
import '../../../lib/data/models/sensor_reading.dart';
import '../../../lib/data/models/accelerometer_data.dart';
import '../../../lib/data/models/gyroscope_data.dart';
import '../../../lib/core/services/mock_sensor_service.dart';

class MockSensorService extends Mock implements SensorService {
  bool _isCollecting = false;
  double _samplingRate = 50.0;
  final StreamController<AccelerometerData> _accelController = StreamController.broadcast();
  final StreamController<GyroscopeData> _gyroController = StreamController.broadcast();
  final StreamController<SensorReading> _readingController = StreamController.broadcast();

  @override
  Stream<AccelerometerData> get accelerometerStream => _accelController.stream;

  @override
  Stream<GyroscopeData> get gyroscopeStream => _gyroController.stream;

  @override
  Stream<SensorReading> get sensorReadingStream => _readingController.stream;

  @override
  bool get isCollecting => _isCollecting;

  @override
  double get samplingRate => _samplingRate;

  @override
  Future<bool> isAccelerometerAvailable() async => true;

  @override
  Future<bool> isGyroscopeAvailable() async => true;

  @override
  Future<AccelerometerData?> getCurrentAccelerometerReading() async {
    return AccelerometerData(x: 0, y: 0, z: 9.8, timestamp: DateTime.now());
  }

  @override
  Future<GyroscopeData?> getCurrentGyroscopeReading() async {
    return GyroscopeData(x: 0, y: 0, z: 0, timestamp: DateTime.now());
  }

  @override
  Future<SensorReading?> getCurrentSensorReading() async {
    final timestamp = DateTime.now();
    return SensorReading(
      accelerometer: AccelerometerData(x: 0, y: 0, z: 9.8, timestamp: timestamp),
      gyroscope: GyroscopeData(x: 0, y: 0, z: 0, timestamp: timestamp),
    );
  }

  @override
  Future<void> startCollection() async {
    _isCollecting = true;
  }

  @override
  Future<void> stopCollection() async {
    _isCollecting = false;
  }

  @override
  Future<void> setSamplingRate(double rate) async {
    if (rate <= 0 || rate > 1000) {
      throw SensorException('Sampling rate must be between 0 and 1000 Hz');
    }
    _samplingRate = rate;
  }

  @override
  Future<Map<String, dynamic>> getSensorInfo() async {
    return {
      'accelerometer': {'available': true},
      'gyroscope': {'available': true},
      'sampling': {
        'isCollecting': _isCollecting,
        'samplingRate': _samplingRate,
      },
    };
  }

  // Test helper methods
  void simulateSensorReading(SensorReading reading) {
    _readingController.add(reading);
  }

  void simulateError(String error) {
    _accelController.addError(SensorException(error));
    _gyroController.addError(SensorException(error));
    _readingController.addError(SensorException(error));
  }

  void dispose() {
    _accelController.close();
    _gyroController.close();
    _readingController.close();
  }
}

void main() {
  group('GaitCollectionCubit Tests', () {
    late MockSensorService mockService;

    setUp(() {
      mockService = MockSensorService();
    });

    tearDown(() {
      mockService.dispose();
    });

    test('initial state is GaitCollectionInitial', () {
      final cubit = GaitCollectionCubit(mockService);
      expect(cubit.state, isA<GaitCollectionInitial>());
      cubit.close();
    });

    test('initialize should emit ready state when sensors are available', () async {
      final cubit = GaitCollectionCubit(mockService);
      
      await cubit.initialize();
      
      expect(cubit.state, isA<GaitCollectionReady>());
      final readyState = cubit.state as GaitCollectionReady;
      expect(readyState.sensorAvailability.allSensorsAvailable, isTrue);
      expect(readyState.samplingRate, equals(50.0));
      
      cubit.close();
    });

    test('initialize should emit error state when sensors are not available', () async {
      final unavailableService = MockUnavailableSensorService();
      final cubit = GaitCollectionCubit(unavailableService);
      
      await cubit.initialize();
      
      expect(cubit.state, isA<GaitCollectionError>());
      
      cubit.close();
    });

    test('startCollection should emit collecting state', () async {
      final cubit = GaitCollectionCubit(mockService);
      await cubit.initialize();
      
      await cubit.startCollection();
      
      expect(cubit.state, isA<GaitCollectionCollecting>());
      final collectingState = cubit.state as GaitCollectionCollecting;
      expect(collectingState.readingCount, equals(0));
      expect(collectingState.duration, equals(Duration.zero));
      
      await cubit.stopCollection();
      cubit.close();
    });

    test('stopCollection should emit stopped state with data', () async {
      final cubit = GaitCollectionCubit(mockService);
      await cubit.initialize();
      
      await cubit.startCollection();
      
      // Simulate some sensor readings
      final timestamp = DateTime.now();
      mockService.simulateSensorReading(SensorReading(
        accelerometer: AccelerometerData(x: 1, y: 2, z: 3, timestamp: timestamp),
        gyroscope: GyroscopeData(x: 0.1, y: 0.2, z: 0.3, timestamp: timestamp),
      ));
      
      // Wait a bit for processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      await cubit.stopCollection();
      
      expect(cubit.state, isA<GaitCollectionStopped>());
      final stoppedState = cubit.state as GaitCollectionStopped;
      expect(stoppedState.collectedData, isNotEmpty);
      expect(stoppedState.statistics['readingCount'], greaterThan(0));
      
      cubit.close();
    });

    test('setSamplingRate should update sampling rate', () async {
      final cubit = GaitCollectionCubit(mockService);
      await cubit.initialize();
      
      await cubit.setSamplingRate(100.0);
      
      expect(cubit.state, isA<GaitCollectionReady>());
      final readyState = cubit.state as GaitCollectionReady;
      expect(readyState.samplingRate, equals(100.0));
      
      cubit.close();
    });

    test('setSamplingRate should handle invalid rates', () async {
      final cubit = GaitCollectionCubit(mockService);
      await cubit.initialize();
      
      await cubit.setSamplingRate(-1.0);
      
      expect(cubit.state, isA<GaitCollectionError>());
      
      cubit.close();
    });

    test('clearData should return to ready state after stopping', () async {
      final cubit = GaitCollectionCubit(mockService);
      await cubit.initialize();
      
      await cubit.startCollection();
      await cubit.stopCollection();
      await cubit.clearData();
      
      expect(cubit.state, isA<GaitCollectionReady>());
      
      cubit.close();
    });

    test('collection should handle sensor errors', () async {
      final cubit = GaitCollectionCubit(mockService);
      await cubit.initialize();
      
      await cubit.startCollection();
      mockService.simulateError('Test sensor error');
      
      // Wait for error processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(cubit.state, isA<GaitCollectionError>());
      
      cubit.close();
    });

    test('sensor readings should be buffered correctly', () async {
      final cubit = GaitCollectionCubit(mockService);
      await cubit.initialize();
      
      await cubit.startCollection();
      
      final timestamp = DateTime.now();
      mockService.simulateSensorReading(SensorReading(
        accelerometer: AccelerometerData(x: 1, y: 2, z: 3, timestamp: timestamp),
        gyroscope: GyroscopeData(x: 0.1, y: 0.2, z: 0.3, timestamp: timestamp),
      ));
      
      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 50));
      
      final collectingState = cubit.state as GaitCollectionCollecting;
      expect(collectingState.buffer.size, greaterThan(0));
      
      await cubit.stopCollection();
      cubit.close();
    });
  });

  group('SensorData Models Tests', () {
    test('AccelerometerData should calculate magnitude correctly', () {
      final data = AccelerometerData(
        x: 3.0,
        y: 4.0,
        z: 0.0,
        timestamp: DateTime.now(),
      );
      
      expect(data.magnitude, equals(25.0)); // 3² + 4² + 0² = 25
    });

    test('AccelerometerData copyWith should work correctly', () {
      final original = AccelerometerData(
        x: 1.0,
        y: 2.0,
        z: 3.0,
        timestamp: DateTime.now(),
      );
      
      final copied = original.copyWith(x: 5.0);
      
      expect(copied.x, equals(5.0));
      expect(copied.y, equals(original.y));
      expect(copied.z, equals(original.z));
      expect(copied.timestamp, equals(original.timestamp));
    });

    test('AccelerometerData serialization should work', () {
      final original = AccelerometerData(
        x: 1.0,
        y: 2.0,
        z: 3.0,
        timestamp: DateTime(2023, 1, 1),
      );
      
      final json = original.toJson();
      final restored = AccelerometerData.fromJson(json);
      
      expect(restored.x, equals(original.x));
      expect(restored.y, equals(original.y));
      expect(restored.z, equals(original.z));
      expect(restored.timestamp, equals(original.timestamp));
    });

    test('GyroscopeData should calculate magnitude correctly', () {
      final data = GyroscopeData(
        x: 1.0,
        y: 1.0,
        z: 1.0,
        timestamp: DateTime.now(),
      );
      
      expect(data.magnitude, equals(3.0)); // 1² + 1² + 1² = 3
    });

    test('GyroscopeData toDegreesPerSecond should convert correctly', () {
      final original = GyroscopeData(
        x: 3.14159265359, // π radians
        y: 0.0,
        z: 0.0,
        timestamp: DateTime.now(),
      );
      
      final converted = original.toDegreesPerSecond;
      expect(converted.x, closeTo(180.0, 0.1));
    });

    test('SensorReading should check timestamp synchronization', () {
      final timestamp = DateTime.now();
      final synchronized = SensorReading(
        accelerometer: AccelerometerData(
          x: 1, y: 2, z: 3, timestamp: timestamp
        ),
        gyroscope: GyroscopeData(
          x: 0.1, y: 0.2, z: 0.3, timestamp: timestamp.add(const Duration(milliseconds: 30))
        ),
      );
      
      expect(synchronized.isTimestampsSynchronized, isTrue);
      
      final unsynchronized = SensorReading(
        accelerometer: AccelerometerData(
          x: 1, y: 2, z: 3, timestamp: timestamp
        ),
        gyroscope: GyroscopeData(
          x: 0.1, y: 0.2, z: 0.3, timestamp: timestamp.add(const Duration(milliseconds: 100))
        ),
      );
      
      expect(unsynchronized.isTimestampsSynchronized, isFalse);
    });

    test('SensorReading serialization should work', () {
      final timestamp = DateTime.now();
      final original = SensorReading(
        id: 'test-id',
        accelerometer: AccelerometerData(x: 1, y: 2, z: 3, timestamp: timestamp),
        gyroscope: GyroscopeData(x: 0.1, y: 0.2, z: 0.3, timestamp: timestamp),
      );
      
      final json = original.toJson();
      final restored = SensorReading.fromJson(json);
      
      expect(restored.id, equals(original.id));
      expect(restored.accelerometer.x, equals(original.accelerometer.x));
      expect(restored.gyroscope.x, equals(original.gyroscope.x));
    });
  });

  group('SensorBuffer Tests', () {
    test('SensorBuffer should add readings correctly', () {
      final buffer = SensorBuffer();
      final reading = _createTestReading();
      
      buffer.addReading(reading);
      
      expect(buffer.size, equals(1));
      expect(buffer.readings.first, equals(reading));
    });

    test('SensorBuffer should enforce max size', () {
      final buffer = SensorBuffer(maxSize: 2);
      final reading1 = _createTestReading();
      final reading2 = _createTestReading();
      final reading3 = _createTestReading();
      
      buffer.addReading(reading1);
      buffer.addReading(reading2);
      buffer.addReading(reading3);
      
      expect(buffer.size, equals(2));
      expect(buffer.readings, isNot(contains(reading1)));
      expect(buffer.readings, contains(reading2));
      expect(buffer.readings, contains(reading3));
    });

    test('SensorBuffer should get readings in time range', () {
      final buffer = SensorBuffer();
      final now = DateTime.now();
      final reading1 = _createTestReading(now.subtract(const Duration(seconds: 5)));
      final reading2 = _createTestReading(now.subtract(const Duration(seconds: 3)));
      final reading3 = _createTestReading(now.subtract(const Duration(seconds: 1)));
      
      buffer.addReadings([reading1, reading2, reading3]);
      
      final rangeReadings = buffer.getReadingsInRange(
        now.subtract(const Duration(seconds: 4)),
        now,
      );
      
      expect(rangeReadings, hasLength(2));
      expect(rangeReadings, contains(reading2));
      expect(rangeReadings, contains(reading3));
    });

    test('SensorBuffer should provide statistics', () {
      final buffer = SensorBuffer();
      final now = DateTime.now();
      final reading1 = _createTestReading(now.subtract(const Duration(seconds: 2)));
      final reading2 = _createTestReading(now);
      
      buffer.addReadings([reading1, reading2]);
      
      final stats = buffer.statistics;
      expect(stats['count'], equals(2));
      expect(stats['duration'], equals(const Duration(seconds: 2)));
      expect(stats['isSynchronized'], isTrue);
    });

    test('SensorBuffer should clear correctly', () {
      final buffer = SensorBuffer();
      buffer.addReading(_createTestReading());
      
      buffer.clear();
      
      expect(buffer.isEmpty, isTrue);
      expect(buffer.size, equals(0));
    });
  });
}

SensorReading _createTestReading([DateTime? timestamp]) {
  final ts = timestamp ?? DateTime.now();
  return SensorReading(
    accelerometer: AccelerometerData(x: 1, y: 2, z: 3, timestamp: ts),
    gyroscope: GyroscopeData(x: 0.1, y: 0.2, z: 0.3, timestamp: ts),
  );
}

class MockUnavailableSensorService implements SensorService {
  @override
  Stream<AccelerometerData> get accelerometerStream => Stream.empty();

  @override
  Stream<GyroscopeData> get gyroscopeStream => Stream.empty();

  @override
  Stream<SensorReading> get sensorReadingStream => Stream.empty();

  @override
  Future<bool> isAccelerometerAvailable() async => false;

  @override
  Future<bool> isGyroscopeAvailable() async => false;

  @override
  Future<AccelerometerData?> getCurrentAccelerometerReading() async => null;

  @override
  Future<GyroscopeData?> getCurrentGyroscopeReading() async => null;

  @override
  Future<SensorReading?> getCurrentSensorReading() async => null;

  @override
  Future<void> startCollection() async {}

  @override
  Future<void> stopCollection() async {}

  @override
  bool get isCollecting => false;

  @override
  double get samplingRate => 50.0;

  @override
  Future<void> setSamplingRate(double rate) async {}

  @override
  Future<Map<String, dynamic>> getSensorInfo() async => {};
}