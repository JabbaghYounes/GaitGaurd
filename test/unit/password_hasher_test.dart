import 'package:flutter_test/flutter_test.dart';

import 'package:gait_guard_app/core/utils/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('hashPassword returns non-empty hash and salt', () {
      final result = PasswordHasher.hashPassword('secret123');

      expect(result.hash, isNotEmpty);
      expect(result.salt, isNotEmpty);
    });

    test('verifyPassword succeeds for correct password', () {
      final result = PasswordHasher.hashPassword('secret123');

      final ok = PasswordHasher.verifyPassword(
        password: 'secret123',
        hash: result.hash,
        salt: result.salt,
      );

      expect(ok, isTrue);
    });

    test('verifyPassword fails for incorrect password', () {
      final result = PasswordHasher.hashPassword('secret123');

      final ok = PasswordHasher.verifyPassword(
        password: 'wrong',
        hash: result.hash,
        salt: result.salt,
      );

      expect(ok, isFalse);
    });
  });
}


