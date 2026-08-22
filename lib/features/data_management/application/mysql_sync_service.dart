import 'package:mysql1/mysql1.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/account_dao.dart';
import '../../../core/db/daos/accounting_period_dao.dart';
import '../../../core/db/daos/expense_category_dao.dart';
import '../../../core/db/daos/income_category_dao.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../../../core/db/daos/transfer_dao.dart';
import '../../../core/db/daos/user_dao.dart';

/// Connection details for a desktop MySQL server MiarhPen can export a
/// snapshot of its data to. Filled in by the user in Settings > Data —
/// there is no built-in default host, since "localhost" from the phone's
/// perspective is the phone itself, not whatever PC is actually running
/// the server. The phone and the MySQL server must be reachable from
/// each other (typically the same Wi-Fi network), and the server must be
/// configured to accept connections from other devices on that network,
/// not just from itself.
class MySqlSyncConfig {
  final String host;
  final int port;
  final String user;
  final String password;
  final String database;

  const MySqlSyncConfig({
    required this.host,
    this.port = 3306,
    required this.user,
    required this.password,
    this.database = 'miarhpen',
  });
}

/// Pushes a full, one-way snapshot of MiarhPen's local SQLite data up to
/// a MySQL database matching `mysql_schema.sql` (see the project root).
///
/// This is strictly export-only: the app's real, primary, offline
/// database is always the on-device SQLite file — nothing here is ever
/// read back into the app. MySQL is a desktop-viewable mirror (via MySQL
/// Workbench, phpMyAdmin, etc.), refreshed each time the user taps
/// "Sync to MySQL" in Settings > Data.
///
/// Each sync clears and re-inserts every table (inside one transaction,
/// with foreign-key checks briefly disabled to allow clearing/reloading
/// in any order) rather than attempting incremental upserts — simpler
/// and safer to reason about for an on-demand snapshot than merge logic
/// that could silently drift from the real data over time.
class MySqlSyncService {
  Future<void> sync(MySqlSyncConfig config) async {
    final settings = ConnectionSettings(
      host: config.host,
      port: config.port,
      user: config.user,
      password: config.password,
      db: config.database,
    );

    // Without a timeout, an unreachable host (wrong IP, server not
    // running, phone and PC not actually on the same network) leaves the
    // "Sync to MySQL" button spinning forever instead of ever surfacing
    // an error — the socket connect just never resolves either way.
    final conn = await MySqlConnection.connect(settings).timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw Exception(
        'Could not reach ${config.host}:${config.port} within 12s. Check '
        'that the MySQL server is running, the address/port are correct, '
        'and the phone and server are on the same network.',
      ),
    );
    try {
      await conn.query('SET FOREIGN_KEY_CHECKS = 0');
      await conn.transaction((txn) async {
        await _syncUsers(txn);
        await _syncAccountingPeriods(txn);
        await _syncAccounts(txn);
        await _syncIncomeCategories(txn);
        await _syncExpenseCategories(txn);
        await _syncTransactions(txn);
        await _syncTransfers(txn);
      });
    } finally {
      await conn.query('SET FOREIGN_KEY_CHECKS = 1');
      await conn.close();
    }
  }

  Future<void> _syncUsers(TransactionContext txn) async {
    final users = await UserDao().getAll();
    await txn.query('DELETE FROM users');
    for (final u in users) {
      await txn.query(
        'INSERT INTO users (id, username, password_hash, password_salt, '
        'pin_hash, biometric_enabled, remember_me, session_timeout_min, '
        'currency_code, currency_symbol, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          u.id,
          u.username,
          u.passwordHash,
          u.passwordSalt,
          u.pinHash,
          u.biometricEnabled ? 1 : 0,
          u.rememberMe ? 1 : 0,
          u.sessionTimeoutMin,
          u.currencyCode,
          u.currencySymbol,
          u.createdAt.toIso8601String(),
          u.updatedAt.toIso8601String(),
        ],
      );
    }
  }

  Future<void> _syncAccountingPeriods(TransactionContext txn) async {
    final periods = await AccountingPeriodDao().getAll();
    await txn.query('DELETE FROM accounting_periods');
    for (final p in periods) {
      await txn.query(
        'INSERT INTO accounting_periods (id, name, start_date, end_date, '
        'beginning_balance, total_income, total_expense, ending_balance, '
        'status, created_at, closed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          p.id,
          p.name,
          p.startDate.toIso8601String(),
          p.endDate?.toIso8601String(),
          p.beginningBalance,
          p.totalIncome,
          p.totalExpense,
          p.endingBalance,
          p.status.name.toUpperCase(),
          p.createdAt.toIso8601String(),
          p.closedAt?.toIso8601String(),
        ],
      );
    }
  }

  Future<void> _syncAccounts(TransactionContext txn) async {
    final accounts = await AccountDao().getAll();
    await txn.query('DELETE FROM accounts');
    // Two passes: first insert every row with linked_account_id left
    // null, then fill it in — self-referencing FK, so a debit card
    // account can reference a bank account that hasn't been inserted
    // yet if inserted in a single pass in the wrong order.
    for (final a in accounts) {
      await txn.query(
        'INSERT INTO accounts (id, name, type, description, '
        'beginning_balance, current_balance, credit_limit, '
        'outstanding_balance, statement_date, due_date, linked_account_id, '
        'is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)',
        [
          a.id,
          a.name,
          a.type.storageValue,
          a.description,
          a.beginningBalance,
          a.currentBalance,
          a.creditLimit,
          a.outstandingBalance,
          a.statementDate,
          a.dueDate,
          a.isActive ? 1 : 0,
          a.createdAt.toIso8601String(),
          a.updatedAt.toIso8601String(),
        ],
      );
    }
    for (final a in accounts) {
      if (a.linkedAccountId == null) continue;
      await txn.query(
        'UPDATE accounts SET linked_account_id = ? WHERE id = ?',
        [a.linkedAccountId, a.id],
      );
    }
  }

  Future<void> _syncIncomeCategories(TransactionContext txn) async {
    final categories = await IncomeCategoryDao().getAll();
    await txn.query('DELETE FROM income_categories');
    for (final c in categories) {
      await txn.query(
        'INSERT INTO income_categories (id, name, description, is_active, '
        'is_default, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        [
          c.id,
          c.name,
          c.description,
          c.isActive ? 1 : 0,
          c.isDefault ? 1 : 0,
          c.createdAt.toIso8601String(),
        ],
      );
    }
  }

  Future<void> _syncExpenseCategories(TransactionContext txn) async {
    final categories = await ExpenseCategoryDao().getAll();
    await txn.query('DELETE FROM expense_categories');
    for (final c in categories) {
      await txn.query(
        'INSERT INTO expense_categories (id, name, description, is_active, '
        'is_default, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        [
          c.id,
          c.name,
          c.description,
          c.isActive ? 1 : 0,
          c.isDefault ? 1 : 0,
          c.createdAt.toIso8601String(),
        ],
      );
    }
  }

  Future<void> _syncTransactions(TransactionContext txn) async {
    final entries = await TransactionDao().getFiltered();
    await txn.query('DELETE FROM transactions');
    for (final e in entries) {
      await txn.query(
        'INSERT INTO transactions (id, type, date, account_id, '
        'income_category_id, expense_category_id, amount, description, '
        'reference_number, notes, attachment_path, accounting_period_id, '
        'created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          e.id,
          e.isIncome ? 'INCOME' : 'EXPENSE',
          e.date.toIso8601String(),
          e.accountId,
          e.incomeCategoryId,
          e.expenseCategoryId,
          e.amount,
          e.description,
          e.referenceNumber,
          e.notes,
          e.attachmentPath,
          e.accountingPeriodId,
          e.createdAt.toIso8601String(),
          e.updatedAt.toIso8601String(),
        ],
      );
    }
  }

  Future<void> _syncTransfers(TransactionContext txn) async {
    final transfers = await TransferDao().getAll();
    await txn.query('DELETE FROM transfers');
    for (final t in transfers) {
      await txn.query(
        'INSERT INTO transfers (id, date, from_account_id, to_account_id, '
        'amount, reference_number, notes, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          t.id,
          t.date.toIso8601String(),
          t.fromAccountId,
          t.toAccountId,
          t.amount,
          t.referenceNumber,
          t.notes,
          t.createdAt.toIso8601String(),
          t.updatedAt.toIso8601String(),
        ],
      );
    }
  }
}
