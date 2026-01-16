import '../../core/services/database_service.dart';
import '../models/gait_features.dart';

/// Repository for ML model metadata and recognition results
abstract class MLModelRepository {
  /// Save ML model information
  Future<int> saveModel({
    required int userId,
    required String modelType,
    required String modelVersion,
    String? modelPath,
    required bool isActive,
    double? accuracy,
    double? performance,
    Map<String, dynamic>? metadata,
  });

  /// Get active model for user
  Future<Map<String, dynamic>?> getActiveModel(int userId);

  /// Get all models for user
  Future<List<Map<String, dynamic>>> getModelsForUser(int userId);

  /// Set model as active
  Future<void> setModelAsActive(int modelId, int userId);

  /// Save recognition result
  Future<int> saveRecognitionResult({
    required int userId,
    required GaitFeatures features,
    required bool isMatch,
    required double confidence,
    required GaitPatternType patternType,
    int? modelId,
    Map<String, dynamic>? metadata,
  });

  /// Get recognition history for user
  Future<List<Map<String, dynamic>>> getRecognitionHistory(int userId, {int limit = 100});

  /// Save training data
  Future<int> saveTrainingData({
    required int userId,
    required int modelId,
    required GaitFeatures features,
  });

  /// Get training data for model
  Future<List<GaitFeatures>> getTrainingData(int modelId);

  /// Delete model and associated data
  Future<void> deleteModel(int modelId, int userId);

  /// Get model statistics
  Future<Map<String, dynamic>> getModelStatistics(int userId);
}

/// SQLite implementation of MLModelRepository
class MLModelRepositoryImpl implements MLModelRepository {
  const MLModelRepositoryImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<int> saveModel({
    required int userId,
    required String modelType,
    required String modelVersion,
    String? modelPath,
    required bool isActive,
    double? accuracy,
    double? performance,
    Map<String, dynamic>? metadata,
  }) async {
    final db = await _databaseService.database;
    
    // If this is the active model, deactivate others
    if (isActive) {
      await db.update(
        'ml_models',
        {'is_active': 0},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }

    final id = await db.insert('ml_models', {
      'user_id': userId,
      'model_type': modelType,
      'model_version': modelVersion,
      'model_path': modelPath,
      'is_active': isActive,
      'accuracy': accuracy,
      'performance': performance,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    return id;
  }

  @override
  Future<Map<String, dynamic>?> getActiveModel(int userId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'ml_models',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _decodeModelMap(maps.first);
  }

  @override
  Future<List<Map<String, dynamic>>> getModelsForUser(int userId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'ml_models',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );

    return maps.map(_decodeModelMap).toList();
  }

  @override
  Future<void> setModelAsActive(int modelId, int userId) async {
    final db = await _databaseService.database;
    
    await db.transaction((txn) async {
      // Deactivate all models for user
      await txn.update(
        'ml_models',
        {'is_active': 0},
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Activate specified model
      await txn.update(
        'ml_models',
        {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND user_id = ?',
        whereArgs: [modelId, userId],
      );
    });
  }

  @override
  Future<int> saveRecognitionResult({
    required int userId,
    required GaitFeatures features,
    required bool isMatch,
    required double confidence,
    required GaitPatternType patternType,
    int? modelId,
    Map<String, dynamic>? metadata,
  }) async {
    final db = await _databaseService.database;
    
    return await db.insert('recognition_results', {
      'user_id': userId,
      'model_id': modelId,
      'features': features.toJson(),
      'is_match': isMatch ? 1 : 0,
      'confidence': confidence,
      'pattern_type': patternType.name,
      'recognition_timestamp': DateTime.now().toIso8601String(),
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getRecognitionHistory(int userId, {int limit = 100}) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'recognition_results',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recognition_timestamp DESC',
      limit: limit,
    );

    return maps.map(_decodeResultMap).toList();
  }

  @override
  Future<int> saveTrainingData({
    required int userId,
    required int modelId,
    required GaitFeatures features,
  }) async {
    final db = await _databaseService.database;
    
    return await db.insert('training_data', {
      'user_id': userId,
      'model_id': modelId,
      'features': features.toJson(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<GaitFeatures>> getTrainingData(int modelId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'training_data',
      where: 'model_id = ?',
      whereArgs: [modelId],
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => GaitFeatures.fromJson(map['features'] as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> deleteModel(int modelId, int userId) async {
    final db = await _databaseService.database;
    
    await db.transaction((txn) async {
      // Delete training data
      await txn.delete(
        'training_data',
        where: 'model_id = ?',
        whereArgs: [modelId],
      );

      // Delete recognition results
      await txn.delete(
        'recognition_results',
        where: 'model_id = ?',
        whereArgs: [modelId],
      );

      // Delete model
      await txn.delete(
        'ml_models',
        where: 'id = ? AND user_id = ?',
        whereArgs: [modelId, userId],
      );
    });
  }

  @override
  Future<Map<String, dynamic>> getModelStatistics(int userId) async {
    final db = await _databaseService.database;
    
    // Get model statistics
    final modelStats = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_models,
        COUNT(CASE WHEN is_active = 1 THEN 1 END) as active_models,
        AVG(accuracy) as avg_accuracy,
        AVG(performance) as avg_performance,
        MAX(updated_at) as last_updated
      FROM ml_models 
      WHERE user_id = ?
    ''', [userId]);

    // Get recognition statistics
    final recognitionStats = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_recognitions,
        COUNT(CASE WHEN is_match = 1 THEN 1 END) as total_matches,
        AVG(confidence) as avg_confidence,
        MAX(recognition_timestamp) as last_recognition
      FROM recognition_results 
      WHERE user_id = ?
    ''', [userId]);

    final modelResult = modelStats.first;
    final recognitionResult = recognitionStats.first;

    return {
      'models': {
        'total': modelResult['total_models'] as int? ?? 0,
        'active': modelResult['active_models'] as int? ?? 0,
        'averageAccuracy': modelResult['avg_accuracy'] as double? ?? 0.0,
        'averagePerformance': modelResult['avg_performance'] as double? ?? 0.0,
        'lastUpdated': modelResult['last_updated'] != null
            ? DateTime.parse(modelResult['last_updated'] as String)
            : null,
      },
      'recognitions': {
        'total': recognitionResult['total_recognitions'] as int? ?? 0,
        'matches': recognitionResult['total_matches'] as int? ?? 0,
        'averageConfidence': recognitionResult['avg_confidence'] as double? ?? 0.0,
        'lastRecognition': recognitionResult['last_recognition'] != null
            ? DateTime.parse(recognitionResult['last_recognition'] as String)
            : null,
      },
      'successRate': (recognitionResult['total_recognitions'] as int? ?? 0) > 0
          ? (recognitionResult['total_matches'] as int? ?? 0) / (recognitionResult['total_recognitions'] as int)
          : 0.0,
    };
  }

  Map<String, dynamic> _decodeModelMap(Map<String, Object?> map) {
    return {
      'id': map['id'],
      'userId': map['user_id'],
      'modelType': map['model_type'],
      'modelVersion': map['model_version'],
      'modelPath': map['model_path'],
      'isActive': (map['is_active'] as int) == 1,
      'accuracy': map['accuracy'],
      'performance': map['performance'],
      'metadata': map['metadata'] != null
          ? _decodeMetadata(map['metadata'] as String)
          : null,
      'createdAt': map['created_at'],
      'updatedAt': map['updated_at'],
    };
  }

  Map<String, dynamic> _decodeResultMap(Map<String, Object?> map) {
    return {
      'id': map['id'],
      'userId': map['user_id'],
      'modelId': map['model_id'],
      'features': map['features'],
      'isMatch': (map['is_match'] as int) == 1,
      'confidence': map['confidence'],
      'patternType': map['pattern_type'],
      'recognitionTimestamp': map['recognition_timestamp'],
      'metadata': map['metadata'] != null
          ? _decodeMetadata(map['metadata'] as String)
          : null,
    };
  }

  // Helper methods for metadata encoding/decoding
  String _encodeMetadata(Map<String, dynamic> metadata) {
    // Simple JSON encoding - in production, use dart:convert
    return metadata.toString();
  }

  Map<String, dynamic> _decodeMetadata(String encoded) {
    // Simple JSON decoding - in production, use dart:convert
    // For now, return empty map as placeholder
    return {};
  }
}