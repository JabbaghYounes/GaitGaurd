import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/profile.dart';
import '../../data/datasources/local/profile_local_data_source.dart';

/// Profile state classes
abstract class ProfileState {
  const ProfileState();


}

class ProfileInitial extends ProfileState {
  const ProfileInitial();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileInitial && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileLoading && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.profile);

  final Profile profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileLoaded &&
          runtimeType == other.runtimeType &&
          profile == other.profile;

  @override
  int get hashCode => profile.hashCode;
}

class ProfileUpdating extends ProfileState {
  const ProfileUpdating(this.profile);

  final Profile profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileUpdating &&
          runtimeType == other.runtimeType &&
          profile == other.profile;

  @override
  int get hashCode => profile.hashCode;
}

class ProfileError extends ProfileState {
  const ProfileError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// Profile Cubit for managing profile state
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._profileRepository) : super(const ProfileInitial());

  final ProfileRepositoryImpl _profileRepository;

  /// Load profile for the given user ID
  Future<void> loadProfile(int userId) async {
    emit(const ProfileLoading());
    
    try {
      final profile = await _profileRepository.getOrCreateProfile(userId);
      emit(ProfileLoaded(profile));
    } catch (e) {
      emit(ProfileError('Failed to load profile: ${e.toString()}'));
    }
  }

  /// Update profile with new values
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? displayName,
    String? bio,
    String? phoneNumber,
    DateTime? dateOfBirth,
  }) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) {
      emit(const ProfileError('No profile loaded to update'));
      return;
    }

    emit(ProfileUpdating(currentState.profile));

    try {
      final updatedProfile = currentState.profile.withUpdatedFields(
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        bio: bio,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
      );

      final savedProfile = await _profileRepository.updateProfile(updatedProfile);
      emit(ProfileLoaded(savedProfile));
    } catch (e) {
      emit(ProfileError('Failed to update profile: ${e.toString()}'));
      // Revert to previous state on error
      emit(ProfileLoaded(currentState.profile));
    }
  }

  /// Reset to initial state
  void reset() {
    emit(const ProfileInitial());
  }
}