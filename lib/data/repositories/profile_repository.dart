import '../models/profile.dart';

/// Repository interface for profile data operations.
abstract class ProfileRepository {
  /// Gets the profile for a given user ID.
  /// Returns null if no profile exists.
  Future<Profile?> getProfile(int userId);

  /// Creates a new profile for the given user.
  /// Returns the created profile with ID.
  Future<Profile> createProfile(Profile profile);

  /// Updates an existing profile.
  /// Returns the updated profile.
  Future<Profile> updateProfile(Profile profile);

  /// Deletes a profile by user ID.
  Future<void> deleteProfile(int userId);

  /// Gets all profiles (mainly for testing/debugging).
  Future<List<Profile>> getAllProfiles();
}