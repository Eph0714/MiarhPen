import '../../../core/db/daos/account_dao.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../data/account_balance_recalculator.dart';

/// Repairs transactions left posted directly to a debit card account
/// instead of the bank account it's linked to — a debit card holds no
/// balance of its own (see `Account.isDebitCard`), so such a transaction
/// saved correctly and still counted in Money IN/OUT, but was invisible
/// to every balance figure derived from `accounts.current_balance` (Cash
/// in Bank, Cash On Hand's counterpart, Total Available Funds). The
/// account picker no longer offers debit cards for new entries, but this
/// fixes any that were already recorded that way before that change.
///
/// Only ever moves the `account_id` reference — amount, date,
/// description, category, and every other field on the transaction stay
/// exactly as entered. Safe to call repeatedly (idempotent: once nothing
/// is left posted to a debit card, later calls just find zero rows to
/// move) — same pattern as the app's other startup repair passes.
/// Returns the number of transactions moved.
Future<int> reassignDebitCardTransactionsIfNeeded() async {
  final accountDao = AccountDao();
  final transactionDao = TransactionDao();
  final recalculator = AccountBalanceRecalculator();

  final accounts = await accountDao.getAll();
  final debitCardsWithLinkedBank = accounts.where(
    (a) => a.isDebitCard && a.id != null && a.linkedAccountId != null,
  );

  var totalMoved = 0;
  for (final card in debitCardsWithLinkedBank) {
    final moved = await transactionDao.reassignAccountTransactions(
      fromAccountId: card.id!,
      toAccountId: card.linkedAccountId!,
    );
    if (moved > 0) {
      totalMoved += moved;
      // Both accounts' cached balances need to catch up with the rows
      // that just moved between them.
      await recalculator.recalculateAccountBalance(card.id!);
      await recalculator.recalculateAccountBalance(card.linkedAccountId!);
    }
  }
  return totalMoved;
}
