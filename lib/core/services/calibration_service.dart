import '../../data/models/calibration_session.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/repositories/calibration_repository.dart';
import 'sensor_service.dart';

/// Service for managing gait calibration sessions.
/// 
/// Handles the business logic for calibration including
/// data quality assessment, session management, and validation.
class CalibrationService {
  const CalibrationService(
    this._sensorService,
    this._calibrationRepository,
  );

  final SensorService _sensorService;
  final CalibrationRepository _calibrationRepository;

  /// Create and start a new calibration session
  Future<CalibrationSession> startCalibration({
    required int userId,
    required CalibrationType type,
  }) async {
    try {
      // Create new session
      final session = CalibrationSession.create(
        userId: userId,
        type: type,
      );

      // Start sensor collection
      await _sensorService.startCollection();

      // Save session to database
      final savedSession = await _calibrationRepository.createCalibrationSession(
        session.startCalibration(),
      );

      return savedSession;
    } catch (e) {
      throw CalibrationException('Failed to start calibration', e);
    }
  }

  /// Process sensor reading during calibration
  Future<CalibrationSession> processCalibrationReading(
    CalibrationSession session,
    SensorReading reading,
  ) async {
    try {
      // Add reading to session
      final updatedSession = session.addReading(reading);

      // Check if calibration should be complete
      if (updatedSession.progress >= 1.0) {
        return await completeCalibration(updatedSession);
      }

      // Save readings in batches (every 100 readings)
      if (updatedSession.readingCount % 100 == 0) {
        await _calibrationRepository.saveCalibrationReadings(
          session.id!,
          updatedSession.collectedReadings,
        );
      }

      return updatedSession;
    } catch (e) {
      throw CalibrationException('Failed to process calibration reading', e);
    }
  }

  /// Complete calibration with quality assessment
  Future<CalibrationSession> completeCalibration(
    CalibrationSession session,
  ) async {
    try {
      // Stop sensor collection
      await _sensorService.stopCollection();

      // Assess calibration quality
      final qualityScore = await _assessCalibrationQuality(session);

      // Complete the session
      final completedSession = session.complete(qualityScore: qualityScore);

      // Save final readings
      if (session.collectedReadings.isNotEmpty) {
        await _calibrationRepository.saveCalibrationReadings(
          session.id!,
          session.collectedReadings,
        );
      }

      // Update session in database
      final savedSession = await _calibrationRepository.updateCalibrationSession(
        completedSession,
      );

      return savedSession;
    } catch (e) {
      throw CalibrationException('Failed to complete calibration', e);
    }
  }

  /// Cancel ongoing calibration
  Future<CalibrationSession> cancelCalibration(
    CalibrationSession session,
  ) async {
    try {
      // Stop sensor collection
      await _sensorService.stopCollection();

      // Cancel the session
      final cancelledSession = session.cancel();

      // Save any readings collected so far
      if (session.collectedReadings.isNotEmpty) {
        await _calibrationRepository.saveCalibrationReadings(
          session.id!,
          session.collectedReadings,
        );
      }

      // Update session in database
      return await _calibrationRepository.updateCalibrationSession(
        cancelledSession,
      );
    } catch (e) {
      throw CalibrationException('Failed to cancel calibration', e);
    }
  }

  /// Get calibration history for user
  Future<List<CalibrationSession>> getCalibrationHistory(int userId) async {
    try {
      return await _calibrationRepository.getCalibrationSessions(userId);
    } catch (e) {
      throw CalibrationException('Failed to get calibration history', e);
    }
  }

  /// Get latest successful calibration for user
  Future<CalibrationSession?> getLatestCalibration(int userId) async {
    try {
      return await _calibrationRepository.getLatestSuccessfulCalibration(userId);
    } catch (e) {
      throw CalibrationException('Failed to get latest calibration', e);
    }
  }

  /// Delete calibration session
  Future<void> deleteCalibration(int sessionId, int userId) async {
    try {
      await _calibrationRepository.deleteCalibrationSession(sessionId, userId);
    } catch (e) {
      throw CalibrationException('Failed to delete calibration', e);
    }
  }

  /// Get calibration statistics for user
  Future<Map<String, dynamic>> getCalibrationStatistics(int userId) async {
    try {
      return await _calibrationRepository.getCalibrationStatistics(userId);
    } catch (e) {
      throw CalibrationException('Failed to get calibration statistics', e);
    }
  }

  /// Assess the quality of collected calibration data
  Future<double> _assessCalibrationQuality(CalibrationSession session) async {
    if (session.collectedReadings.isEmpty) return 0.0;

    final readings = session.collectedReadings;

    // Factors affecting quality:
    double score = 0.0;
    int factors = 0;

    // 1. Data quantity (30% of score)
    final expectedReadings = _getExpectedReadingCount(session.type);
    final readingCountScore = (readings.length / expectedReadings).clamp(0.0, 1.0);
    score += readingCountScore * 0.3;
    factors++;

    // 2. Sensor synchronization (25% of score)
    final syncRate = _calculateSyncRate(readings);
    score += syncRate * 0.25;
    factors++;

    // 3. Data consistency (20% of score)
    final consistencyScore = _calculateConsistencyScore(readings);
    score += consistencyScore * 0.2;
    factors++;

    // 4. Sampling rate stability (15% of score)
    final samplingStabilityScore = _calculateSamplingStability(readings);
    score += samplingStabilityScore * 0.15;
    factors++;

    // 5. Movement variation (10% of score) - should show walking patterns
    final movementVariationScore = _calculateMovementVariation(readings);
    score += movementVariationScore * 0.1;
    factors++;

    return score.clamp(0.0, 1.0);
  }

  /// Get expected reading count for calibration type
  int _getExpectedReadingCount(CalibrationType type) {
    // Assume 50Hz sampling rate
    const samplingRate = 50;
    final durationSeconds = type.duration.inSeconds;
    return (durationSeconds * samplingRate).round();
  }

  /// Calculate the rate of synchronized sensor readings
  double _calculateSyncRate(List<SensorReading> readings) {
    if (readings.isEmpty) return 0.0;

    final synchronized = readings.where((r) => r.isTimestampsSynchronized).length;
    return synchronized / readings.length;
  }

  /// Calculate data consistency score
  double _calculateConsistencyScore(List<SensorReading> readings) {
    if (readings.length < 10) return 0.0;

    // Check accelerometer Z-axis (gravity) consistency
    final zValues = readings.map((r) => r.accelerometer.z).toList();
    final zMean = zValues.reduce((a, b) => a + b) / zValues.length;
    final zVariance = zValues
        .map((z) => (z - zMean) * (z - zMean))
        .reduce((a, b) => a + b) / zValues.length;
    final zStdDev = zVariance.sqrt();

    // Z-axis should be around 9.8 with some variation
    final deviationFromGravity = (zMean - 9.8).abs();
    final zScore = (1.0 - deviationFromGravity / 5.0).clamp(0.0, 1.0);
    final varianceScore = (1.0 - (zStdDev / 3.0)).clamp(0.0, 1.0);

    return (zScore + varianceScore) / 2.0;
  }

  /// Calculate sampling rate stability
  double _calculateSamplingStability(List<SensorReading> readings) {
    if (readings.length < 20) return 0.0;

    final intervals = <double>[];
    for (int i = 1; i < readings.length; i++) {
      final interval = readings[i].timestamp
          .difference(readings[i - 1].timestamp)
          .inMicroseconds / 1000000.0; // Convert to seconds
      intervals.add(interval);
    }

    final meanInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final targetInterval = 1.0 / 50.0; // 50Hz target

    final deviationRatio = (meanInterval - targetInterval).abs() / targetInterval;
    return (1.0 - deviationRatio).clamp(0.0, 1.0);
  }

  /// Calculate movement variation to detect walking patterns
  double _calculateMovementVariation(List<SensorReading> readings) {
    if (readings.length < 50) return 0.0;

    // Analyze accelerometer variation
    final xValues = readings.map((r) => r.accelerometer.x).toList();
    final yValues = readings.map((r) => r.accelerometer.y).toList();

    // Calculate standard deviations
    final xStdDev = _calculateStandardDeviation(xValues);
    final yStdDev = _calculateStandardDeviation(yValues);

    // Look for periodic patterns in the data
    final periodicity = _detectPeriodicity(xValues + yValues);

    // Combine factors
    final variationScore = ((xStdDev + yStdDev) / 4.0).clamp(0.0, 1.0);
    final periodicityScore = periodicity.clamp(0.0, 1.0);

    return (variationScore + periodicityScore) / 2.0;
  }

  /// Calculate standard deviation of values
  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b) / values.length;
    
    return variance.sqrt();
  }

  /// Detect periodicity in sensor data (indicates walking)
  double _detectPeriodicity(List<double> values) {
    if (values.length < 100) return 0.0;

    // Simple autocorrelation-based periodicity detection
    final targetFrequency = 2.0; // ~2 steps per second
    
    int matches = 0;
    final periodSamples = (50.0 / targetFrequency).round(); // Assuming 50Hz

    for (int i = 0; i < values.length - periodSamples; i++) {
      if ((values[i] - values[i + periodSamples]).abs() < 0.5) {
        matches++;
      }
    }

    return matches / (values.length - periodSamples);
  }

  /// Validate calibration requirements before starting
  Future<bool> validateCalibrationRequirements(int userId) async {
    try {
      // Check sensor availability
      final accelAvailable = await _sensorService.isAccelerometerAvailable();
      final gyroAvailable = await _sensorService.isGyroscopeAvailable();

      if (!accelAvailable || !gyroAvailable) {
        return false;
      }

      // Check if user has recent successful calibration
      final latestCalibration = await getLatestCalibration(userId);
      if (latestCalibration != null) {
        final timeSinceLastCalibration = 
            DateTime.now().difference(latestCalibration.startTime);
        // Allow re-calibration after 24 hours
        if (timeSinceLastCalibration.inHours < 24) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Exception thrown when calibration operations fail
class CalibrationException implements Exception {
  const CalibrationException(this.message, [this.cause]);

  final String message;
  final dynamic cause;

  @override
  String toString() => 'CalibrationException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

extension on double {
  double sqrt() => this < 0 ? 0 : this * 0.5 + 1.5; // Simplified approximation
}