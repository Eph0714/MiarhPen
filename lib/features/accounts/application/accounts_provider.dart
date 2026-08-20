import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/account_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../../transactions/data/account_balance_recalculator.dart';
import '../domain/account.dart';

final accountDaoProvider = Provider<AccountDao>((ref) => AccountDao());

final accountBalanceRecalculatorProvider = Provider<AccountBalanceRecalculator>(
  (ref) => AccountBalanceRecalculator(),
);

/// All accounts, optionally filtered to active-only via the family param.
final accountsStreamProvider = StreamProvider.autoDispose
    .family<List<Account>, bool>((ref, activeOnly) {
      final dao = ref.watch(accountDaoProvider);
      return DbChangeNotifier.instance
          .watch(DbTable.accounts)
          .asyncMap((_) => dao.getAll(activeOnly: activeOnly));
    });

/// Convenience provider for pickers: active accounts only, no family needed.
final activeAccountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  final dao = ref.watch(accountDaoProvider);
  return DbChangeNotifier.instance
      .watch(DbTable.accounts)
      .asyncMap((_) => dao.getAll(activeOnly: true));
});

/// Single account by id, kept live via the accounts table stream.
final accountByIdProvider = StreamProvider.autoDispose.family<Account?, int>((
  ref,
  id,
) {
  final dao = ref.watch(accountDaoProvider);
  return DbChangeNotifier.instance
      .watch(DbTable.accounts)
      .asyncMap((_) => dao.getById(id));
});

/// Sum of currentBalance across active accounts whose type counts toward
/// "Total Available Funds" (excludes credit cards and debit cards — see
/// [AccountTypeX.countsTowardAvailableFunds]).
final totalAvailableFundsProvider = Provider.autoDispose<AsyncValue<double>>((
  ref,
) {
  final accounts = ref.watch(accountsStreamProvider(false));
  return accounts.whenData((list) {
    return list
        .where((a) => a.isActive && a.type.countsTowardAvailableFunds)
        .fold<double>(0, (sum, a) => sum + a.currentBalance);
  });
});

/// Handles account create/update/disable. Mutations rely on the DAO's own
/// [DbChangeNotifier] calls to refresh the streams above — no manual
/// invalidation needed.
class AccountFormController {
  AccountFormController(this._dao, this._recalculator);

  final AccountDao _dao;
  final AccountBalanceRecalculator _recalculator;

  Future<void> createAccount({
    required String name,
    required AccountType type,
    String? description,
    double beginningBalance = 0,
    double? creditLimit,
    int? statementDate,
    int? dueDate,
    int? linkedAccountId,
  }) async {
    final now = DateTime.now();
    final account = Account(
      name: name,
      type: type,
      description: description,
      beginningBalance: beginningBalance,
      currentBalance: beginningBalance,
      creditLimit: type == AccountType.creditCard ? creditLimit : null,
      outstandingBalance: type == AccountType.creditCard ? 0 : null,
      statementDate: type == AccountType.creditCard ? statementDate : null,
      dueDate: type == AccountType.creditCard ? dueDate : null,
      linkedAccountId: type == AccountType.debitCard ? linkedAccountId : null,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _dao.insert(account);
    await _recalculator.recalculateAccountBalance(id);
  }

  /// Updates non-balance fields only — currentBalance/outstandingBalance are
  /// never touched here; they are only ever written by the recalculator.
  Future<void> updateAccount(
    Account existing, {
    String? name,
    AccountType? type,
    String? description,
    double? creditLimit,
    int? statementDate,
    int? dueDate,
    int? linkedAccountId,
  }) async {
    final resolvedType = type ?? existing.type;
    // Built directly (not via copyWith) because copyWith's `??` pattern
    // cannot null out a field — we need type-conditional fields to become
    // null outright when the account's type no longer uses them.
    final updated = Account(
      id: existing.id,
      name: name ?? existing.name,
      type: resolvedType,
      description: description ?? existing.description,
      beginningBalance: existing.beginningBalance,
      currentBalance: existing.currentBalance,
      creditLimit: resolvedType == AccountType.creditCard
          ? (creditLimit ?? existing.creditLimit)
          : null,
      outstandingBalance: existing.outstandingBalance,
      statementDate: resolvedType == AccountType.creditCard
          ? (statementDate ?? existing.statementDate)
          : null,
      dueDate: resolvedType == AccountType.creditCard
          ? (dueDate ?? existing.dueDate)
          : null,
      linkedAccountId: resolvedType == AccountType.debitCard
          ? (linkedAccountId ?? existing.linkedAccountId)
          : null,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await _dao.update(updated);
  }

  Future<void> disableAccount(int id) async {
    await _dao.disable(id);
  }

  Future<void> activateAccount(int id) async {
    await _dao.activate(id);
  }

  /// The only sanctioned way to correct an account's starting figure
  /// after creation. Unlike a raw balance edit, this stays honest: it
  /// updates the stored `beginning_balance` fact, then hands off to the
  /// same recalculator every transaction/transfer write already goes
  /// through, so `currentBalance` is always re-derived from
  /// beginning_balance + transaction history — never hand-set — and stays
  /// consistent with every account-detail/report screen that reads it.
  Future<void> adjustBeginningBalance(
    Account existing,
    double newBeginningBalance,
  ) async {
    final updated = Account(
      id: existing.id,
      name: existing.name,
      type: existing.type,
      description: existing.description,
      beginningBalance: newBeginningBalance,
      currentBalance: existing.currentBalance,
      creditLimit: existing.creditLimit,
      outstandingBalance: existing.outstandingBalance,
      statementDate: existing.statementDate,
      dueDate: existing.dueDate,
      linkedAccountId: existing.linkedAccountId,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await _dao.update(updated);
    final id = existing.id;
    if (id != null) {
      await _recalculator.recalculateAccountBalance(id);
    }
  }
}

final accountFormControllerProvider = Provider<AccountFormController>((ref) {
  return AccountFormController(
    ref.watch(accountDaoProvider),
    ref.watch(accountBalanceRecalculatorProvider),
  );
});
