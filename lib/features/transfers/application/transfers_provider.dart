import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/transfer_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../../../core/utils/validators.dart';
import '../../transactions/data/transaction_repository.dart';
import '../domain/transfer.dart';

final transferDaoProvider = Provider<TransferDao>((ref) => TransferDao());

final transferRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(),
);

/// Simple filter for the transfer history list: an optional date range.
class TransfersFilter {
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const TransfersFilter({this.dateFrom, this.dateTo});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransfersFilter &&
          other.dateFrom == dateFrom &&
          other.dateTo == dateTo);

  @override
  int get hashCode => Object.hash(dateFrom, dateTo);
}

/// All transfers matching [filter], newest first.
final transfersStreamProvider = StreamProvider.autoDispose
    .family<List<Transfer>, TransfersFilter>((ref, filter) {
  final dao = ref.watch(transferDaoProvider);
  return DbChangeNotifier.instance
      .watch(DbTable.transfers)
      .asyncMap((_) => dao.getAll(from: filter.dateFrom, to: filter.dateTo));
});

/// Single transfer by id, kept live via the transfers table stream.
final transferByIdProvider =
    StreamProvider.autoDispose.family<Transfer?, int>((ref, id) {
  final dao = ref.watch(transferDaoProvider);
  return DbChangeNotifier.instance
      .watch(DbTable.transfers)
      .asyncMap((_) => dao.getById(id));
});

/// Handles create/update/delete for account-to-account transfers. Routes
/// every write through [TransactionRepository] — the single trusted write
/// path — which also validates from != to and re-derives both accounts'
/// balances.
class AddTransferController extends AsyncNotifier<void> {
  DateTime? _lastSubmitAt;

  @override
  void build() {}

  TransactionRepository get _repository =>
      ref.read(transferRepositoryProvider);

  Future<void> submit({
    required DateTime date,
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? referenceNumber,
    String? notes,
    Transfer? editing,
  }) async {
    if (isDuplicateSubmitGuardTripped(_lastSubmitAt)) return;
    _lastSubmitAt = DateTime.now();

    final validationError =
        Validators.differentAccounts(fromAccountId, toAccountId);
    if (validationError != null) {
      state = AsyncError(ArgumentError(validationError), StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final transfer = Transfer(
        id: editing?.id,
        date: date,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        referenceNumber: referenceNumber,
        notes: notes,
        createdAt: editing?.createdAt ?? now,
        updatedAt: now,
      );

      if (editing != null) {
        await _repository.updateTransfer(editing, transfer);
      } else {
        await _repository.addTransfer(transfer);
      }
    });
  }

  Future<void> delete(Transfer transfer) async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _repository.deleteTransfer(transfer));
  }
}

final addTransferControllerProvider =
    AsyncNotifierProvider<AddTransferController, void>(
  AddTransferController.new,
);
