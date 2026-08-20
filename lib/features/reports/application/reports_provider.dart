import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/charts/chart_datum.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/account_dao.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../../../core/db/daos/transfer_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../../accounts/domain/account.dart';
import 'report_filters.dart';

final _reportTransactionDaoProvider = Provider<TransactionDao>(
  (ref) => TransactionDao(),
);
final _reportTransferDaoProvider = Provider<TransferDao>(
  (ref) => TransferDao(),
);
final _reportAccountDaoProvider = Provider<AccountDao>((ref) => AccountDao());

/// Summary figures for the Financial Summary report.
///
/// [beginningBalance] is always 0: a true beginning balance requires an
/// accounting-period context (an explicit opening balance for the selected
/// range), which this generic date-range report does not assume. Callers
/// that need a real beginning balance should source it from the accounting
/// periods feature instead.
class FinancialSummary {
  final double totalIncome;
  final double totalExpense;
  final double netMovement;
  final double beginningBalance;

  const FinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netMovement,
    this.beginningBalance = 0,
  });

  /// Ending-balance equivalent for the period: totalIncome - totalExpense
  /// (relative to [beginningBalance], which is 0 for this report).
  double get endingBalance => beginningBalance + netMovement;
}

/// Every report provider below is a [StreamProvider], not a plain
/// [FutureProvider] — Reports must stay live in the background the same
/// way the Dashboard already does. A `FutureProvider.family` only
/// recomputes when its filter argument changes or the provider is torn
/// down and rebuilt; it does *not* notice a transaction/account/transfer
/// changing underneath it elsewhere in the app (e.g. correcting an
/// account's beginning balance while a report screen is still mounted),
/// so a report could silently keep showing stale figures. Subscribing to
/// [DbChangeNotifier] for the relevant tables — exactly like
/// `dashboardSummaryProvider` — closes that gap.
final financialSummaryProvider = StreamProvider.autoDispose
    .family<FinancialSummary, ReportDateFilter>((ref, filter) {
      final dao = ref.watch(_reportTransactionDaoProvider);
      final range = filter.resolve();
      return DbChangeNotifier.instance.watch(DbTable.transactions).asyncMap((
        _,
      ) async {
        final incomeEntries = await dao.getFiltered(
          from: range.start,
          to: range.end,
          type: TransactionType.income,
        );
        final expenseEntries = await dao.getFiltered(
          from: range.start,
          to: range.end,
          type: TransactionType.expense,
        );

        final totalIncome = incomeEntries.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );
        final totalExpense = expenseEntries.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

        return FinancialSummary(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          netMovement: totalIncome - totalExpense,
        );
      });
    });

final incomeByCategoryProvider = StreamProvider.autoDispose
    .family<List<ChartDatum>, ReportDateFilter>((ref, filter) {
      final dao = ref.watch(_reportTransactionDaoProvider);
      final range = filter.resolve();
      return DbChangeNotifier.instance
          .watchAny([DbTable.transactions, DbTable.incomeCategories])
          .asyncMap((_) async {
            final rows = await dao.sumByCategory(
              income: true,
              from: range.start,
              to: range.end,
            );
            return rows
                .map(
                  (r) => ChartDatum(
                    label: r['category_name'] as String? ?? 'Uncategorized',
                    value: (r['total'] as num?)?.toDouble() ?? 0,
                  ),
                )
                .toList();
          });
    });

final expenseByCategoryProvider = StreamProvider.autoDispose
    .family<List<ChartDatum>, ReportDateFilter>((ref, filter) {
      final dao = ref.watch(_reportTransactionDaoProvider);
      final range = filter.resolve();
      return DbChangeNotifier.instance
          .watchAny([DbTable.transactions, DbTable.expenseCategories])
          .asyncMap((_) async {
            final rows = await dao.sumByCategory(
              income: false,
              from: range.start,
              to: range.end,
            );
            return rows
                .map(
                  (r) => ChartDatum(
                    label: r['category_name'] as String? ?? 'Uncategorized',
                    value: (r['total'] as num?)?.toDouble() ?? 0,
                  ),
                )
                .toList();
          });
    });

/// One [ChartDatum] per active account counted toward available funds
/// (excludes credit cards and debit cards — see
/// [AccountTypeX.countsTowardAvailableFunds]).
final accountDistributionProvider =
    StreamProvider.autoDispose<List<ChartDatum>>((ref) {
      final dao = ref.watch(_reportAccountDaoProvider);
      return DbChangeNotifier.instance.watch(DbTable.accounts).asyncMap((
        _,
      ) async {
        final accounts = await dao.getAll(activeOnly: true);
        return accounts
            .where((a) => a.type.countsTowardAvailableFunds)
            .map((a) => ChartDatum(label: a.name, value: a.currentBalance))
            .toList();
      });
    });

/// A single row in the Money In/Out report: one transaction or one leg of a
/// transfer, normalized to a common shape for display.
class MoneyInOutRow {
  final DateTime date;
  final String accountName;
  final String type; // INCOME / EXPENSE / TRANSFER IN / TRANSFER OUT
  final String? description;
  final double amount;

  /// Extra identifiers (not part of the display shape) kept so the report
  /// screen can drive its account/category filter dropdowns without a
  /// second round-trip. Null for transfer legs (no category applies).
  final int? accountId;
  final int? categoryId;

  const MoneyInOutRow({
    required this.date,
    required this.accountName,
    required this.type,
    required this.amount,
    this.description,
    this.accountId,
    this.categoryId,
  });
}

final moneyInOutRowsProvider = StreamProvider.autoDispose
    .family<List<MoneyInOutRow>, ReportDateFilter>((ref, filter) {
      final txnDao = ref.watch(_reportTransactionDaoProvider);
      final transferDao = ref.watch(_reportTransferDaoProvider);
      final accountDao = ref.watch(_reportAccountDaoProvider);
      final range = filter.resolve();

      return DbChangeNotifier.instance
          .watchAny([DbTable.transactions, DbTable.transfers, DbTable.accounts])
          .asyncMap((_) async {
            final accounts = await accountDao.getAll();
            final accountNames = {for (final a in accounts) a.id: a.name};
            String nameFor(int? id) => accountNames[id] ?? 'Unknown';

            final entries = await txnDao.getFiltered(
              from: range.start,
              to: range.end,
            );
            final transfers = await transferDao.getAll(
              from: range.start,
              to: range.end,
            );

            final rows = <MoneyInOutRow>[
              for (final e in entries)
                MoneyInOutRow(
                  date: e.date,
                  accountName: nameFor(e.accountId),
                  type: e.isIncome ? 'INCOME' : 'EXPENSE',
                  description: e.description,
                  amount: e.amount,
                  accountId: e.accountId,
                  categoryId: e.categoryId,
                ),
              for (final t in transfers) ...[
                MoneyInOutRow(
                  date: t.date,
                  accountName: nameFor(t.fromAccountId),
                  type: 'TRANSFER OUT',
                  description: t.notes,
                  amount: t.amount,
                  accountId: t.fromAccountId,
                ),
                MoneyInOutRow(
                  date: t.date,
                  accountName: nameFor(t.toAccountId),
                  type: 'TRANSFER IN',
                  description: t.notes,
                  amount: t.amount,
                  accountId: t.toAccountId,
                ),
              ],
            ];

            rows.sort((a, b) => b.date.compareTo(a.date));
            return rows;
          });
    });

/// One row per active account for the Account Report: totals in/out over
/// the resolved date range (transactions + transfer legs) plus the
/// account's live current balance.
class AccountReportRow {
  final Account account;
  final double totalIn;
  final double totalOut;
  final double currentBalance;

  const AccountReportRow({
    required this.account,
    required this.totalIn,
    required this.totalOut,
    required this.currentBalance,
  });
}

final accountReportProvider = StreamProvider.autoDispose
    .family<List<AccountReportRow>, ReportDateFilter>((ref, filter) {
      final accountDao = ref.watch(_reportAccountDaoProvider);
      final txnDao = ref.watch(_reportTransactionDaoProvider);
      final transferDao = ref.watch(_reportTransferDaoProvider);
      final range = filter.resolve();

      return DbChangeNotifier.instance
          .watchAny([DbTable.accounts, DbTable.transactions, DbTable.transfers])
          .asyncMap((_) async {
            final accounts = await accountDao.getAll(activeOnly: true);
            final rows = <AccountReportRow>[];

            for (final account in accounts) {
              final id = account.id;
              if (id == null) continue;

              final incomeEntries = await txnDao.getFiltered(
                from: range.start,
                to: range.end,
                accountId: id,
                type: TransactionType.income,
              );
              final expenseEntries = await txnDao.getFiltered(
                from: range.start,
                to: range.end,
                accountId: id,
                type: TransactionType.expense,
              );
              final transfers = await transferDao.getForAccount(id);
              final periodTransfers = transfers.where(
                (t) =>
                    !t.date.isBefore(range.start) && !t.date.isAfter(range.end),
              );

              final incomeTotal = incomeEntries.fold<double>(
                0,
                (sum, e) => sum + e.amount,
              );
              final transfersIn = periodTransfers
                  .where((t) => t.toAccountId == id)
                  .fold<double>(0, (sum, t) => sum + t.amount);
              final expenseTotal = expenseEntries.fold<double>(
                0,
                (sum, e) => sum + e.amount,
              );
              final transfersOut = periodTransfers
                  .where((t) => t.fromAccountId == id)
                  .fold<double>(0, (sum, t) => sum + t.amount);

              rows.add(
                AccountReportRow(
                  account: account,
                  totalIn: incomeTotal + transfersIn,
                  totalOut: expenseTotal + transfersOut,
                  currentBalance: account.currentBalance,
                ),
              );
            }

            return rows;
          });
    });
