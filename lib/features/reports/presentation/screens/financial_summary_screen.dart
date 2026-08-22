import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/charts/chart_datum.dart';
import '../../../../core/charts/chart_legend.dart';
import '../../../../core/charts/income_vs_expense_chart.dart';
import '../../../../core/charts/pie_donut_chart_painter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../application/report_filters.dart';
import '../../application/reports_provider.dart';
import '../widgets/account_summary_section.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/report_export_button.dart';

/// Financial Summary report: total income/expense/net movement for a date
/// range, an income-vs-expense chart, and a donut breakdown of funds across
/// accounts.
class FinancialSummaryScreen extends ConsumerStatefulWidget {
  const FinancialSummaryScreen({super.key});

  @override
  ConsumerState<FinancialSummaryScreen> createState() =>
      _FinancialSummaryScreenState();
}

class _FinancialSummaryScreenState
    extends ConsumerState<FinancialSummaryScreen> {
  ReportDateFilter _filter = const ReportDateFilter(
    preset: DateRangePreset.thisMonth,
  );

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(financialSummaryProvider(_filter));
    final distributionAsync = ref.watch(accountDistributionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Summary'),
        actions: [
          ReportExportButton(
            title: 'Financial Summary',
            headers: const ['Metric', 'Amount'],
            rowsBuilder: () async {
              final summary = await ref.read(
                financialSummaryProvider(_filter).future,
              );
              return [
                ['Total Income', summary.totalIncome.toStringAsFixed(2)],
                ['Total Expense', summary.totalExpense.toStringAsFixed(2)],
                ['Net Movement', summary.netMovement.toStringAsFixed(2)],
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
          summaryAsync.when(
            data: (summary) => Column(
              children: [
                _SummaryTile(
                  label: 'Total Income',
                  amount: summary.totalIncome,
                  color: AppColors.income,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryTile(
                  label: 'Total Expense',
                  amount: summary.totalExpense,
                  color: AppColors.expense,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryTile(
                  label: 'Net Movement',
                  amount: summary.netMovement,
                  color: summary.netMovement < 0
                      ? AppColors.expense
                      : AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: IncomeVsExpenseChart(
                    income: summary.totalIncome,
                    expense: summary.totalExpense,
                  ),
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('Failed to load summary: $err')),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          distributionAsync.when(
            data: (data) => _AccountDistributionCard(data: data),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('Failed to load accounts: $err')),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AccountSummarySection(filter: _filter),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          BalanceText(
            amount: amount,
            color: color,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

class _AccountDistributionCard extends StatelessWidget {
  const _AccountDistributionCard({required this.data});

  final List<ChartDatum> data;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (sum, d) => sum + d.value);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Funds by Account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          DonutChart(
            data: data,
            centerLabel: CurrencyFormatter.formatCompact(total),
          ),
          const SizedBox(height: AppSpacing.sm),
          ChartLegend(data: data),
        ],
      ),
    );
  }
}
