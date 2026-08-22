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
              icon: Icons.arrow_downward_rounded,
              label: 'Income',
              amount: incomeAbs,
              percent: incomePercent,
            ),
            _Legend(
              color: AppColors.expense,
              icon: Icons.arrow_upward_rounded,
              label: 'Expense',
              amount: expenseAbs,
              percent: expensePercent,
              alignEnd: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          child: SizedBox(
            height: 28,
            child: total <= 0
                ? ColoredBox(color: AppColors.border)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final incomeWidth = constraints.maxWidth * incomeFraction;
                      return Stack(
                        children: [
                          // Base layer: expense fills the full width, then
                          // income is laid on top up to its own share —
                          // together they always cover exactly 100%
                          // regardless of rounding, with no gap between them.
                          // Both layers carry a subtle gradient (darker to
                          // lighter along the fill direction) instead of a
                          // flat tint, for a glossier, more modern bar.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.expense,
                                  AppColors.expense.withValues(alpha: 0.75),
                                ],
                              ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                          SizedBox(
                            width: incomeWidth,
                            height: 28,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.income,
                                    AppColors.income.withValues(alpha: 0.75),
                                  ],
                                ),
                              ),
                            ),
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
    required this.icon,
    required this.label,
    required this.amount,
    required this.percent,
    this.alignEnd = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final double amount;
  final int percent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: color),
    );

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignEnd) ...[badge, const SizedBox(width: AppSpacing.xs)],
            Text(
              '$label · $percent%',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (alignEnd) ...[const SizedBox(width: AppSpacing.xs), badge],
          ],
        ),
        const SizedBox(height: AppSpacing.xs / 2),
        Text(
          CurrencyFormatter.format(amount),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
