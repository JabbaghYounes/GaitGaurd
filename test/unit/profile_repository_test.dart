import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../lib/core/services/database_service.dart';
import '../../../lib/data/models/profile.dart';
import '../../../lib/data/datasources/local/profile_local_data_source.dart';

void main() {
  // Initialize FFI
  setUpAll(() {
    // Initialize ffi loader if needed
    sqfliteFfiInit();
    // Set database factory to ffi
    databaseFactory = databaseFactoryFfi;
  });

  group('ProfileRepository Tests', () {
    late DatabaseService databaseService;
    late ProfileRepositoryImpl repository;

    setUp(() async {
      // Create in-memory database for testing
      databaseService = DatabaseService();
      final db = await databaseService.database;
      
      // Create test user
      await db.insert('users', {
        'email': 'test@example.com',
        'password_hash': 'test_hash',
        'password_salt': 'test_salt',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      repository = ProfileRepositoryImpl(databaseService);
    });

    tearDown(() async {
      final db = await databaseService.database;
      await db.close();
    });

    test('should create a new profile', () async {
      // Arrange
      const profile = Profile(
        userId: 1,
        firstName: 'John',
        lastName: 'Doe',
        displayName: 'John Doe',
        bio: 'Test user bio',
        phoneNumber: '+1234567890',
      );

      // Act
      final createdProfile = await repository.createProfile(profile);

      // Assert
      expect(createdProfile.id, isNotNull);
      expect(createdProfile.userId, equals(1));
      expect(createdProfile.firstName, equals('John'));
      expect(createdProfile.lastName, equals('Doe'));
      expect(createdProfile.displayName, equals('John Doe'));
      expect(createdProfile.bio, equals('Test user bio'));
      expect(createdProfile.phoneNumber, equals('+1234567890'));
      expect(createdProfile.updatedAt, isNotNull);
    });

    test('should get profile by user ID', () async {
      // Arrange
      const profile = Profile(
        userId: 1,
        displayName: 'Test User',
      );
      await repository.createProfile(profile);

      // Act
      final retrievedProfile = await repository.getProfile(1);

      // Assert
      expect(retrievedProfile, isNotNull);
      expect(retrievedProfile!.userId, equals(1));
      expect(retrievedProfile.displayName, equals('Test User'));
    });

    test('should return null when profile does not exist', () async {
      // Act
      final profile = await repository.getProfile(999);

      // Assert
      expect(profile, isNull);
    });

    test('should update existing profile', () async {
      // Arrange
      const originalProfile = Profile(
        userId: 1,
        displayName: 'Original Name',
      );
      final createdProfile = await repository.createProfile(originalProfile);

      final updatedProfile = createdProfile.copyWith(
        displayName: 'Updated Name',
        bio: 'Updated bio',
      );

      // Act
      final result = await repository.updateProfile(updatedProfile);

      // Assert
      expect(result.displayName, equals('Updated Name'));
      expect(result.bio, equals('Updated bio'));
      expect(result.updatedAt, isNot(equals(createdProfile.updatedAt)));
    });

    test('should throw error when updating profile without ID', () async {
      // Arrange
      const profile = Profile(
        userId: 1,
        displayName: 'Test',
      );

      // Act & Assert
      expect(
        () => repository.updateProfile(profile),
        throwsArgumentError,
      );
    });

    test('should delete profile by user ID', () async {
      // Arrange
      const profile = Profile(
        userId: 1,
        displayName: 'Test User',
      );
      await repository.createProfile(profile);

      // Act
      await repository.deleteProfile(1);

      // Assert
      final deletedProfile = await repository.getProfile(1);
      expect(deletedProfile, isNull);
    });

    test('should get all profiles', () async {
      // Arrange
      const profile1 = Profile(
        userId: 1,
        displayName: 'User 1',
      );
      const profile2 = Profile(
        userId: 2, // Note: This would require another user in test setup
        displayName: 'User 2',
      );

      // For now, just test with one profile
      await repository.createProfile(profile1);

      // Act
      final profiles = await repository.getAllProfiles();

      // Assert
      expect(profiles, isNotEmpty);
      expect(profiles.first.displayName, equals('User 1'));
    });

    test('should get or create profile', () async {
      // Arrange
      const profile = Profile(
        userId: 1,
        displayName: 'Test User',
      );

      // Act
      final result1 = await repository.getOrCreateProfile(1);
      expect(result1.displayName, equals('Test User'));

      // Create the profile
      await repository.createProfile(profile);

      final result2 = await repository.getOrCreateProfile(1);
      expect(result2.displayName, equals('Test User'));
      expect(result2.id, isNotNull);
    });
  });

  group('Profile Model Tests', () {
    test('should create profile with required fields', () {
      // Arrange & Act
      const profile = Profile(
        userId: 1,
      );

      // Assert
      expect(profile.userId, equals(1));
      expect(profile.firstName, isNull);
      expect(profile.lastName, isNull);
      expect(profile.displayName, isNull);
    });

    test('should copy profile with new values', () {
      // Arrange
      const original = Profile(
        userId: 1,
        firstName: 'John',
      );

      // Act
      final copied = original.copyWith(
        lastName: 'Doe',
        displayName: 'John Doe',
      );

      // Assert
      expect(copied.userId, equals(1));
      expect(copied.firstName, equals('John'));
      expect(copied.lastName, equals('Doe'));
      expect(copied.displayName, equals('John Doe'));
    });

    test('should update profile with current timestamp', () {
      // Arrange
      const original = Profile(
        userId: 1,
        displayName: 'Old Name',
      );

      // Act
      final updated = original.withUpdatedFields(
        displayName: 'New Name',
      );

      // Assert
      expect(updated.displayName, equals('New Name'));
      expect(updated.updatedAt, isNotNull);
    });

    test('should return effective display name correctly', () {
      // Test with display name set
      const profile1 = Profile(
        userId: 1,
        displayName: 'Custom Name',
        firstName: 'John',
        lastName: 'Doe',
      );
      expect(profile1.effectiveDisplayName, equals('Custom Name'));

      // Test with first and last name
      const profile2 = Profile(
        userId: 1,
        firstName: 'John',
        lastName: 'Doe',
      );
      expect(profile2.effectiveDisplayName, equals('John Doe'));

      // Test with only first name
      const profile3 = Profile(
        userId: 1,
        firstName: 'John',
      );
      expect(profile3.effectiveDisplayName, equals('John'));

      // Test with no names
      const profile4 = Profile(
        userId: 1,
      );
      expect(profile4.effectiveDisplayName, equals('Anonymous User'));
    });

    test('should convert to and from map correctly', () {
      // Arrange
      const original = Profile(
        id: 1,
        userId: 2,
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        displayName: 'John Doe',
        bio: 'Test bio',
        phoneNumber: '+1234567890',
      );

      // Act
      final map = original.toMap();
      final fromMap = Profile.fromMap(map);

      // Assert
      expect(fromMap, equals(original));
    });
  });
}