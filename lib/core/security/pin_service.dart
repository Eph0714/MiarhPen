import '../constants/app_constants.dart';
import 'password_hasher.dart';
import 'secure_storage_service.dart';

/// Validates PIN format and hashes/verifies PINs, plus tracks failed PIN
/// attempts (persisted via [SecureStorageService]).
///
/// This service only tracks the failed-attempt count — the caller (UI)
/// decides what to do once the cap is reached (e.g. force a full
/// password re-login).
class PinService {
  PinService({SecureStorageService? secureStorageService})
    : _secureStorageService = secureStorageService ?? SecureStorageService();

  final SecureStorageService _secureStorageService;

  /// Failed attempts are tracked (and displayed) up to this cap.
  static const int maxTrackedAttempts = 5;

  static bool isValidPinFormat(String pin) {
    if (pin.length < AppConstants.minPinLength ||
        pin.length > AppConstants.maxPinLength) {
      return false;
    }
    return RegExp(r'^[0-9]+$').hasMatch(pin);
  }

  static String hashPin(String pin) => PasswordHasher.hash(pin);

  static bool verifyPin(String pin, String hash) {
    return PasswordHasher.verify(pin, hash);
  }

  Future<int> getFailedAttempts() async {
    final raw = await _secureStorageService.read(
      SecureStorageService.pinAttempts,
    );
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> recordFailedAttempt() async {
    final current = await getFailedAttempts();
    final updated = current + 1 > maxTrackedAttempts
        ? maxTrackedAttempts
        : current + 1;
    await _secureStorageService.write(
      SecureStorageService.pinAttempts,
      updated.toString(),
    );
  }

  Future<void> resetFailedAttempts() async {
    await _secureStorageService.write(SecureStorageService.pinAttempts, '0');
  }
}
