import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/account_dao.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../../../core/db/daos/transfer_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../domain/account_statement.dart';
import 'report_filters.dart';

final _statementAccountDaoProvider = Provider<AccountDao>(
  (ref) => AccountDao(),
);
final _statementTransactionDaoProvider = Provider<TransactionDao>(
  (ref) => TransactionDao(),
);
final _statementTransferDaoProvider = Provider<TransferDao>(
  (ref) => TransferDao(),
);

/// One account's full statement (running balance, day by day, income and
/// expense transactions plus transfer legs all interleaved by date) for
/// a [ReportDateFilter]'s resolved range.
///
/// The whole account's history (not just the selected range) is walked
/// once, oldest to newest, to build a continuous running balance —
/// exactly the same reasoning as `dailyBalanceReportProvider`: a
/// "Beginning Balance" for the selected range has to be whatever the
/// account's true balance already was the moment before that range
/// starts, which can only be known by replaying everything before it.
/// The range then just selects which already-computed rows to show.
final accountStatementProvider = StreamProvider.autoDispose
    .family<AccountStatement, ({int accountId, ReportDateFilter filter})>((
      ref,
      arg,
    ) {
      final accountDao = ref.watch(_statementAccountDaoProvider);
      final txnDao = ref.watch(_statementTransactionDaoProvider);
      final transferDao = ref.watch(_statementTransferDaoProvider);
      final range = arg.filter.resolve();

      return DbChangeNotifier.instance
          .watchAny([DbTable.transactions, DbTable.transfers, DbTable.accounts])
          .asyncMap((_) async {
            final account = await accountDao.getById(arg.accountId);
            if (account == null) {
              return const AccountStatement(
                accountName: 'Unknown Account',
                summary: AccountStatementSummary(
                  beginningBalance: 0,
                  endingBalance: 0,
                  totalCashIn: 0,
                  totalCashOut: 0,
                ),
                rows: [],
              );
            }

            final entries = await txnDao.getFiltered(accountId: arg.accountId);
            final transfers = await transferDao.getForAccount(arg.accountId);

            // Normalize transactions + transfer legs into one ledger, each
            // tagged with a stable (date, id) sort key so same-day entries
            // land in the order they were actually recorded, not
            // arbitrarily.
            final ledger =
                <
                  ({
                    DateTime date,
                    int id,
                    String description,
                    double cashIn,
                    double cashOut,
                  })
                >[];
            for (final e in entries) {
              final label = (e.description?.isNotEmpty ?? false)
                  ? e.description!
                  : (e.isIncome ? 'Income' : 'Expense');
              ledger.add((
                date: e.date,
                id: e.id ?? 0,
                description: label,
                cashIn: e.isIncome ? e.amount : 0,
                cashOut: e.isExpense ? e.amount : 0,
              ));
            }
            for (final t in transfers) {
              final label = (t.notes?.isNotEmpty ?? false)
                  ? t.notes!
                  : 'Transfer';
              if (t.toAccountId == arg.accountId) {
                ledger.add((
                  date: t.date,
                  id: t.id ?? 0,
                  description: '$label (Transfer In)',
                  cashIn: t.amount,
                  cashOut: 0,
                ));
              }
              if (t.fromAccountId == arg.accountId) {
                ledger.add((
                  date: t.date,
                  id: t.id ?? 0,
                  description: '$label (Transfer Out)',
                  cashIn: 0,
                  cashOut: t.amount,
                ));
              }
            }
            ledger.sort((a, b) {
              final byDate = a.date.compareTo(b.date);
              return byDate != 0 ? byDate : a.id.compareTo(b.id);
            });

            final start = DateTime(
              range.start.year,
              range.start.month,
              range.start.day,
            );
            final end = DateTime(
              range.end.year,
              range.end.month,
              range.end.day,
              23,
              59,
              59,
            );

            var running = account.beginningBalance;
            double beginningBalanceForRange = account.beginningBalance;
            var sawFirstRowInRange = false;
            final rows = <AccountStatementRow>[];
            double totalCashIn = 0;
            double totalCashOut = 0;

            for (final line in ledger) {
              final isBeforeRange = line.date.isBefore(start);
              running = running + line.cashIn - line.cashOut;
              if (isBeforeRange) {
                beginningBalanceForRange = running;
                continue;
              }
              if (line.date.isAfter(end)) continue;
              sawFirstRowInRange = true;
              totalCashIn += line.cashIn;
              totalCashOut += line.cashOut;
              rows.add(
                AccountStatementRow(
                  date: line.date,
                  description: line.description,
                  cashIn: line.cashIn,
                  cashOut: line.cashOut,
                  balance: running,
                ),
              );
            }

            final endingBalance = sawFirstRowInRange
                ? rows.last.balance
                : beginningBalanceForRange;

            return AccountStatement(
              accountName: account.name,
              summary: AccountStatementSummary(
                beginningBalance: beginningBalanceForRange,
                endingBalance: endingBalance,
                totalCashIn: totalCashIn,
                totalCashOut: totalCashOut,
              ),
              rows: rows,
            );
          });
    });
