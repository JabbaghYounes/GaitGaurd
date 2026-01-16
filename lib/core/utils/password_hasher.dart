import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Simple password hashing helper for local-only auth.
///
/// For this MVP we use a random salt + SHA-256. This is *not* as strong as a
/// dedicated password hashing algorithm like Argon2 or bcrypt, but is still
/// significantly better than storing plaintext or unsalted hashes.
class PasswordHasher {
  static const _saltLengthBytes = 16;

  static String _randomSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(_saltLengthBytes, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  static ({String hash, String salt}) hashPassword(String password) {
    final salt = _randomSalt();
    final hash = _hashWithSalt(password: password, salt: salt);
    return (hash: hash, salt: salt);
  }

  static bool verifyPassword({
    required String password,
    required String hash,
    required String salt,
  }) {
    final candidate = _hashWithSalt(password: password, salt: salt);
    return constantTimeComparison(candidate, hash);
  }

  static String _hashWithSalt({
    required String password,
    required String salt,
  }) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Constant-time string comparison to reduce timing side channels.
  static bool constantTimeComparison(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}


