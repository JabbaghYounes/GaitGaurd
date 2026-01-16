import 'package:flutter_test/flutter_test.dart';

import 'package:gait_guard_app/core/utils/password_hasher.dart';
import 'package:gait_guard_app/data/datasources/local/auth_local_data_source.dart';
import 'package:gait_guard_app/data/models/user.dart';
import 'package:gait_guard_app/data/repositories/auth_repository.dart';

/// Simple in-memory fake for the local data source to avoid touching SQLite
/// in unit tests.
class _FakeAuthLocalDataSource extends AuthLocalDataSource {
  _FakeAuthLocalDataSource() : super(databaseService: null);

  final Map<String, User> _usersByEmail = {};

  @override
  Future<User?> getUserByEmail(String email) async {
    return _usersByEmail[email];
  }

  @override
  Future<User> createUser(User user) async {
    final id = _usersByEmail.length + 1;
    final created = user.copyWith(id: id);
    _usersByEmail[user.email] = created;
    return created;
  }
}

void main() {
  group('AuthRepository validation', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(localDataSource: _FakeAuthLocalDataSource());
    });

    test('rejects empty email and password', () {
      final result = repository.validateCredentials(
        email: '',
        password: '',
        isRegistration: true,
      );

      expect(result.isValid, isFalse);
      expect(result.emailError, isNotNull);
      expect(result.passwordError, isNotNull);
    });

    test('rejects short password', () {
      final result = repository.validateCredentials(
        email: 'user@example.com',
        password: 'short',
        isRegistration: true,
      );

      expect(result.isValid, isFalse);
      expect(result.passwordError, isNotNull);
    });

    test('accepts valid email and password', () {
      final result = repository.validateCredentials(
        email: 'user@example.com',
        password: 'longenough',
        isRegistration: true,
      );

      expect(result.isValid, isTrue);
    });
  });

  group('AuthRepository register/login', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(localDataSource: _FakeAuthLocalDataSource());
    });

    test('register then login succeeds', () async {
      final user = await repository.register(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(user.id, isNotNull);
      expect(user.email, 'user@example.com');
      expect(user.passwordHash, isNotEmpty);
      expect(user.passwordSalt, isNotEmpty);

      final loggedIn = await repository.login(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(loggedIn.id, user.id);
    });

    test('login with wrong password fails', () async {
      await repository.register(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(
        () => repository.login(
          email: 'user@example.com',
          password: 'wrong',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });
}


