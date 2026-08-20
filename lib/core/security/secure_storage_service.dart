import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] for reading/writing sensitive
/// key-value pairs (tokens, PIN attempt counters, session timestamps).
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Key under which the "remember me" auth token is stored.
  static const String rememberMeToken = 'remember_me_token';

  /// Key under which the number of failed PIN attempts is stored.
  static const String pinAttempts = 'pin_attempts';

  /// Key under which the timestamp of the last user activity is stored.
  static const String lastActiveTimestamp = 'last_active_timestamp';

  /// Key marking that the one-time battery-optimization exemption prompt
  /// has already been shown, so it isn't repeated on every launch.
  static const String batteryOptimizationPrompted =
      'battery_optimization_prompted';

  /// Keys under which the desktop MySQL export connection details are
  /// remembered (so the user doesn't have to retype them every sync) —
  /// stored in secure storage since one of them is a database password.
  static const String mysqlHost = 'mysql_sync_host';
  static const String mysqlPort = 'mysql_sync_port';
  static const String mysqlUser = 'mysql_sync_user';
  static const String mysqlPassword = 'mysql_sync_password';
  static const String mysqlDatabase = 'mysql_sync_database';

  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  Future<void> deleteAll() {
    return _storage.deleteAll();
  }
}
