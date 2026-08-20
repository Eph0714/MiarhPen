import '../../../features/accounting_periods/domain/accounting_period.dart';
import '../app_database.dart';
import '../db_change_notifier.dart';

class AccountingPeriodDao {
  Future<int> insert(AccountingPeriod period) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('accounting_periods', period.toMap());
    DbChangeNotifier.instance.notify(DbTable.accountingPeriods);
    return id;
  }

  Future<int> update(AccountingPeriod period) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'accounting_periods',
      period.toMap(),
      where: 'id = ?',
      whereArgs: [period.id],
    );
    DbChangeNotifier.instance.notify(DbTable.accountingPeriods);
    return count;
  }

  Future<AccountingPeriod?> getById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounting_periods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AccountingPeriod.fromMap(rows.first);
  }

  Future<List<AccountingPeriod>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounting_periods',
      orderBy: 'start_date DESC',
    );
    return rows.map(AccountingPeriod.fromMap).toList();
  }

  /// Returns the currently open period, if any (there should be at most one).
  Future<AccountingPeriod?> getOpenPeriod() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounting_periods',
      where: 'status = ?',
      whereArgs: ['OPEN'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AccountingPeriod.fromMap(rows.first);
  }

  /// The most recently closed period (by when it was closed), if any —
  /// used to default a new period's beginning balance to the previous
  /// period's frozen ending balance, so opening the next period doesn't
  /// silently reset the running total to zero.
  Future<AccountingPeriod?> getMostRecentlyClosed() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounting_periods',
      where: 'status = ?',
      whereArgs: ['CLOSED'],
      orderBy: 'closed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AccountingPeriod.fromMap(rows.first);
  }

  Future<int> closePeriod(
    int id,
    DateTime endDate,
    double endingBalance,
  ) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'accounting_periods',
      {
        'status': 'CLOSED',
        'end_date': endDate.toIso8601String(),
        'ending_balance': endingBalance,
        'closed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.accountingPeriods);
    return count;
  }
}
