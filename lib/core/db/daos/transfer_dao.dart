import '../../../features/transfers/domain/transfer.dart';
import '../app_database.dart';
import '../db_change_notifier.dart';

class TransferDao {
  Future<int> insert(Transfer transfer) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('transfers', transfer.toMap());
    DbChangeNotifier.instance.notify(DbTable.transfers);
    return id;
  }

  Future<int> update(Transfer transfer) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'transfers',
      transfer.toMap(),
      where: 'id = ?',
      whereArgs: [transfer.id],
    );
    DbChangeNotifier.instance.notify(DbTable.transfers);
    return count;
  }

  Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    final count = await db.delete(
      'transfers',
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.transfers);
    return count;
  }

  Future<Transfer?> getById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'transfers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Transfer.fromMap(rows.first);
  }

  Future<List<Transfer>> getAll({DateTime? from, DateTime? to}) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      'transfers',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transfer.fromMap).toList();
  }

  Future<List<Transfer>> getForAccount(int accountId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'transfers',
      where: 'from_account_id = ? OR to_account_id = ?',
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transfer.fromMap).toList();
  }

  Future<double> sumTransfersInForAccount(int accountId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM transfers WHERE to_account_id = ?',
      [accountId],
    );
    final total = rows.first['total'];
    return (total as num?)?.toDouble() ?? 0;
  }

  Future<double> sumTransfersOutForAccount(int accountId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM transfers WHERE from_account_id = ?',
      [accountId],
    );
    final total = rows.first['total'];
    return (total as num?)?.toDouble() ?? 0;
  }
}
