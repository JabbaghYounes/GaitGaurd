import 'package:meta/meta.dart';

/// Local-only user model used for authentication.
///
/// For this MVP the model only stores what we need for login/registration.
@immutable
class User {
  const User({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    required this.createdAt,
  });

  final int? id;
  final String email;
  final String passwordHash;
  final String passwordSalt;
  final DateTime createdAt;

  User copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? passwordSalt,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as int?,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      passwordSalt: map['password_salt'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}


