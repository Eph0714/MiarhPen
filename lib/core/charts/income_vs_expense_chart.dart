import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bar_chart_painter.dart';
import 'chart_datum.dart';
import 'chart_legend.dart';

/// Self-contained income-vs-expense comparison widget: a two-bar
/// [BarChart] plus its [ChartLegend], ready to drop into Dashboard or
/// Reports screens as `IncomeVsExpenseChart(income: x, expense: y)`.
class IncomeVsExpenseChart extends StatelessWidget {
  const IncomeVsExpenseChart({
    required this.income,
    required this.expense,
    super.key,
  });

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final data = [
      ChartDatum(label: 'Income', value: income, color: AppColors.income),
      ChartDatum(label: 'Expense', value: expense, color: AppColors.expense),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BarChart(data: data),
        const SizedBox(height: AppSpacing.sm),
        ChartLegend(data: data),
      ],
    );
  }
}
