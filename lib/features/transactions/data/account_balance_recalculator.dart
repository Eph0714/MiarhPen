import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/account_dao.dart';
import '../../../core/db/daos/accounting_period_dao.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../../../core/db/daos/transfer_dao.dart';
import '../../../core/db/db_change_notifier.dart';

/// Re-derives cached balance fields from source records.
///
/// `accounts.current_balance` / `accounts.outstanding_balance` and
/// `accounting_periods.total_income` / `total_expense` are cached values —
/// this class is the only place that ever recomputes and writes them, always
/// from scratch off the transactions/transfers tables, never by hand-
/// incrementing. This prevents double-counting and drift bugs.
class AccountBalanceRecalculator {
  AccountBalanceRecalculator({
    AccountDao? accountDao,
    AccountingPeriodDao? accountingPeriodDao,
    TransactionDao? transactionDao,
    TransferDao? transferDao,
  }) : _accountDao = accountDao ?? AccountDao(),
       _accountingPeriodDao = accountingPeriodDao ?? AccountingPeriodDao(),
       _transactionDao = transactionDao ?? TransactionDao(),
       _transferDao = transferDao ?? TransferDao();

  final AccountDao _accountDao;
  final AccountingPeriodDao _accountingPeriodDao;
  final TransactionDao _transactionDao;
  final TransferDao _transferDao;

  Future<void> recalculateAccountBalance(int accountId) async {
    final account = await _accountDao.getById(accountId);
    if (account == null) return;

    final incomeTotal = await _transactionDao.sumIncomeForAccount(accountId);
    final expenseTotal = await _transactionDao.sumExpenseForAccount(accountId);
    final transfersIn = await _transferDao.sumTransfersInForAccount(accountId);
    final transfersOut = await _transferDao.sumTransfersOutForAccount(
      accountId,
    );

    final newBalance =
        account.beginningBalance +
        incomeTotal -
        expenseTotal +
        transfersIn -
        transfersOut;

    double? outstandingBalance;
    if (account.type == AccountType.creditCard) {
      // Purchases (expenses posted to the card) increase the liability;
      // payments (income-type transactions posted to the card) decrease
      // it. No clamping — an overpayment can legitimately go negative.
      outstandingBalance = expenseTotal - incomeTotal;
    }

    await _accountDao.updateBalanceFields(
      accountId,
      currentBalance: newBalance,
      outstandingBalance: outstandingBalance,
    );
    DbChangeNotifier.instance.notify(DbTable.accounts);
  }

  Future<void> recalculatePeriodTotals(int periodId) async {
    final period = await _accountingPeriodDao.getById(periodId);
    if (period == null) return;

    final totalIncome = await _transactionDao.sumIncomeForPeriod(periodId);
    final totalExpense = await _transactionDao.sumExpenseForPeriod(periodId);

    await _accountingPeriodDao.update(
      period.copyWith(totalIncome: totalIncome, totalExpense: totalExpense),
    );
    DbChangeNotifier.instance.notify(DbTable.accountingPeriods);
  }
}
