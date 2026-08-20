import '../../../features/auth/domain/user.dart';
import '../app_database.dart';
import '../db_change_notifier.dart';

class UserDao {
  /// Every user account (MiarhPen supports several people sharing one
  /// household/team ledger) — used by the MySQL export and anywhere else
  /// that needs the full roster rather than just "the first one".
  Future<List<AppUser>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', orderBy: 'id ASC');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<int> insert(AppUser user) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('users', user.toMap());
    DbChangeNotifier.instance.notify(DbTable.users);
    return id;
  }

  Future<int> update(AppUser user) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    DbChangeNotifier.instance.notify(DbTable.users);
    return count;
  }

  Future<AppUser?> getById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getByUsername(String username) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  /// Used by onboarding to check whether any user has been created yet.
  Future<AppUser?> getFirstUser() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', orderBy: 'id ASC', limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  /// The one user (if any) currently flagged to be auto-logged-in on app
  /// start via "Remember Me". At most one user should have this flag set
  /// at a time — [clearAllRememberMe] enforces that invariant whenever a
  /// new user checks the box.
  Future<AppUser?> getRememberedUser() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', where: 'remember_me = 1', limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  /// Clears the "Remember Me" flag on every user — called before setting
  /// it on whoever just logged in with the box checked, since only one
  /// remembered session makes sense on a single device at a time.
  Future<void> clearAllRememberMe() async {
    final db = await AppDatabase.instance.database;
    await db.update('users', {'remember_me': 0});
    DbChangeNotifier.instance.notify(DbTable.users);
  }

  Future<int> updatePassword(
    int id,
    String passwordHash,
    String? passwordSalt,
  ) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'users',
      {
        'password_hash': passwordHash,
        'password_salt': passwordSalt,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.users);
    return count;
  }

  Future<int> updatePin(int id, String? pinHash) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'users',
      {'pin_hash': pinHash, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.users);
    return count;
  }

  Future<int> updateBiometricEnabled(int id, bool enabled) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'users',
      {
        'biometric_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.users);
    return count;
  }

  Future<int> updateSessionTimeout(int id, int minutes) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'users',
      {
        'session_timeout_min': minutes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.users);
    return count;
  }
}
