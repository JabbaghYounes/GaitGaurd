import 'package:sqflite/sqflite.dart';

import '../../../core/services/database_service.dart';
import '../../../data/models/user.dart';

/// Low-level data source that talks directly to SQLite for auth.
class AuthLocalDataSource {
  AuthLocalDataSource({
    DatabaseService? databaseService,
  }) : _databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService _databaseService;

  Future<User?> getUserByEmail(String email) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User> createUser(User user) async {
    final db = await _databaseService.database;
    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }
}


