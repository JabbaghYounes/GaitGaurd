import 'package:meta/meta.dart';

/// User profile model for storing personal information.
///
/// Extends the basic User model with profile-specific fields
/// that can be edited by the user.
@immutable
class Profile {
  const Profile({
    this.id,
    required this.userId,
    this.email,
    this.firstName,
    this.lastName,
    this.displayName,
    this.bio,
    this.phoneNumber,
    this.dateOfBirth,
    this.updatedAt,
  });

  final int? id;
  final int userId; // Foreign key to users table
  final String? email; // User email from users table
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? bio;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final DateTime? updatedAt;

  Profile copyWith({
    int? id,
    int? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? displayName,
    String? bio,
    String? phoneNumber,
    DateTime? dateOfBirth,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates a profile with current timestamp for updated_at
  Profile withUpdatedFields({
    String? firstName,
    String? lastName,
    String? displayName,
    String? bio,
    String? phoneNumber,
    DateTime? dateOfBirth,
  }) {
    return copyWith(
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
      bio: bio,
      phoneNumber: phoneNumber,
      dateOfBirth: dateOfBirth,
      updatedAt: DateTime.now(),
    );
  }

  /// Returns the display name, falling back to first + last name
  String get effectiveDisplayName {
    if (displayName?.isNotEmpty == true) {
      return displayName!;
    }
    final parts = [
      if (firstName?.isNotEmpty == true) firstName,
      if (lastName?.isNotEmpty == true) lastName,
    ];
    return parts.isNotEmpty ? parts.join(' ') : 'Anonymous User';
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'display_name': displayName,
      'bio': bio,
      'phone_number': phoneNumber,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Profile.fromMap(Map<String, Object?> map) {
    return Profile(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      email: map['email'] as String?,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      displayName: map['display_name'] as String?,
      bio: map['bio'] as String?,
      phoneNumber: map['phone_number'] as String?,
      dateOfBirth: map['date_of_birth'] != null
          ? DateTime.parse(map['date_of_birth'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile &&
        other.id == id &&
        other.userId == userId &&
        other.email == email &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.displayName == displayName &&
        other.bio == bio &&
        other.phoneNumber == phoneNumber &&
        other.dateOfBirth == dateOfBirth &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      email,
      firstName,
      lastName,
      displayName,
      bio,
      phoneNumber,
      dateOfBirth,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'Profile(id: $id, userId: $userId, displayName: $effectiveDisplayName)';
  }
}