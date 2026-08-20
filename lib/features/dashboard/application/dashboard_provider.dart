import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../../accounts/application/accounts_provider.dart';
import '../../accounting_periods/application/periods_provider.dart';
import '../../transactions/domain/transaction_entry.dart';

/// Aggregated numbers shown at the top of the Dashboard.
class DashboardSummary {
  const DashboardSummary({
    required this.totalAvailableFunds,
    required this.beginningBalance,
    required this.totalMoneyIn,
    required this.totalMoneyOut,
    required this.hasOpenPeriod,
    this.periodName,
  });

  /// Sum of current balances across active cash/bank/e-wallet accounts
  /// (excludes credit cards / debit cards).
  final double totalAvailableFunds;

  /// The current open accounting period's beginning balance (0 if none).
  final double beginningBalance;

  /// The current open period's total income (0 if none).
  final double totalMoneyIn;

  /// The current open period's total expense (0 if none).
  final double totalMoneyOut;

  /// Whether there is currently an open accounting period.
  final bool hasOpenPeriod;

  /// Name of the current open period, if any.
  final String? periodName;

  double get netMovement => totalMoneyIn - totalMoneyOut;

  double get endingBalance => beginningBalance + totalMoneyIn - totalMoneyOut;
}

final _transactionDaoProvider = Provider<TransactionDao>(
  (ref) => TransactionDao(),
);

/// Combines the open accounting period's totals with total available funds
/// across accounts, kept live via [DbChangeNotifier].
final dashboardSummaryProvider = StreamProvider.autoDispose<DashboardSummary>((
  ref,
) async* {
  final periodDao = ref.watch(accountingPeriodDaoProvider);
  final transactionDao = ref.watch(_transactionDaoProvider);
  final accountDao = ref.watch(accountDaoProvider);

  await for (final _ in DbChangeNotifier.instance.watchAny([
    DbTable.accounts,
    DbTable.transactions,
    DbTable.transfers,
    DbTable.accountingPeriods,
  ])) {
    final openPeriod = await periodDao.getOpenPeriod();
    final accounts = await accountDao.getAll(activeOnly: true);
    final totalAvailableFunds = accounts
        .where((a) => a.type.countsTowardAvailableFunds)
        .fold<double>(0, (sum, a) => sum + a.currentBalance);

    double beginningBalance = 0;
    double totalMoneyIn = 0;
    double totalMoneyOut = 0;
    if (openPeriod != null && openPeriod.id != null) {
      beginningBalance = openPeriod.beginningBalance;
      totalMoneyIn = await transactionDao.sumIncomeForPeriod(openPeriod.id!);
      totalMoneyOut = await transactionDao.sumExpenseForPeriod(openPeriod.id!);
    }

    yield DashboardSummary(
      totalAvailableFunds: totalAvailableFunds,
      beginningBalance: beginningBalance,
      totalMoneyIn: totalMoneyIn,
      totalMoneyOut: totalMoneyOut,
      hasOpenPeriod: openPeriod != null,
      periodName: openPeriod?.name,
    );
  }
});

/// Last 5 transactions across all accounts, newest first, for the
/// Dashboard's "Recent Transactions" section.
///
/// NOTE: `lib/features/transactions/application/transactions_provider.dart`
/// (`transactionsFilteredProvider`) did not exist yet at the time this file
/// was written by a parallel agent — this is a minimal local fallback using
/// [TransactionDao.getFiltered] directly. Once that provider lands, this
/// can likely be dropped in favor of it (dedup candidate).
final recentTransactionsProvider =
    StreamProvider.autoDispose<List<TransactionEntry>>((ref) {
      final dao = ref.watch(_transactionDaoProvider);
      return DbChangeNotifier.instance
          .watchAny([DbTable.transactions])
          .asyncMap((_) async {
            final all = await dao.getFiltered();
            return all.take(5).toList();
          });
    });
