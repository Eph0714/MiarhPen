import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/accounting_period_dao.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../../../core/utils/validators.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_entry.dart';
import 'transaction_filter.dart';

final transactionDaoProvider = Provider<TransactionDao>(
  (ref) => TransactionDao(),
);

final _accountingPeriodDaoProvider = Provider<AccountingPeriodDao>(
  (ref) => AccountingPeriodDao(),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(),
);

/// Transactions matching [filter], newest first. When [filter.categoryId]
/// is set but [filter.type] is not, the DAO query can't discriminate which
/// of the two category columns to match against, so that case is filtered
/// client-side after fetching (matches either income or expense category id).
final transactionsFilteredProvider = StreamProvider.autoDispose
    .family<List<TransactionEntry>, TransactionFilter>((ref, filter) {
      final dao = ref.watch(transactionDaoProvider);
      return DbChangeNotifier.instance
          .watchAny([DbTable.transactions, DbTable.transfers])
          .asyncMap((_) async {
            final results = await dao.getFiltered(
              from: filter.dateFrom,
              to: filter.dateTo,
              accountId: filter.accountId,
              incomeCategoryId: filter.type == TransactionType.income
                  ? filter.categoryId
                  : null,
              expenseCategoryId: filter.type == TransactionType.expense
                  ? filter.categoryId
                  : null,
              type: filter.type,
              searchText: filter.searchText,
            );
            if (filter.categoryId != null && filter.type == null) {
              return results
                  .where((e) => e.categoryId == filter.categoryId)
                  .toList();
            }
            return results;
          });
    });

/// Single transaction by id, kept live via the transactions table stream.
final transactionByIdProvider = StreamProvider.autoDispose
    .family<TransactionEntry?, int>((ref, id) {
      final dao = ref.watch(transactionDaoProvider);
      return DbChangeNotifier.instance
          .watch(DbTable.transactions)
          .asyncMap((_) => dao.getById(id));
    });

/// Sum of money in (income) vs. money out (expense) among transactions
/// matching [filter].
final moneyInOutSummaryProvider = Provider.autoDispose
    .family<AsyncValue<({double moneyIn, double moneyOut})>, TransactionFilter>(
      (ref, filter) {
        final entries = ref.watch(transactionsFilteredProvider(filter));
        return entries.whenData((list) {
          double moneyIn = 0;
          double moneyOut = 0;
          for (final e in list) {
            if (e.isIncome) {
              moneyIn += e.amount;
            } else {
              moneyOut += e.amount;
            }
          }
          return (moneyIn: moneyIn, moneyOut: moneyOut);
        });
      },
    );

/// Handles create/update/delete for income & expense entries. Builds a
/// [TransactionEntry] from raw form values (setting incomeCategoryId /
/// expenseCategoryId appropriately based on [isIncome]) and routes every
/// write through [TransactionRepository] — the single trusted write path.
class AddTransactionController extends AsyncNotifier<void> {
  DateTime? _lastSubmitAt;

  @override
  void build() {}

  TransactionRepository get _repository =>
      ref.read(transactionRepositoryProvider);

  Future<void> submit({
    required bool isIncome,
    required DateTime date,
    required int accountId,
    required int categoryId,
    required double amount,
    String? description,
    String? referenceNumber,
    String? notes,
    String? attachmentPath,
    int? accountingPeriodId,
    TransactionEntry? editing,
  }) async {
    if (isDuplicateSubmitGuardTripped(_lastSubmitAt)) return;
    _lastSubmitAt = DateTime.now();

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();

      // The entry form only ever passes a non-null accountingPeriodId when
      // *editing* an entry that already had one (it reads
      // `widget.editing?.accountingPeriodId`) — a brand-new entry always
      // arrived here with accountingPeriodId == null, which meant it was
      // invisible to the dashboard's period-scoped Money In/Out/Net
      // Movement/Ending Balance sums (those filter strictly by
      // accounting_period_id). Backfill it from the currently open period
      // so new entries are actually counted.
      final resolvedPeriodId =
          accountingPeriodId ??
          (await ref.read(_accountingPeriodDaoProvider).getOpenPeriod())?.id;

      final entry = TransactionEntry(
        id: editing?.id,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        date: date,
        accountId: accountId,
        incomeCategoryId: isIncome ? categoryId : null,
        expenseCategoryId: isIncome ? null : categoryId,
        amount: amount,
        description: description,
        referenceNumber: referenceNumber,
        notes: notes,
        attachmentPath: attachmentPath,
        accountingPeriodId: resolvedPeriodId,
        createdAt: editing?.createdAt ?? now,
        updatedAt: now,
      );

      if (editing != null) {
        await _repository.updateTransaction(editing, entry);
      } else {
        await _repository.addTransaction(entry);
      }
    });
  }

  Future<void> delete(TransactionEntry entry) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.deleteTransaction(entry));
  }
}

final addTransactionControllerProvider =
    AsyncNotifierProvider<AddTransactionController, void>(
      AddTransactionController.new,
    );
