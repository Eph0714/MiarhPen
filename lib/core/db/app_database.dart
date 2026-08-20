import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../constants/app_constants.dart';

/// Raw-SQL SQLite schema, source of truth for spec §34.
///
/// current_balance / outstanding_balance columns on `accounts` are cached
/// values that only [AccountBalanceRecalculator] (in the transactions
/// feature) ever writes — always re-derived from beginning_balance + the
/// sum of transactions/transfers, never hand-edited by UI code. See plan
/// §"Tech Decisions" for the rationale.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;
  Future<Database>? _opening;

  // Memoizes the in-flight *Future*, not just the resolved Database. The
  // previous version only checked `if (_db != null)` before starting
  // `_open()`, which is a classic check-then-act race: on first-ever
  // launch, multiple call sites (e.g. app.dart's startup category seeding
  // and the onboarding screen's own provider reads) can all call this
  // getter before the first `_open()` has finished, each seeing `_db ==
  // null` and each kicking off its own concurrent `openDatabase()` call
  // against the same file. Two concurrent opens of the same SQLite file
  // while the first is still running its `onCreate` schema batch can hang
  // indefinitely (this is what caused "Finish Setup" to freeze forever on
  // a fresh install — the wizard's DB transaction never got a connection
  // back). Caching the Future itself means every caller, no matter how
  // many arrive before the first open completes, awaits the exact same
  // single `_open()` call.
  Future<Database> get database {
    return _opening ??= _open().then((db) {
      _db = db;
      return db;
    });
  }

  Future<Database> _open() async {
    // Desktop test runs (no Android/iOS platform) need the FFI backend.
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.dbFileName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Additive-only: never drops/rewrites existing tables or rows.
        if (oldVersion < 2) {
          await _createRecurringPaymentsTable(db);
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        password_salt TEXT,
        pin_hash TEXT,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        remember_me INTEGER NOT NULL DEFAULT 0,
        session_timeout_min INTEGER NOT NULL DEFAULT 5,
        currency_code TEXT NOT NULL DEFAULT 'PHP',
        currency_symbol TEXT NOT NULL DEFAULT '₱',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE accounting_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        beginning_balance REAL NOT NULL DEFAULT 0,
        total_income REAL NOT NULL DEFAULT 0,
        total_expense REAL NOT NULL DEFAULT 0,
        ending_balance REAL,
        status TEXT NOT NULL DEFAULT 'OPEN',
        created_at TEXT NOT NULL,
        closed_at TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_periods_status ON accounting_periods(status)',
    );

    batch.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        beginning_balance REAL NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        credit_limit REAL,
        outstanding_balance REAL,
        statement_date INTEGER,
        due_date INTEGER,
        linked_account_id INTEGER REFERENCES accounts(id),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_accounts_type ON accounts(type)');
    batch.execute('CREATE INDEX idx_accounts_active ON accounts(is_active)');

    batch.execute('''
      CREATE TABLE income_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        income_category_id INTEGER REFERENCES income_categories(id),
        expense_category_id INTEGER REFERENCES expense_categories(id),
        amount REAL NOT NULL CHECK (amount > 0),
        description TEXT,
        reference_number TEXT,
        notes TEXT,
        attachment_path TEXT,
        accounting_period_id INTEGER REFERENCES accounting_periods(id),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_txn_account ON transactions(account_id)');
    batch.execute('CREATE INDEX idx_txn_date ON transactions(date)');
    batch.execute('CREATE INDEX idx_txn_type ON transactions(type)');
    batch.execute(
      'CREATE INDEX idx_txn_income_cat ON transactions(income_category_id)',
    );
    batch.execute(
      'CREATE INDEX idx_txn_expense_cat ON transactions(expense_category_id)',
    );
    batch.execute(
      'CREATE INDEX idx_txn_period ON transactions(accounting_period_id)',
    );

    batch.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        from_account_id INTEGER NOT NULL REFERENCES accounts(id),
        to_account_id INTEGER NOT NULL REFERENCES accounts(id),
        amount REAL NOT NULL CHECK (amount > 0),
        reference_number TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK (from_account_id != to_account_id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_transfer_from ON transfers(from_account_id)',
    );
    batch.execute('CREATE INDEX idx_transfer_to ON transfers(to_account_id)');
    batch.execute('CREATE INDEX idx_transfer_date ON transfers(date)');

    await batch.commit(noResult: true);
    await _createRecurringPaymentsTable(db);
  }

  /// Schedule of recurring payments (e.g. "Payment of Housing Loan, every 6
  /// of the month, 08:00 AM - 05:00 PM, Unpaid"). Introduced in schema v2;
  /// created both on fresh installs (from [_createSchema]) and via
  /// [onUpgrade] for existing installs, so no one loses this table just
  /// because they installed before it existed. Purely additive — does not
  /// touch any other table.
  Future<void> _createRecurringPaymentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        amount REAL,
        account_id INTEGER REFERENCES accounts(id),
        expense_category_id INTEGER REFERENCES expense_categories(id),
        day_of_month INTEGER NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
        start_time TEXT,
        end_time TEXT,
        status TEXT NOT NULL DEFAULT 'UNPAID',
        is_active INTEGER NOT NULL DEFAULT 1,
        last_paid_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recurring_payments_active '
      'ON recurring_payments(is_active)',
    );
  }

  /// Closes and clears the cached instance/in-flight open — used by
  /// restore-from-backup (which overwrites the DB file and needs the next
  /// `database` access to reopen it) and by tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _opening = null;
  }
}
