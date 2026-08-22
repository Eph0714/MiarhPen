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

  /// One-time repair for transactions recorded before a bug fix that left
  /// new entries with `accounting_period_id = NULL` — such rows were
  /// invisible to the dashboard's period-scoped Money In/Out/Net
  /// Movement/Ending Balance sums even though they were saved correctly
  /// and their account balances were already right. This only fills in
  /// that missing reference on rows where it's currently null; it never
  /// touches amount, date, description, or any other field, so no
  /// existing record is erased or overwritten — just linked to the period
  /// it actually belongs to. Returns the number of rows fixed.
  Future<int> backfillMissingAccountingPeriod(int periodId) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update('transactions', {
      'accounting_period_id': periodId,
    }, where: 'accounting_period_id IS NULL');
    if (count > 0) {
      DbChangeNotifier.instance.notify(DbTable.transactions);
    }
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

  /// Account types excluded from the Daily Balance Report's cash-position
  /// scope — matches [AccountTypeX.countsTowardAvailableFunds]: a credit
  /// card is a liability (not cash), and a debit card just mirrors its
  /// linked bank account's balance, so counting either here would either
  /// misrepresent or double-count real cash-equivalent money.
  static const _excludedAccountTypesSql = "('creditCard', 'debitCard')";

  /// The total cash-equivalent balance (every account whose type counts
  /// toward available funds — cash, bank, e-wallets, etc.) as of the very
  /// start of [asOf]: each such account's own `beginning_balance`, plus
  /// every income/expense transaction posted to one of them strictly
  /// before that date. This is the Daily Balance Report's anchor point —
  /// each day's own beginning/ending balance is then derived by walking
  /// forward from here one day at a time, so nothing needs to be stored:
  /// editing or deleting any transaction just changes what this (and the
  /// day-by-day totals below) compute next time, with no separate
  /// recalculation step required anywhere.
  Future<double> cashOpeningBalanceAsOf(DateTime asOf) async {
    final db = await AppDatabase.instance.database;
    final cutoff = DateTime(asOf.year, asOf.month, asOf.day).toIso8601String();

    final accountRows = await db.rawQuery(
      'SELECT COALESCE(SUM(beginning_balance), 0) AS total FROM accounts '
      'WHERE type NOT IN $_excludedAccountTypesSql',
    );
    final accountsTotal = (accountRows.first['total'] as num).toDouble();

    final txnRows = await db.rawQuery(
      'SELECT t.type AS type, SUM(t.amount) AS total '
      'FROM transactions t '
      'JOIN accounts a ON a.id = t.account_id '
      'WHERE a.type NOT IN $_excludedAccountTypesSql AND t.date < ? '
      'GROUP BY t.type',
      [cutoff],
    );
    var income = 0.0;
    var expense = 0.0;
    for (final row in txnRows) {
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      if (row['type'] == 'INCOME') {
        income = total;
      } else if (row['type'] == 'EXPENSE') {
        expense = total;
      }
    }
    return accountsTotal + income - expense;
  }

  /// Per-day income/expense totals across cash-equivalent accounts (see
  /// [cashOpeningBalanceAsOf]) for `[from, to]` inclusive, keyed by
  /// [DateFormatter.iso]-formatted date (`yyyy-MM-dd`) — matches SQLite's
  /// own `date()` output, which is what this groups by.
  Future<Map<String, ({double income, double expense})>> cashDailyTotals({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await AppDatabase.instance.database;
    final fromIso = DateTime(from.year, from.month, from.day).toIso8601String();
    final toIso = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
    ).toIso8601String();

    final rows = await db.rawQuery(
      'SELECT date(t.date) AS day, t.type AS type, SUM(t.amount) AS total '
      'FROM transactions t '
      'JOIN accounts a ON a.id = t.account_id '
      'WHERE a.type NOT IN $_excludedAccountTypesSql '
      'AND t.date >= ? AND t.date <= ? '
      'GROUP BY day, t.type',
      [fromIso, toIso],
    );

    final result = <String, ({double income, double expense})>{};
    for (final row in rows) {
      final day = row['day'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      final existing = result[day] ?? (income: 0.0, expense: 0.0);
      result[day] = row['type'] == 'INCOME'
          ? (income: total, expense: existing.expense)
          : (income: existing.income, expense: total);
    }
    return result;
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
    final categoryColumn = income
        ? 'income_category_id'
        : 'expense_category_id';
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

    final rows = await db.rawQuery('''
      SELECT c.id AS category_id, c.name AS category_name, SUM(t.amount) AS total
      FROM transactions t
      JOIN $categoryTable c ON c.id = t.$categoryColumn
      WHERE $where
      GROUP BY c.id, c.name
      ORDER BY total DESC
      ''', args);
    return rows;
  }
}
