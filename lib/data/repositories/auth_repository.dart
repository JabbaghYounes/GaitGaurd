import 'package:intl/intl.dart';

import '../../core/utils/password_hasher.dart';
import '../datasources/local/auth_local_data_source.dart';
import '../models/user.dart';

/// Failures specific to auth operations.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Minimal validation result for auth forms.
class AuthValidationResult {
  const AuthValidationResult({this.emailError, this.passwordError});

  final String? emailError;
  final String? passwordError;

  bool get isValid => emailError == null && passwordError == null;
}

/// Repository that coordinates validation, hashing and persistence for auth.
class AuthRepository {
  AuthRepository({
    AuthLocalDataSource? localDataSource,
  }) : _localDataSource = localDataSource ?? AuthLocalDataSource();

  final AuthLocalDataSource _localDataSource;

  AuthValidationResult validateCredentials({
    required String email,
    required String password,
    bool isRegistration = false,
  }) {
    String? emailError;
    String? passwordError;

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      emailError = 'Email is required';
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(trimmedEmail)) {
      emailError = 'Enter a valid email';
    }

    if (password.isEmpty) {
      passwordError = 'Password is required';
    } else if (password.length < 8) {
      // Basic length requirement for MVP.
      passwordError = 'Use at least 8 characters';
    }

    if (isRegistration && passwordError == null) {
      // Add any extra registration rules here (e.g., mixed character classes).
    }

    return AuthValidationResult(
      emailError: emailError,
      passwordError: passwordError,
    );
  }

  Future<User> register({
    required String email,
    required String password,
  }) async {
    final validation = validateCredentials(
      email: email,
      password: password,
      isRegistration: true,
    );
    if (!validation.isValid) {
      throw AuthException(
        validation.emailError ?? validation.passwordError ?? 'Invalid input',
      );
    }

    final existing = await _localDataSource.getUserByEmail(email.trim());
    if (existing != null) {
      throw AuthException('An account with this email already exists');
    }

    final hashed = PasswordHasher.hashPassword(password);
    final now = DateTime.now();

    final user = User(
      email: email.trim(),
      passwordHash: hashed.hash,
      passwordSalt: hashed.salt,
      createdAt: now,
    );

    final created = await _localDataSource.createUser(user);
    return created;
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final validation = validateCredentials(
      email: email,
      password: password,
      isRegistration: false,
    );
    if (!validation.isValid) {
      throw AuthException('Invalid email or password');
    }

    final user = await _localDataSource.getUserByEmail(email.trim());
    if (user == null) {
      throw AuthException('Invalid email or password');
    }

    final ok = PasswordHasher.verifyPassword(
      password: password,
      hash: user.passwordHash,
      salt: user.passwordSalt,
    );
    if (!ok) {
      throw AuthException('Invalid email or password');
    }

    return user;
  }

  /// Helper for showing a human-readable created date in the UI.
  String formatCreatedAt(User user) {
    final formatter = DateFormat.yMMMd().add_jm();
    return formatter.format(user.createdAt);
  }
}


