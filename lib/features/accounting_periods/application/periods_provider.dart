import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/accounting_period_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../../transactions/data/account_balance_recalculator.dart';
import '../domain/accounting_period.dart';

final accountingPeriodDaoProvider = Provider<AccountingPeriodDao>(
  (ref) => AccountingPeriodDao(),
);

/// All accounting periods, newest (by start date) first.
final periodsStreamProvider =
    StreamProvider.autoDispose<List<AccountingPeriod>>((ref) {
      final dao = ref.watch(accountingPeriodDaoProvider);
      return DbChangeNotifier.instance
          .watch(DbTable.accountingPeriods)
          .asyncMap((_) => dao.getAll());
    });

/// The currently open accounting period, if any. MiarhPen has at most one
/// open period at a time.
final openPeriodProvider = StreamProvider.autoDispose<AccountingPeriod?>((ref) {
  final dao = ref.watch(accountingPeriodDaoProvider);
  return DbChangeNotifier.instance
      .watch(DbTable.accountingPeriods)
      .asyncMap((_) => dao.getOpenPeriod());
});

/// A single period by id, kept live via the accountingPeriods table stream.
final periodByIdProvider = StreamProvider.autoDispose
    .family<AccountingPeriod?, int>((ref, id) {
      final dao = ref.watch(accountingPeriodDaoProvider);
      return DbChangeNotifier.instance
          .watch(DbTable.accountingPeriods)
          .asyncMap((_) => dao.getById(id));
    });

/// Handles closing an open period and opening a new one.
class ClosePeriodController {
  ClosePeriodController(this._dao, this._recalculator);

  final AccountingPeriodDao _dao;
  final AccountBalanceRecalculator _recalculator;

  /// Freezes a period's ending balance. Recalculates totals from source
  /// transactions first so the close reflects everything posted to the
  /// period, then computes `endingBalance = beginningBalance + totalIncome
  /// - totalExpense` and writes it via [AccountingPeriodDao.closePeriod].
  Future<void> closePeriod(int periodId) async {
    await _recalculator.recalculatePeriodTotals(periodId);
    final refreshed = await _dao.getById(periodId);
    if (refreshed == null) return;
    final endingBalance =
        refreshed.beginningBalance +
        refreshed.totalIncome -
        refreshed.totalExpense;
    await _dao.closePeriod(periodId, DateTime.now(), endingBalance);
  }

  /// Opens a new accounting period. Whether the previous period's ending
  /// balance is carried over as this period's [beginningBalance] is a UI
  /// decision — callers should pass it in explicitly rather than this
  /// method inferring/hardcoding anything.
  Future<int> openNewPeriod({
    required String name,
    required DateTime startDate,
    required double beginningBalance,
  }) async {
    final now = DateTime.now();
    final period = AccountingPeriod(
      name: name,
      startDate: startDate,
      beginningBalance: beginningBalance,
      createdAt: now,
    );
    return _dao.insert(period);
  }

  /// Directly sets an open period's beginning balance — e.g. to correct a
  /// wrong figure entered when the period was opened, without having to
  /// reverse-engineer it through an unrelated account correction (see
  /// [AccountFormController.adjustBeginningBalance] for that other path,
  /// which nudges this same field by a delta rather than setting it
  /// outright). Ending Balance is derived live from this field plus
  /// income/expense while the period stays open, so it updates
  /// automatically — nothing else to recompute here.
  Future<void> setBeginningBalance(
    int periodId,
    double newBeginningBalance,
  ) async {
    final period = await _dao.getById(periodId);
    if (period == null) return;
    await _dao.update(period.copyWith(beginningBalance: newBeginningBalance));
  }
}

final closePeriodControllerProvider = Provider<ClosePeriodController>((ref) {
  return ClosePeriodController(
    ref.watch(accountingPeriodDaoProvider),
    AccountBalanceRecalculator(),
  );
});
