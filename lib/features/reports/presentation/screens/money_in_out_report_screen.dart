import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../../categories/application/categories_provider.dart';
import '../../application/report_filters.dart';
import '../../application/reports_provider.dart';
import '../widgets/account_summary_section.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/report_export_button.dart';

const List<String> _typeOptions = [
  'INCOME',
  'EXPENSE',
  'TRANSFER IN',
  'TRANSFER OUT',
];

/// Money In/Out report: the full transaction + transfer ledger for a date
/// range, with additional account/category/type dropdown filters.
class MoneyInOutReportScreen extends ConsumerStatefulWidget {
  const MoneyInOutReportScreen({super.key});

  @override
  ConsumerState<MoneyInOutReportScreen> createState() =>
      _MoneyInOutReportScreenState();
}

class _MoneyInOutReportScreenState
    extends ConsumerState<MoneyInOutReportScreen> {
  ReportDateFilter _filter = const ReportDateFilter(
    preset: DateRangePreset.thisMonth,
  );
  int? _accountId;
  int? _categoryId;
  String? _type;

  /// Applies the account/category/type dropdown filters on top of the
  /// date-ranged rows — shared by the on-screen list and the export
  /// button so exported files always match what's currently displayed.
  List<MoneyInOutRow> _applyExtraFilters(List<MoneyInOutRow> rows) {
    return rows.where((r) {
      if (_accountId != null && r.accountId != _accountId) return false;
      if (_categoryId != null && r.categoryId != _categoryId) return false;
      if (_type != null && r.type != _type) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(moneyInOutRowsProvider(_filter));
    final accountsAsync = ref.watch(accountsStreamProvider(false));
    final incomeCategoriesAsync = ref.watch(incomeCategoriesStreamProvider);
    final expenseCategoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money In/Out'),
        actions: [
          ReportExportButton(
            title: 'Money In-Out Report',
            headers: const ['Date', 'Type', 'Account', 'Description', 'Amount'],
            rowsBuilder: () async {
              final rows = await ref.read(
                moneyInOutRowsProvider(_filter).future,
              );
              final filtered = _applyExtraFilters(rows);
              return [
                for (final r in filtered)
                  [
                    DateFormatter.short(r.date),
                    r.type,
                    r.accountName,
                    r.description ?? '',
                    r.amount.toStringAsFixed(2),
                  ],
              ];
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          DateFilterBar(
            value: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                width: 180,
                child: accountsAsync.when(
                  data: (accounts) => DropdownButtonFormField<int?>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      for (final a in accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...incomeCategoriesAsync.maybeWhen(
                      data: (list) => [
                        for (final c in list)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      orElse: () => const <DropdownMenuItem<int?>>[],
                    ),
                    ...expenseCategoriesAsync.maybeWhen(
                      data: (list) => [
                        for (final c in list)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      orElse: () => const <DropdownMenuItem<int?>>[],
                    ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final t in _typeOptions)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          rowsAsync.when(
            data: (rows) {
              final filtered = _applyExtraFilters(rows);

              if (filtered.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No entries found',
                  message: 'No transactions or transfers match these filters.',
                );
              }

              return Column(
                children: [
                  for (final row in filtered) ...[
                    _MoneyInOutTile(row: row),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('Failed to load report: $err')),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AccountSummarySection(filter: _filter),
        ],
      ),
    );
  }
}

class _MoneyInOutTile extends StatelessWidget {
  const _MoneyInOutTile({required this.row});

  final MoneyInOutRow row;

  Color get _badgeColor {
    switch (row.type) {
      case 'INCOME':
      case 'TRANSFER IN':
        return AppColors.income;
      case 'EXPENSE':
      case 'TRANSFER OUT':
        return AppColors.expense;
      default:
        return AppColors.transfer;
    }
  }

  bool get _isPositive => row.type == 'INCOME' || row.type == 'TRANSFER IN';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.chipRadius,
                        ),
                      ),
                      child: Text(
                        row.type,
                        style: TextStyle(
                          color: _badgeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      DateFormatter.short(row.date),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  row.description?.isNotEmpty == true
                      ? row.description!
                      : row.accountName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  row.accountName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            '${_isPositive ? '+' : '-'}${CurrencyFormatter.format(row.amount)}',
            style: TextStyle(color: _badgeColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
