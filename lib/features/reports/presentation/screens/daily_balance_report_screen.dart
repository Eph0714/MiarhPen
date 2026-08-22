import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/report_filters.dart';
import '../../application/reports_provider.dart';
import '../../domain/daily_balance_row.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/report_export_button.dart';

/// Daily Balance Report: one row per calendar day, each day's Beginning
/// Balance carried forward automatically from the previous day's Ending
/// Balance — never entered by hand. See [dailyBalanceReportProvider] for
/// the underlying calculation (cash-equivalent accounts only: cash,
/// bank, GCash, Maya, PayPal, and other e-wallets/online payment
/// methods — credit cards and debit cards are excluded, same as
/// elsewhere in the app).
class DailyBalanceReportScreen extends ConsumerStatefulWidget {
  const DailyBalanceReportScreen({super.key});

  @override
  ConsumerState<DailyBalanceReportScreen> createState() =>
      _DailyBalanceReportScreenState();
}

class _DailyBalanceReportScreenState
    extends ConsumerState<DailyBalanceReportScreen> {
  ReportDateFilter _filter = const ReportDateFilter(
    preset: DateRangePreset.thisMonth,
  );

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(dailyBalanceReportProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Balance Report'),
        actions: [
          ReportExportButton(
            title: 'Daily Balance Report',
            headers: const [
              'Date',
              'Beginning Balance',
              'Total Income',
              'Total Expenses',
              'Ending Balance',
            ],
            rowsBuilder: () async {
              final rows = await ref.read(
                dailyBalanceReportProvider(_filter).future,
              );
              return [
                for (final r in rows)
                  [
                    DateFormatter.short(r.date),
                    r.beginningBalance.toStringAsFixed(2),
                    r.totalIncome.toStringAsFixed(2),
                    r.totalExpense.toStringAsFixed(2),
                    r.endingBalance.toStringAsFixed(2),
                  ],
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DateFilterBar(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          Expanded(
            child: rowsAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const EmptyState(
                    icon: Icons.calendar_today_outlined,
                    title: 'No days in this range',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  // Most recent day first — matches every other report's
                  // ordering in this app.
                  itemBuilder: (context, index) =>
                      _DailyBalanceCard(row: rows[rows.length - 1 - index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Failed to load report: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBalanceCard extends StatelessWidget {
  const _DailyBalanceCard({required this.row});

  final DailyBalanceRow row;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormatter.long(row.date),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Amount(
                  label: 'Beginning',
                  amount: row.beginningBalance,
                ),
              ),
              Expanded(
                child: _Amount(
                  label: 'Income',
                  amount: row.totalIncome,
                  color: AppColors.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Amount(
                  label: 'Expenses',
                  amount: row.totalExpense,
                  color: AppColors.expense,
                ),
              ),
              Expanded(
                child: _Amount(
                  label: 'Ending',
                  amount: row.endingBalance,
                  emphasize: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.amount,
    this.color,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final Color? color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          CurrencyFormatter.format(amount),
          style:
              (emphasize
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.bodyLarge)
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
