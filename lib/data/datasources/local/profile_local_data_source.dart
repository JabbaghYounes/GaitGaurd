import '../../core/services/database_service.dart';
import '../models/profile.dart';
import 'profile_repository.dart';

/// SQLite implementation of ProfileRepository.
class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<Profile?> getProfile(int userId) async {
    final db = await _databaseService.database;
    final maps = await db.rawQuery('''
      SELECT 
        p.*,
        u.email as email
      FROM profiles p
      LEFT JOIN users u ON p.user_id = u.id
      WHERE p.user_id = ?
      LIMIT 1
    ''', [userId]);

    if (maps.isEmpty) return null;
    return Profile.fromMap(maps.first);
  }

  @override
  Future<Profile> createProfile(Profile profile) async {
    final db = await _databaseService.database;
    final id = await db.insert(
      'profiles',
      profile.copyWith(updatedAt: DateTime.now()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return profile.copyWith(id: id, updatedAt: DateTime.now());
  }

  @override
  Future<Profile> updateProfile(Profile profile) async {
    final db = await _databaseService.database;
    
    if (profile.id == null) {
      throw ArgumentError('Profile ID is required for updates');
    }

    final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
    await db.update(
      'profiles',
      updatedProfile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );

    return updatedProfile;
  }

  @override
  Future<void> deleteProfile(int userId) async {
    final db = await _databaseService.database;
    await db.delete(
      'profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  @override
  Future<List<Profile>> getAllProfiles() async {
    final db = await _databaseService.database;
    final maps = await db.rawQuery('''
      SELECT 
        p.*,
        u.email as email
      FROM profiles p
      LEFT JOIN users u ON p.user_id = u.id
      ORDER BY p.updated_at DESC
    ''');
    
    return maps.map((map) => Profile.fromMap(map)).toList();
  }

  /// Gets or creates a profile for the given user ID.
  /// If no profile exists, creates a default one.
  Future<Profile> getOrCreateProfile(int userId) async {
    final existingProfile = await getProfile(userId);
    if (existingProfile != null) return existingProfile;

    // Create default profile
    final defaultProfile = Profile(
      userId: userId,
      updatedAt: DateTime.now(),
    );
    
    return createProfile(defaultProfile);
  }
}