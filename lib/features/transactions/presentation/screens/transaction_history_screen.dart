import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../../accounts/domain/account.dart';
import '../../../categories/application/categories_provider.dart';
import '../../../transfers/application/transfers_provider.dart';
import '../../../transfers/domain/transfer.dart';
import '../../application/transaction_filter.dart';
import '../../application/transactions_provider.dart';
import '../../domain/transaction_entry.dart';
import '../widgets/transaction_tile.dart';

/// One row in the consolidated history list — either an income/expense
/// [TransactionEntry] or a [Transfer] leg, normalized to a common display
/// shape so both render side by side in one chronological list instead of
/// being split by type.
class _HistoryItem {
  const _HistoryItem({
    required this.date,
    required this.sortKey,
    required this.entryType,
    required this.title,
    required this.amount,
    required this.accountName,
    required this.onTap,
    this.runningBalanceId,
  });

  final DateTime date;
  final int sortKey;
  final HistoryEntryType entryType;
  final String title;
  final double amount;
  final String accountName;
  final VoidCallback onTap;

  /// Positive for a real transaction id, negative for a transfer's "out"
  /// leg (`-id`) so both share one lookup map without id collisions —
  /// only meaningful when running-balance is being shown (single account
  /// filtered).
  final int? runningBalanceId;
}

/// Filterable transaction + transfer history list, grouped by date. When
/// [initialAccountId] is set, a running-balance column is shown.
///
/// Running balance implementation note: rather than re-deriving a running
/// balance from `Account.currentBalance` walking backwards (fragile if the
/// list is paginated or the filter narrows the date range), we fetch every
/// transaction *and transfer* for that account with no date filter, sort it
/// oldest → newest once, walk it summing a running total, then apply the
/// date-range filter only for what is *displayed*. This keeps the running
/// balance correct regardless of which date preset is selected, at the
/// cost of fetching the full account history — acceptable for a
/// personal-finance app's data volumes.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final int? initialAccountId;
  final TransactionType? initialType;
  final void Function(TransactionEntry) onTapTransaction;
  final void Function(Transfer)? onTapTransfer;

  const TransactionHistoryScreen({
    super.key,
    this.initialAccountId,
    this.initialType,
    required this.onTapTransaction,
    this.onTapTransfer,
  });

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  late TransactionFilter _filter;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = TransactionFilter.fromPreset(
      DateRangePreset.thisMonth,
      accountId: widget.initialAccountId,
      type: widget.initialType,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setPreset(DateRangePreset preset) {
    setState(() {
      _filter = TransactionFilter.fromPreset(
        preset,
        accountId: _filter.accountId,
        categoryId: _filter.categoryId,
        type: _filter.type,
        searchText: _filter.searchText,
      );
    });
  }

  /// Transfers matching the current filter — excluded entirely once the
  /// user narrows to a specific Income/Expense type or category (neither
  /// applies to a transfer), included otherwise so a transfer is never
  /// invisible in "All Types" history.
  bool get _includeTransfers =>
      _filter.type == null && _filter.categoryId == null;

  bool _transferMatchesSearch(Transfer t) {
    final q = _filter.searchText;
    if (q == null || q.isEmpty) return true;
    final needle = q.toLowerCase();
    return (t.notes?.toLowerCase().contains(needle) ?? false) ||
        (t.referenceNumber?.toLowerCase().contains(needle) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final incomeCategoriesAsync = ref.watch(incomeCategoriesStreamProvider);
    final expenseCategoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    final Map<int, double>? runningBalances;
    final AsyncValue<List<TransactionEntry>> displayedTxnAsync;

    if (_filter.accountId != null) {
      final accountId = _filter.accountId!;
      final fullHistoryFilter = TransactionFilter(accountId: accountId);
      final fullHistoryAsync = ref.watch(
        transactionsFilteredProvider(fullHistoryFilter),
      );
      final fullTransfersAsync = ref.watch(
        transfersStreamProvider(const TransfersFilter()),
      );
      displayedTxnAsync = ref.watch(transactionsFilteredProvider(_filter));

      final computed = fullHistoryAsync.whenData((all) {
        final allTransfers = fullTransfersAsync.value ?? const <Transfer>[];
        final relevantTransfers = allTransfers.where(
          (t) => t.fromAccountId == accountId || t.toAccountId == accountId,
        );

        final walk =
            <({DateTime date, int sortId, int? txnId, double delta})>[
              for (final e in all)
                (
                  date: e.date,
                  sortId: e.id ?? 0,
                  txnId: e.id,
                  delta: e.isIncome ? e.amount : -e.amount,
                ),
              for (final t in relevantTransfers) ...[
                if (t.toAccountId == accountId)
                  (
                    date: t.date,
                    sortId: t.id ?? 0,
                    txnId: t.id == null ? null : -t.id!,
                    delta: t.amount,
                  ),
                if (t.fromAccountId == accountId)
                  (
                    date: t.date,
                    sortId: t.id == null ? 0 : -t.id!,
                    txnId: t.id == null ? null : -t.id!,
                    delta: -t.amount,
                  ),
              ],
            ]..sort((a, b) {
              final byDate = a.date.compareTo(b.date);
              if (byDate != 0) return byDate;
              return a.sortId.compareTo(b.sortId);
            });

        double running = 0;
        final map = <int, double>{};
        for (final row in walk) {
          running += row.delta;
          if (row.txnId != null) map[row.txnId!] = running;
        }
        return map;
      });

      runningBalances = computed.maybeWhen(data: (m) => m, orElse: () => null);
    } else {
      runningBalances = null;
      displayedTxnAsync = ref.watch(transactionsFilteredProvider(_filter));
    }

    final displayedTransfersAsync = _includeTransfers
        ? ref.watch(
            transfersStreamProvider(
              TransfersFilter(
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
              ),
            ),
          )
        : const AsyncValue<List<Transfer>>.data(<Transfer>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search description, reference, notes',
              ),
              onSubmitted: (value) {
                setState(() {
                  _filter = _filter.copyWith(
                    searchText: value.trim().isEmpty ? null : value.trim(),
                    clearSearchText: value.trim().isEmpty,
                  );
                });
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: DateRangePreset.values
                  .where((p) => p != DateRangePreset.custom)
                  .map((preset) {
                    final selected = _filter.preset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(preset.label),
                        selected: selected,
                        onSelected: (_) => _setPreset(preset),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: accountsAsync.when(
                    data: (accounts) => DropdownButtonFormField<int?>(
                      initialValue: _filter.accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Account'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Accounts'),
                        ),
                        ...accounts.map(
                          (a) => DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _filter = _filter.copyWith(
                          accountId: v,
                          clearAccountId: v == null,
                        );
                      }),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<TransactionType?>(
                    initialValue: _filter.type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem<TransactionType?>(
                        value: null,
                        child: Text('All (incl. Transfers)'),
                      ),
                      DropdownMenuItem<TransactionType?>(
                        value: TransactionType.income,
                        child: Text('Income'),
                      ),
                      DropdownMenuItem<TransactionType?>(
                        value: TransactionType.expense,
                        child: Text('Expense'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _filter = _filter.copyWith(type: v, clearType: v == null);
                    }),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child:
                (incomeCategoriesAsync.value == null ||
                    expenseCategoriesAsync.value == null)
                ? const SizedBox.shrink()
                : Builder(
                    builder: (context) {
                      final categories = [
                        ...?incomeCategoriesAsync.value?.map(
                          (c) => (id: c.id, name: c.name),
                        ),
                        ...?expenseCategoriesAsync.value?.map(
                          (c) => (id: c.id, name: c.name),
                        ),
                      ];
                      return DropdownButtonFormField<int?>(
                        initialValue: _filter.categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Categories'),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _filter = _filter.copyWith(
                            categoryId: v,
                            clearCategoryId: v == null,
                          );
                        }),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          Expanded(
            child: _buildList(
              context,
              accountsAsync,
              displayedTxnAsync,
              displayedTransfersAsync,
              runningBalances,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AsyncValue<List<Account>> accountsAsync,
    AsyncValue<List<TransactionEntry>> txnAsync,
    AsyncValue<List<Transfer>> transfersAsync,
    Map<int, double>? runningBalances,
  ) {
    if (txnAsync.isLoading || transfersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (txnAsync.hasError) {
      return Center(
        child: Text('Failed to load transactions: ${txnAsync.error}'),
      );
    }
    if (transfersAsync.hasError) {
      return Center(
        child: Text('Failed to load transfers: ${transfersAsync.error}'),
      );
    }

    String accountNameFor(int? accountId) {
      return accountsAsync.maybeWhen(
        data: (accounts) {
          for (final a in accounts) {
            if (a.id == accountId) return a.name;
          }
          return '';
        },
        orElse: () => '',
      );
    }

    final transactions = txnAsync.value ?? const <TransactionEntry>[];
    final transfers = transfersAsync.value ?? const <Transfer>[];
    final filteredTransfers = transfers.where((t) {
      if (_filter.accountId != null &&
          t.fromAccountId != _filter.accountId &&
          t.toAccountId != _filter.accountId) {
        return false;
      }
      return _transferMatchesSearch(t);
    });

    final items = <_HistoryItem>[
      for (final e in transactions)
        _HistoryItem(
          date: e.date,
          sortKey: e.id ?? 0,
          entryType: e.isIncome
              ? HistoryEntryType.income
              : HistoryEntryType.expense,
          title: (e.description == null || e.description!.isEmpty)
              ? (e.isIncome ? 'Income' : 'Expense')
              : e.description!,
          amount: e.amount,
          accountName: accountNameFor(e.accountId),
          onTap: () => widget.onTapTransaction(e),
          runningBalanceId: e.id,
        ),
      for (final t in filteredTransfers) ...[
        // Shown from the perspective of whichever single account is being
        // filtered (if any); with no account filter, shown as an OUT leg
        // from the source account, which is enough to make the transfer
        // visible without double-listing it twice for "All Accounts".
        if (_filter.accountId == null || _filter.accountId == t.fromAccountId)
          _HistoryItem(
            date: t.date,
            sortKey: t.id ?? 0,
            entryType: HistoryEntryType.transferOut,
            title: t.notes?.isNotEmpty == true
                ? t.notes!
                : 'Transfer to ${accountNameFor(t.toAccountId)}',
            amount: t.amount,
            accountName: accountNameFor(t.fromAccountId),
            onTap: () => widget.onTapTransfer?.call(t),
            runningBalanceId: t.id == null ? null : -t.id!,
          ),
        if (_filter.accountId != null && _filter.accountId == t.toAccountId)
          _HistoryItem(
            date: t.date,
            sortKey: t.id ?? 0,
            entryType: HistoryEntryType.transferIn,
            title: t.notes?.isNotEmpty == true
                ? t.notes!
                : 'Transfer from ${accountNameFor(t.fromAccountId)}',
            amount: t.amount,
            accountName: accountNameFor(t.toAccountId),
            onTap: () => widget.onTapTransfer?.call(t),
            runningBalanceId: t.id == null ? null : -t.id!,
          ),
      ],
    ];

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions found',
        message: 'Try adjusting your filters or add a new entry.',
      );
    }

    final grouped = <String, List<_HistoryItem>>{};
    for (final item in items) {
      final key = DateFormatter.iso(item.date);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final dayItems = grouped[key]!
          ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                DateFormatter.long(dayItems.first.date),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...dayItems.map(
              (item) => TransactionTile(
                entryType: item.entryType,
                title: item.title,
                date: item.date,
                amount: item.amount,
                accountName: item.accountName,
                runningBalance:
                    (runningBalances != null && item.runningBalanceId != null)
                    ? runningBalances[item.runningBalanceId!]
                    : null,
                onTap: item.onTap,
              ),
            ),
          ],
        );
      },
    );
  }
}
