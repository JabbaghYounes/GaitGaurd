import '../models/calibration_session.dart';
import '../models/sensor_reading.dart';

/// Repository interface for calibration session operations.
abstract class CalibrationRepository {
  /// Get all calibration sessions for a user
  Future<List<CalibrationSession>> getCalibrationSessions(int userId);

  /// Get a specific calibration session by ID
  Future<CalibrationSession?> getCalibrationSession(int sessionId, int userId);

  /// Create a new calibration session
  Future<CalibrationSession> createCalibrationSession(CalibrationSession session);

  /// Update an existing calibration session
  Future<CalibrationSession> updateCalibrationSession(CalibrationSession session);

  /// Save sensor readings for a calibration session
  Future<void> saveCalibrationReadings(int sessionId, List<SensorReading> readings);

  /// Get sensor readings for a calibration session
  Future<List<SensorReading>> getCalibrationReadings(int sessionId);

  /// Delete a calibration session and its readings
  Future<void> deleteCalibrationSession(int sessionId, int userId);

  /// Get the latest successful calibration for a user
  Future<CalibrationSession?> getLatestSuccessfulCalibration(int userId);

  /// Get calibration statistics for a user
  Future<Map<String, dynamic>> getCalibrationStatistics(int userId);
}