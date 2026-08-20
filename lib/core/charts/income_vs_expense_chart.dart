import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

/// Self-contained income-vs-expense comparison widget: a single
/// proportional split bar (not two independently-scaled bars) so the two
/// figures read as a zero-sum comparison — as expense's share grows,
/// income's share visibly shrinks to make room for it, and vice versa.
/// Ready to drop into Dashboard or Reports screens as
/// `IncomeVsExpenseChart(income: x, expense: y)`.
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
    final incomeAbs = income.abs();
    final expenseAbs = expense.abs();
    final total = incomeAbs + expenseAbs;

    // With nothing recorded yet, split the bar evenly rather than
    // collapsing one side to zero-width — an empty state, not a
    // lopsided one.
    final incomeFraction = total > 0 ? incomeAbs / total : 0.5;
    final incomePercent = (incomeFraction * 100).round();
    final expensePercent = 100 - incomePercent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Legend(
              color: AppColors.income,
              label: 'Income',
              amount: incomeAbs,
              percent: incomePercent,
            ),
            _Legend(
              color: AppColors.expense,
              label: 'Expense',
              amount: expenseAbs,
              percent: expensePercent,
              alignEnd: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          child: SizedBox(
            height: 20,
            child: total <= 0
                ? const ColoredBox(color: AppColors.border)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final incomeWidth = constraints.maxWidth * incomeFraction;
                      return Stack(
                        children: [
                          // Base layer: expense fills the full width, then
                          // income is laid on top up to its own share —
                          // together they always cover exactly 100%
                          // regardless of rounding, with no gap between them.
                          const ColoredBox(
                            color: AppColors.expense,
                            child: SizedBox.expand(),
                          ),
                          SizedBox(
                            width: incomeWidth,
                            height: 20,
                            child: const ColoredBox(color: AppColors.income),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.amount,
    required this.percent,
    this.alignEnd = false,
  });

  final Color color;
  final String label;
  final double amount;
  final int percent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignEnd) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              '$label · $percent%',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (alignEnd) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
