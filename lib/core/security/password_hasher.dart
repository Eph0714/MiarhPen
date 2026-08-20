import 'package:bcrypt/bcrypt.dart';

/// Hashes and verifies passwords/PINs using bcrypt.
///
/// Never store or log plaintext passwords or PINs. This is the only file
/// in the codebase that should touch the `bcrypt` package directly — all
/// other code should go through [PasswordHasher] (or [PinService], which
/// delegates here).
class PasswordHasher {
  PasswordHasher._();

  static String hash(String plainPassword) {
    return BCrypt.hashpw(plainPassword, BCrypt.gensalt());
  }

  static bool verify(String plainPassword, String hash) {
    try {
      return BCrypt.checkpw(plainPassword, hash);
    } on FormatException {
      // Malformed/unexpected hash format should never crash login.
      return false;
    }
  }
}
