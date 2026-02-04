import '../models/protected_app.dart';
import '../models/app_lock_session.dart';
import '../../core/services/database_service.dart';

/// Repository for app lock data access.
abstract class AppLockRepository {
  /// Get all protected apps for a user
  Future<List<ProtectedApp>> getProtectedApps(int userId);

  /// Get a specific protected app by package name
  Future<ProtectedApp?> getProtectedApp(int userId, String packageName);

  /// Save or update a protected app
  Future<ProtectedApp> saveProtectedApp(int userId, ProtectedApp app);

  /// Update app protection status
  Future<void> setAppProtected(int userId, String packageName, bool isProtected, {ProtectedApp? appInfo});

  /// Update app lock status
  Future<void> setAppLocked(int userId, String packageName, bool isLocked);

  /// Lock all protected apps for a user
  Future<void> lockAllProtectedApps(int userId);

  /// Unlock all apps for a user
  Future<void> unlockAllApps(int userId);

  /// Create a new lock session
  Future<AppLockSession> createLockSession(AppLockSession session);

  /// Update a lock session (e.g., when unlocked)
  Future<void> updateLockSession(AppLockSession session);

  /// Get active lock sessions for a user
  Future<List<AppLockSession>> getActiveLockSessions(int userId);

  /// Get lock session for a specific app
  Future<AppLockSession?> getActiveLockSession(int userId, String packageName);

  /// Get lock history for a user
  Future<List<AppLockSession>> getLockHistory(int userId, {int limit = 50});

  /// Get app lock statistics
  Future<Map<String, dynamic>> getAppLockStats(int userId);
}

/// SQLite implementation of AppLockRepository.
class AppLockRepositoryImpl implements AppLockRepository {
  const AppLockRepositoryImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<ProtectedApp>> getProtectedApps(int userId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'protected_apps',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'display_name ASC',
    );

    return maps.map((map) => ProtectedApp.fromMap(map)).toList();
  }

  @override
  Future<ProtectedApp?> getProtectedApp(int userId, String packageName) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'protected_apps',
      where: 'user_id = ? AND package_name = ?',
      whereArgs: [userId, packageName],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ProtectedApp.fromMap(maps.first);
  }

  @override
  Future<ProtectedApp> saveProtectedApp(int userId, ProtectedApp app) async {
    final db = await _databaseService.database;

    // Check if app already exists
    final existing = await getProtectedApp(userId, app.packageName);

    if (existing != null) {
      // Update existing
      await db.update(
        'protected_apps',
        {
          ...app.toMap(),
          'user_id': userId,
        },
        where: 'user_id = ? AND package_name = ?',
        whereArgs: [userId, app.packageName],
      );
      return app.copyWith(id: existing.id);
    } else {
      // Insert new
      final id = await db.insert('protected_apps', {
        ...app.toMap(),
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return app.copyWith(id: id);
    }
  }

  @override
  Future<void> setAppProtected(
      int userId, String packageName, bool isProtected, {ProtectedApp? appInfo}) async {
    final db = await _databaseService.database;

    // Check if app exists
    final existing = await getProtectedApp(userId, packageName);

    if (existing != null) {
      // Update existing app
      final updateData = <String, dynamic>{
        'is_protected': isProtected ? 1 : 0,
      };

      // Update icon if provided
      if (appInfo?.iconBase64 != null) {
        updateData['icon_base64'] = appInfo!.iconBase64;
        updateData['is_real_app'] = 1;
      }

      await db.update(
        'protected_apps',
        updateData,
        where: 'user_id = ? AND package_name = ?',
        whereArgs: [userId, packageName],
      );
    } else {
      // Get app info from provided appInfo, mock apps, or create minimal entry
      final ProtectedApp sourceApp;
      if (appInfo != null) {
        sourceApp = appInfo;
      } else {
        sourceApp = ProtectedApp.mockApps.firstWhere(
          (app) => app.packageName == packageName,
          orElse: () => ProtectedApp(
            packageName: packageName,
            displayName: packageName,
          ),
        );
      }

      await db.insert('protected_apps', {
        'user_id': userId,
        'package_name': packageName,
        'display_name': sourceApp.displayName,
        'icon_code_point': sourceApp.iconData.codePoint,
        'icon_base64': sourceApp.iconBase64,
        'is_protected': isProtected ? 1 : 0,
        'is_locked': 0,
        'lock_count': 0,
        'is_real_app': sourceApp.isRealApp ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<void> setAppLocked(
      int userId, String packageName, bool isLocked) async {
    final db = await _databaseService.database;

    await db.update(
      'protected_apps',
      {
        'is_locked': isLocked ? 1 : 0,
        if (!isLocked) 'last_unlock_time': DateTime.now().toIso8601String(),
        if (isLocked) 'lock_count': (await _getLockCount(userId, packageName)) + 1,
      },
      where: 'user_id = ? AND package_name = ?',
      whereArgs: [userId, packageName],
    );
  }

  Future<int> _getLockCount(int userId, String packageName) async {
    final app = await getProtectedApp(userId, packageName);
    return app?.lockCount ?? 0;
  }

  @override
  Future<void> lockAllProtectedApps(int userId) async {
    final db = await _databaseService.database;

    // Get all protected apps
    final protectedApps = await db.query(
      'protected_apps',
      where: 'user_id = ? AND is_protected = 1',
      whereArgs: [userId],
    );

    // Lock each one and create session
    for (final appMap in protectedApps) {
      final packageName = appMap['package_name'] as String;
      final currentLockCount = appMap['lock_count'] as int? ?? 0;

      await db.update(
        'protected_apps',
        {
          'is_locked': 1,
          'lock_count': currentLockCount + 1,
        },
        where: 'user_id = ? AND package_name = ?',
        whereArgs: [userId, packageName],
      );

      // Create lock session
      await createLockSession(AppLockSession.lock(
        userId: userId,
        packageName: packageName,
      ));
    }
  }

  @override
  Future<void> unlockAllApps(int userId) async {
    final db = await _databaseService.database;

    await db.update(
      'protected_apps',
      {
        'is_locked': 0,
        'last_unlock_time': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // Update all active sessions to unlocked
    await db.update(
      'app_lock_sessions',
      {
        'lock_status': AppLockStatus.unlocked.name,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ? AND lock_status = ?',
      whereArgs: [userId, AppLockStatus.locked.name],
    );
  }

  @override
  Future<AppLockSession> createLockSession(AppLockSession session) async {
    final db = await _databaseService.database;

    final id = await db.insert('app_lock_sessions', {
      ...session.toMap(),
      'created_at': DateTime.now().toIso8601String(),
    });

    return session.copyWith(id: id);
  }

  @override
  Future<void> updateLockSession(AppLockSession session) async {
    final db = await _databaseService.database;

    await db.update(
      'app_lock_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  @override
  Future<List<AppLockSession>> getActiveLockSessions(int userId) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'app_lock_sessions',
      where: 'user_id = ? AND lock_status IN (?, ?)',
      whereArgs: [userId, AppLockStatus.locked.name, AppLockStatus.authenticating.name],
      orderBy: 'locked_at DESC',
    );

    return maps.map((map) => AppLockSession.fromMap(map)).toList();
  }

  @override
  Future<AppLockSession?> getActiveLockSession(
      int userId, String packageName) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'app_lock_sessions',
      where: 'user_id = ? AND package_name = ? AND lock_status IN (?, ?)',
      whereArgs: [userId, packageName, AppLockStatus.locked.name, AppLockStatus.authenticating.name],
      orderBy: 'locked_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return AppLockSession.fromMap(maps.first);
  }

  @override
  Future<List<AppLockSession>> getLockHistory(int userId,
      {int limit = 50}) async {
    final db = await _databaseService.database;
    final maps = await db.query(
      'app_lock_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'locked_at DESC',
      limit: limit,
    );

    return maps.map((map) => AppLockSession.fromMap(map)).toList();
  }

  @override
  Future<Map<String, dynamic>> getAppLockStats(int userId) async {
    final db = await _databaseService.database;

    // Get protected apps count
    final protectedApps = await db.rawQuery('''
      SELECT COUNT(*) as count FROM protected_apps
      WHERE user_id = ? AND is_protected = 1
    ''', [userId]);

    // Get currently locked count
    final lockedApps = await db.rawQuery('''
      SELECT COUNT(*) as count FROM protected_apps
      WHERE user_id = ? AND is_locked = 1
    ''', [userId]);

    // Get total lock sessions
    final totalSessions = await db.rawQuery('''
      SELECT COUNT(*) as count FROM app_lock_sessions
      WHERE user_id = ?
    ''', [userId]);

    // Get successful unlocks
    final successfulUnlocks = await db.rawQuery('''
      SELECT COUNT(*) as count FROM app_lock_sessions
      WHERE user_id = ? AND lock_status = ?
    ''', [userId, AppLockStatus.unlocked.name]);

    // Get average unlock confidence
    final avgConfidence = await db.rawQuery('''
      SELECT AVG(unlock_confidence) as avg FROM app_lock_sessions
      WHERE user_id = ? AND unlock_confidence IS NOT NULL
    ''', [userId]);

    return {
      'protectedAppsCount': protectedApps.first['count'] as int? ?? 0,
      'lockedAppsCount': lockedApps.first['count'] as int? ?? 0,
      'totalLockSessions': totalSessions.first['count'] as int? ?? 0,
      'successfulUnlocks': successfulUnlocks.first['count'] as int? ?? 0,
      'averageUnlockConfidence': avgConfidence.first['avg'] as double? ?? 0.0,
    };
  }
}
