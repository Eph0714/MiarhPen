import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../../categories/application/categories_provider.dart';
import '../../application/transaction_filter.dart';
import '../../application/transactions_provider.dart';
import '../../domain/transaction_entry.dart';
import '../widgets/transaction_tile.dart';

/// Filterable transaction history list, grouped by date. When
/// [initialAccountId] is set, a running-balance column is shown.
///
/// Running balance implementation note: rather than re-deriving a running
/// balance from `Account.currentBalance` walking backwards (fragile if the
/// list is paginated or the filter narrows the date range), we fetch every
/// transaction for that account with no date filter, sort it oldest → newest
/// once, walk it summing a running total, then apply the date-range filter
/// only for what is *displayed*. This keeps the running balance correct
/// regardless of which date preset is selected, at the cost of fetching the
/// full account history — acceptable for a personal-finance app's data
/// volumes.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final int? initialAccountId;
  final TransactionType? initialType;
  final void Function(TransactionEntry) onTapTransaction;

  const TransactionHistoryScreen({
    super.key,
    this.initialAccountId,
    this.initialType,
    required this.onTapTransaction,
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

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final incomeCategoriesAsync = ref.watch(incomeCategoriesStreamProvider);
    final expenseCategoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    final Map<int, double>? runningBalances;
    final AsyncValue<List<TransactionEntry>> displayedAsync;

    if (_filter.accountId != null) {
      final accountId = _filter.accountId!;
      final fullHistoryFilter = TransactionFilter(accountId: accountId);
      final fullHistoryAsync = ref.watch(
        transactionsFilteredProvider(fullHistoryFilter),
      );
      final displayed = ref.watch(transactionsFilteredProvider(_filter));

      final computed = fullHistoryAsync.whenData((all) {
        final sorted = [...all]
          ..sort((a, b) {
            final byDate = a.date.compareTo(b.date);
            if (byDate != 0) return byDate;
            return (a.id ?? 0).compareTo(b.id ?? 0);
          });
        double running = 0;
        final map = <int, double>{};
        for (final e in sorted) {
          running += e.isIncome ? e.amount : -e.amount;
          if (e.id != null) map[e.id!] = running;
        }
        return map;
      });

      runningBalances = computed.maybeWhen(data: (m) => m, orElse: () => null);
      displayedAsync = displayed;
    } else {
      runningBalances = null;
      displayedAsync = ref.watch(transactionsFilteredProvider(_filter));
    }

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
                        child: Text('All Types'),
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
            child: displayedAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions found',
                    message: 'Try adjusting your filters or add a new entry.',
                  );
                }
                final grouped = <String, List<TransactionEntry>>{};
                for (final e in entries) {
                  final key = DateFormatter.iso(e.date);
                  grouped.putIfAbsent(key, () => []).add(e);
                }
                final sortedKeys = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final key = sortedKeys[index];
                    final dayEntries = grouped[key]!;
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
                            DateFormatter.long(dayEntries.first.date),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        ...dayEntries.map((e) {
                          final accountName = accountsAsync.maybeWhen(
                            data: (accounts) {
                              for (final a in accounts) {
                                if (a.id == e.accountId) return a.name;
                              }
                              return '';
                            },
                            orElse: () => '',
                          );
                          return TransactionTile(
                            entryType: e.isIncome
                                ? HistoryEntryType.income
                                : HistoryEntryType.expense,
                            title:
                                (e.description == null ||
                                    e.description!.isEmpty)
                                ? (e.isIncome ? 'Income' : 'Expense')
                                : e.description!,
                            date: e.date,
                            amount: e.amount,
                            accountName: accountName,
                            runningBalance:
                                (runningBalances != null && e.id != null)
                                ? runningBalances[e.id!]
                                : null,
                            onTap: () => widget.onTapTransaction(e),
                          );
                        }),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) =>
                  Center(child: Text('Failed to load transactions: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
