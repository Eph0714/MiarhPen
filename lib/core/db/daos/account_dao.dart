import '../../../features/accounts/domain/account.dart';
import '../app_database.dart';
import '../db_change_notifier.dart';

class AccountDao {
  Future<int> insert(Account account) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('accounts', account.toMap());
    DbChangeNotifier.instance.notify(DbTable.accounts);
    return id;
  }

  Future<int> update(Account account) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
    DbChangeNotifier.instance.notify(DbTable.accounts);
    return count;
  }

  Future<Account?> getById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  Future<List<Account>> getAll({bool activeOnly = false}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<List<Account>> search(String query) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  /// Soft-disable only. Accounts must never be hard-deleted (spec), so no
  /// hard-delete method is provided at all — this is the only removal path.
  Future<int> disable(int id) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'accounts',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.accounts);
    return count;
  }

  /// Whether this account has any transaction or transfer history —
  /// used to guard destructive UI actions.
  Future<bool> hasTransactionHistory(int id) async {
    final db = await AppDatabase.instance.database;
    final txnRows = await db.rawQuery(
      'SELECT 1 FROM transactions WHERE account_id = ? LIMIT 1',
      [id],
    );
    if (txnRows.isNotEmpty) return true;
    final transferRows = await db.rawQuery(
      'SELECT 1 FROM transfers WHERE from_account_id = ? OR to_account_id = ? LIMIT 1',
      [id, id],
    );
    return transferRows.isNotEmpty;
  }

  /// Raw write of the cached balance fields. This is the SINGLE trusted
  /// write path for `current_balance` / `outstanding_balance` — it must
  /// only ever be called by [AccountBalanceRecalculator]. No other caller
  /// should write these columns directly; balances are always re-derived
  /// from source records to avoid double-counting and drift bugs.
  Future<int> updateBalanceFields(
    int id, {
    double? currentBalance,
    double? outstandingBalance,
  }) async {
    final db = await AppDatabase.instance.database;
    final values = <String, Object?>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (currentBalance != null) {
      values['current_balance'] = currentBalance;
    }
    values['outstanding_balance'] = outstandingBalance;
    final count = await db.update(
      'accounts',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.accounts);
    return count;
  }
}
