import '../../../core/db/daos/accounting_period_dao.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../data/account_balance_recalculator.dart';

/// Repairs transactions saved before a bug fix that left new entries
/// with no accounting period reference (see [TransactionDao.
/// backfillMissingAccountingPeriod] for the full explanation). Safe to
/// call on every app start: once every transaction has a period id,
/// there's nothing left to fix and this is a fast no-op query. Only
/// fills in the missing reference — never changes amounts, dates, or
/// any other field on existing records.
Future<void> backfillTransactionPeriodsIfNeeded() async {
  final periodDao = AccountingPeriodDao();
  final openPeriod = await periodDao.getOpenPeriod();
  if (openPeriod?.id == null) return;

  final fixedCount = await TransactionDao().backfillMissingAccountingPeriod(
    openPeriod!.id!,
  );
  if (fixedCount > 0) {
    await AccountBalanceRecalculator().recalculatePeriodTotals(openPeriod.id!);
  }
}
