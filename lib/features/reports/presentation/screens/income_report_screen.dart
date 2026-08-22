import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/charts/chart_datum.dart';
import '../../../../core/charts/chart_legend.dart';
import '../../../../core/charts/pie_donut_chart_painter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/report_filters.dart';
import '../../application/reports_provider.dart';
import '../widgets/account_summary_section.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/report_export_button.dart';

/// Income Report: income broken down by category for a date range, shown
/// as a donut chart with legend plus a sortable list below.
class IncomeReportScreen extends ConsumerStatefulWidget {
  const IncomeReportScreen({super.key});

  @override
  ConsumerState<IncomeReportScreen> createState() => _IncomeReportScreenState();
}

class _IncomeReportScreenState extends ConsumerState<IncomeReportScreen> {
  ReportDateFilter _filter = const ReportDateFilter(
    preset: DateRangePreset.thisMonth,
  );
  bool _sortDescending = true;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(incomeByCategoryProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income Report'),
        actions: [
          IconButton(
            tooltip: _sortDescending ? 'Sort ascending' : 'Sort descending',
            icon: Icon(
              _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: () => setState(() => _sortDescending = !_sortDescending),
          ),
          ReportExportButton(
            title: 'Income Report',
            headers: const ['Category', 'Amount'],
            rowsBuilder: () async {
              final data = await ref.read(
                incomeByCategoryProvider(_filter).future,
              );
              return [
                for (final d in data) [d.label, d.value.toStringAsFixed(2)],
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
          dataAsync.when(
            data: (data) {
              if (data.isEmpty) {
                return const EmptyState(
                  icon: Icons.trending_up,
                  title: 'No income recorded',
                  message: 'No income transactions found for this period.',
                );
              }
              final sorted = [...data]
                ..sort(
                  (a, b) => _sortDescending
                      ? b.value.compareTo(a.value)
                      : a.value.compareTo(b.value),
                );
              final total = data.fold<double>(0, (sum, d) => sum + d.value);
              return Column(
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        DonutChart(
                          data: data,
                          centerLabel: CurrencyFormatter.formatCompact(total),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ChartLegend(data: data),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CategoryList(data: sorted),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('Failed to load income report: $err')),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AccountSummarySection(filter: _filter),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.data});

  final List<ChartDatum> data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < data.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(data[i].label)),
                  Text(
                    CurrencyFormatter.format(data[i].value),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
