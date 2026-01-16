import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../../models/calibration_session.dart';
import '../../models/sensor_reading.dart';
import '../../models/accelerometer_data.dart';
import '../../models/gyroscope_data.dart';
import '../../repositories/calibration_repository.dart';

/// SQLite implementation of CalibrationRepository.
class CalibrationRepositoryImpl implements CalibrationRepository {
  const CalibrationRepositoryImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<CalibrationSession>> getCalibrationSessions(int userId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'calibration_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_time DESC',
    );

    final sessions = <CalibrationSession>[];
    for (final map in maps) {
      // Get readings count from database
      final readingCount = await _getReadingCount(map['id'] as int);
      
      final session = CalibrationSession.fromMap(map);
      
      // Update session with readings count
      sessions.add(session.copyWith(readingCount: readingCount));
    }

    return sessions;
  }

  @override
  Future<CalibrationSession?> getCalibrationSession(int sessionId, int userId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'calibration_sessions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [sessionId, userId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final readingCount = await _getReadingCount(sessionId);
    final readings = await getCalibrationReadings(sessionId);

    return CalibrationSession.fromMap(map).copyWith(
      readingCount: readingCount,
      collectedReadings: readings,
    );
  }

  @override
  Future<CalibrationSession> createCalibrationSession(CalibrationSession session) async {
    final db = await _databaseService.database;
    final id = await db.insert(
      'calibration_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return session.copyWith(id: id);
  }

  @override
  Future<CalibrationSession> updateCalibrationSession(CalibrationSession session) async {
    final db = await _databaseService.database;
    
    if (session.id == null) {
      throw ArgumentError('Session ID is required for updates');
    }

    await db.update(
      'calibration_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );

    return session;
  }

  @override
  Future<void> saveCalibrationReadings(int sessionId, List<SensorReading> readings) async {
    if (readings.isEmpty) return;

    final db = await _databaseService.database;
    final batch = db.batch();

    for (final reading in readings) {
      batch.insert(
        'calibration_readings',
        {
          'session_id': sessionId,
          'timestamp': reading.timestamp.toIso8601String(),
          'accel_x': reading.accelerometer.x,
          'accel_y': reading.accelerometer.y,
          'accel_z': reading.accelerometer.z,
          'gyro_x': reading.gyroscope.x,
          'gyro_y': reading.gyroscope.y,
          'gyro_z': reading.gyroscope.z,
          'is_synchronized': reading.isTimestampsSynchronized ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  @override
  Future<List<SensorReading>> getCalibrationReadings(int sessionId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'calibration_readings',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => SensorReading(
      accelerometer: AccelerometerData(
        x: map['accel_x'] as double,
        y: map['accel_y'] as double,
        z: map['accel_z'] as double,
        timestamp: DateTime.parse(map['timestamp'] as String),
      ),
      gyroscope: GyroscopeData(
        x: map['gyro_x'] as double,
        y: map['gyro_y'] as double,
        z: map['gyro_z'] as double,
        timestamp: DateTime.parse(map['timestamp'] as String),
      ),
    )).toList();
  }

  @override
  Future<void> deleteCalibrationSession(int sessionId, int userId) async {
    final db = await _databaseService.database;
    
    // Delete readings first (foreign key should handle this, but be explicit)
    await db.delete(
      'calibration_readings',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    
    // Delete session
    await db.delete(
      'calibration_sessions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [sessionId, userId],
    );
  }

  @override
  Future<CalibrationSession?> getLatestSuccessfulCalibration(int userId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'calibration_sessions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, CalibrationStatus.completed.name],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final readingCount = await _getReadingCount(map['id'] as int);
    final readings = await getCalibrationReadings(map['id'] as int);

    return CalibrationSession.fromMap(map).copyWith(
      readingCount: readingCount,
      collectedReadings: readings,
    );
  }

  @override
  Future<Map<String, dynamic>> getCalibrationStatistics(int userId) async {
    final db = await _databaseService.database;
    
    // Get session statistics
    final sessionStats = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_sessions,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_sessions,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_sessions,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_sessions,
        AVG(CASE WHEN status = 'completed' THEN quality_score END) as avg_quality_score,
        MIN(start_time) as first_calibration,
        MAX(start_time) as last_calibration
      FROM calibration_sessions 
      WHERE user_id = ?
    ''', [userId]);

    // Get reading statistics
    final readingStats = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_readings,
        AVG(session_id) as avg_readings_per_session
      FROM calibration_readings cr
      INNER JOIN calibration_sessions cs ON cr.session_id = cs.id
      WHERE cs.user_id = ?
    ''', [userId]);

    // Get type distribution
    final typeStats = await db.rawQuery('''
      SELECT 
        type,
        COUNT(*) as count
      FROM calibration_sessions 
      WHERE user_id = ?
      GROUP BY type
    ''', [userId]);

    final sessionResult = sessionStats.first;
    final readingResult = readingStats.first;

    return {
      'totalSessions': sessionResult['total_sessions'] as int? ?? 0,
      'completedSessions': sessionResult['completed_sessions'] as int? ?? 0,
      'failedSessions': sessionResult['failed_sessions'] as int? ?? 0,
      'cancelledSessions': sessionResult['cancelled_sessions'] as int? ?? 0,
      'averageQualityScore': sessionResult['avg_quality_score'] as double? ?? 0.0,
      'firstCalibration': sessionResult['first_calibration'] != null
          ? DateTime.parse(sessionResult['first_calibration'] as String)
          : null,
      'lastCalibration': sessionResult['last_calibration'] != null
          ? DateTime.parse(sessionResult['last_calibration'] as String)
          : null,
      'totalReadings': readingResult['total_readings'] as int? ?? 0,
      'averageReadingsPerSession': readingResult['avg_readings_per_session'] as double? ?? 0.0,
      'typeDistribution': {
        for (final stat in typeStats)
          stat['type']: stat['count'] as int,
      },
    };
  }

  /// Helper method to get reading count for a session
  Future<int> _getReadingCount(int sessionId) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM calibration_readings WHERE session_id = ?',
      [sessionId],
    );
    
    return result.first['count'] as int? ?? 0;
  }

  /// Get session readings in batches for performance
  Future<List<SensorReading>> getCalibrationReadingsBatched(
    int sessionId, {
    int batchSize = 1000,
    int offset = 0,
  }) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'calibration_readings',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
      limit: batchSize,
      offset: offset,
    );

    return maps.map((map) => SensorReading(
      accelerometer: AccelerometerData(
        x: map['accel_x'] as double,
        y: map['accel_y'] as double,
        z: map['accel_z'] as double,
        timestamp: DateTime.parse(map['timestamp'] as String),
      ),
      gyroscope: GyroscopeData(
        x: map['gyro_x'] as double,
        y: map['gyro_y'] as double,
        z: map['gyro_z'] as double,
        timestamp: DateTime.parse(map['timestamp'] as String),
      ),
    )).toList();
  }

  /// Clean up old calibration sessions (older than specified date)
  Future<void> cleanupOldCalibrations(int userId, DateTime cutoffDate) async {
    final db = await _databaseService.database;
    
    // Get sessions to delete
    final oldSessions = await db.query(
      'calibration_sessions',
      where: 'user_id = ? AND start_time < ?',
      whereArgs: [userId, cutoffDate.toIso8601String()],
      columns: ['id'],
    );

    if (oldSessions.isEmpty) return;

    // Delete readings first
    for (final session in oldSessions) {
      await db.delete(
        'calibration_readings',
        where: 'session_id = ?',
        whereArgs: [session['id']],
      );
    }

    // Delete sessions
    await db.delete(
      'calibration_sessions',
      where: 'user_id = ? AND start_time < ?',
      whereArgs: [userId, cutoffDate.toIso8601String()],
    );
  }
}