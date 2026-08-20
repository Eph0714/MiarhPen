import '../../../core/db/daos/transaction_dao.dart';
import '../../../core/db/daos/transfer_dao.dart';
import '../../transfers/domain/transfer.dart';
import '../domain/transaction_entry.dart';
import 'account_balance_recalculator.dart';

/// This is the single trusted write path for transactions and transfers —
/// UI code must never write to the transactions/transfers tables directly,
/// and must never write accounts.current_balance/outstanding_balance
/// directly. All balance mutation flows through
/// [AccountBalanceRecalculator.recalculateAccountBalance] so balances are
/// always re-derived from source records, never hand-incremented — this
/// prevents double-counting and drift bugs.
class TransactionRepository {
  TransactionRepository({
    TransactionDao? transactionDao,
    AccountBalanceRecalculator? recalculator,
    TransferDao? transferDao,
  })  : _transactionDao = transactionDao ?? TransactionDao(),
        _recalculator = recalculator ?? AccountBalanceRecalculator(),
        _transferDao = transferDao ?? TransferDao();

  final TransactionDao _transactionDao;
  final AccountBalanceRecalculator _recalculator;
  final TransferDao _transferDao;

  Future<int> addTransaction(TransactionEntry entry) async {
    if (entry.amount <= 0) {
      throw ArgumentError.value(
        entry.amount,
        'amount',
        'Transaction amount must be greater than zero',
      );
    }

    final id = await _transactionDao.insert(entry);
    await _recalculator.recalculateAccountBalance(entry.accountId);
    if (entry.accountingPeriodId != null) {
      await _recalculator.recalculatePeriodTotals(entry.accountingPeriodId!);
    }
    return id;
  }

  Future<void> updateTransaction(
    TransactionEntry oldEntry,
    TransactionEntry newEntry,
  ) async {
    if (newEntry.amount <= 0) {
      throw ArgumentError.value(
        newEntry.amount,
        'amount',
        'Transaction amount must be greater than zero',
      );
    }

    await _transactionDao.update(newEntry);

    final accountIds = <int>{oldEntry.accountId, newEntry.accountId};
    for (final accountId in accountIds) {
      await _recalculator.recalculateAccountBalance(accountId);
    }

    final periodIds = <int>{
      if (oldEntry.accountingPeriodId != null) oldEntry.accountingPeriodId!,
      if (newEntry.accountingPeriodId != null) newEntry.accountingPeriodId!,
    };
    for (final periodId in periodIds) {
      await _recalculator.recalculatePeriodTotals(periodId);
    }
  }

  Future<void> deleteTransaction(TransactionEntry entry) async {
    if (entry.id != null) {
      await _transactionDao.delete(entry.id!);
    }
    await _recalculator.recalculateAccountBalance(entry.accountId);
    if (entry.accountingPeriodId != null) {
      await _recalculator.recalculatePeriodTotals(entry.accountingPeriodId!);
    }
  }

  Future<int> addTransfer(Transfer transfer) async {
    _validateTransfer(transfer);

    final id = await _transferDao.insert(transfer);
    await _recalculator.recalculateAccountBalance(transfer.fromAccountId);
    await _recalculator.recalculateAccountBalance(transfer.toAccountId);
    return id;
  }

  Future<void> updateTransfer(
    Transfer oldTransfer,
    Transfer newTransfer,
  ) async {
    _validateTransfer(newTransfer);

    await _transferDao.update(newTransfer);

    final accountIds = <int>{
      oldTransfer.fromAccountId,
      oldTransfer.toAccountId,
      newTransfer.fromAccountId,
      newTransfer.toAccountId,
    };
    for (final accountId in accountIds) {
      await _recalculator.recalculateAccountBalance(accountId);
    }
  }

  Future<void> deleteTransfer(Transfer transfer) async {
    if (transfer.id != null) {
      await _transferDao.delete(transfer.id!);
    }
    await _recalculator.recalculateAccountBalance(transfer.fromAccountId);
    await _recalculator.recalculateAccountBalance(transfer.toAccountId);
  }

  void _validateTransfer(Transfer transfer) {
    if (transfer.amount <= 0) {
      throw ArgumentError.value(
        transfer.amount,
        'amount',
        'Transfer amount must be greater than zero',
      );
    }
    if (transfer.fromAccountId == transfer.toAccountId) {
      throw ArgumentError.value(
        transfer.toAccountId,
        'toAccountId',
        'Transfer source and destination accounts must differ',
      );
    }
  }
}
