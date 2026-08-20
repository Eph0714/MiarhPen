import '../../../core/constants/app_constants.dart';
import '../../../features/transactions/domain/transaction_entry.dart';
import '../app_database.dart';
import '../db_change_notifier.dart';

class TransactionDao {
  Future<int> insert(TransactionEntry entry) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('transactions', entry.toMap());
    DbChangeNotifier.instance.notify(DbTable.transactions);
    return id;
  }

  Future<int> update(TransactionEntry entry) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'transactions',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    DbChangeNotifier.instance.notify(DbTable.transactions);
    return count;
  }

  Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    final count = await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.transactions);
    return count;
  }

  Future<TransactionEntry?> getById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TransactionEntry.fromMap(rows.first);
  }

  Future<List<TransactionEntry>> getForAccount(
    int accountId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await AppDatabase.instance.database;
    final where = StringBuffer('account_id = ?');
    final args = <Object?>[accountId];
    if (from != null) {
      where.write(' AND date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND date <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      'transactions',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionEntry.fromMap).toList();
  }

  Future<List<TransactionEntry>> getFiltered({
    DateTime? from,
    DateTime? to,
    int? accountId,
    int? incomeCategoryId,
    int? expenseCategoryId,
    TransactionType? type,
    String? searchText,
  }) async {
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
    if (accountId != null) {
      where.add('account_id = ?');
      args.add(accountId);
    }
    if (incomeCategoryId != null) {
      where.add('income_category_id = ?');
      args.add(incomeCategoryId);
    }
    if (expenseCategoryId != null) {
      where.add('expense_category_id = ?');
      args.add(expenseCategoryId);
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type == TransactionType.income ? 'INCOME' : 'EXPENSE');
    }
    if (searchText != null && searchText.isNotEmpty) {
      where.add(
        '(description LIKE ? OR reference_number LIKE ? OR notes LIKE ?)',
      );
      final like = '%$searchText%';
      args
        ..add(like)
        ..add(like)
        ..add(like);
    }

    final rows = await db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionEntry.fromMap).toList();
  }

  Future<double> sumIncomeForAccount(int accountId) async {
    return _sumForAccount(accountId, 'INCOME');
  }

  Future<double> sumExpenseForAccount(int accountId) async {
    return _sumForAccount(accountId, 'EXPENSE');
  }

  Future<double> _sumForAccount(int accountId, String type) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM transactions WHERE account_id = ? AND type = ?',
      [accountId, type],
    );
    final total = rows.first['total'];
    return (total as num?)?.toDouble() ?? 0;
  }

  Future<double> sumIncomeForPeriod(int periodId) async {
    return _sumForPeriod(periodId, 'INCOME');
  }

  Future<double> sumExpenseForPeriod(int periodId) async {
    return _sumForPeriod(periodId, 'EXPENSE');
  }

  Future<double> _sumForPeriod(int periodId, String type) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM transactions WHERE accounting_period_id = ? AND type = ?',
      [periodId, type],
    );
    final total = rows.first['total'];
    return (total as num?)?.toDouble() ?? 0;
  }

  /// Returns rows of `{category_id, category_name, total}` for reports and
  /// charts, joined against income_categories or expense_categories
  /// depending on [income].
  Future<List<Map<String, Object?>>> sumByCategory({
    required bool income,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await AppDatabase.instance.database;
    final categoryTable = income ? 'income_categories' : 'expense_categories';
    final categoryColumn = income ? 'income_category_id' : 'expense_category_id';
    final type = income ? 'INCOME' : 'EXPENSE';

    final where = StringBuffer('t.type = ?');
    final args = <Object?>[type];
    if (from != null) {
      where.write(' AND t.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND t.date <= ?');
      args.add(to.toIso8601String());
    }

    final rows = await db.rawQuery(
      '''
      SELECT c.id AS category_id, c.name AS category_name, SUM(t.amount) AS total
      FROM transactions t
      JOIN $categoryTable c ON c.id = t.$categoryColumn
      WHERE $where
      GROUP BY c.id, c.name
      ORDER BY total DESC
      ''',
      args,
    );
    return rows;
  }
}
