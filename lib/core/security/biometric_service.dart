import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/local_auth.dart';

/// Wraps `local_auth` to check biometric availability and prompt the
/// device's biometric/PIN authentication UI.
///
/// If [authenticate] returns false, the caller should fall back to the
/// app's own PIN/password flow — it should never crash the app.
class BiometricService {
  BiometricService({LocalAuthentication? localAuthentication})
      : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> isDeviceSupported() {
    return _localAuthentication.isDeviceSupported();
  }

  Future<bool> canCheckBiometrics() {
    return _localAuthentication.canCheckBiometrics;
  }

  Future<bool> authenticate({
    String reason = 'Authenticate to access MiarhPen',
  }) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
