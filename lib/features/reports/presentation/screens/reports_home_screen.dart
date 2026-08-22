import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

/// Landing menu for the Reports feature: one tile per report, routing-agnostic
/// (the caller supplies navigation via the callbacks).
class ReportsHomeScreen extends StatelessWidget {
  const ReportsHomeScreen({
    required this.onFinancialSummary,
    required this.onIncomeReport,
    required this.onExpenseReport,
    required this.onAccountReport,
    required this.onMoneyInOut,
    required this.onDailyBalance,
    super.key,
  });

  final VoidCallback onFinancialSummary;
  final VoidCallback onIncomeReport;
  final VoidCallback onExpenseReport;
  final VoidCallback onAccountReport;
  final VoidCallback onMoneyInOut;
  final VoidCallback onDailyBalance;

  @override
  Widget build(BuildContext context) {
    final tiles = <_ReportTile>[
      _ReportTile(
        icon: Icons.pie_chart_outline,
        title: 'Financial Summary',
        subtitle: 'Income, expense and net movement overview',
        onTap: onFinancialSummary,
      ),
      _ReportTile(
        icon: Icons.trending_up,
        title: 'Income Report',
        subtitle: 'Income broken down by category',
        onTap: onIncomeReport,
      ),
      _ReportTile(
        icon: Icons.trending_down,
        title: 'Expense Report',
        subtitle: 'Expenses broken down by category',
        onTap: onExpenseReport,
      ),
      _ReportTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Account Report',
        subtitle: 'Totals in/out and balance per account',
        onTap: onAccountReport,
      ),
      _ReportTile(
        icon: Icons.swap_horiz,
        title: 'Money In/Out',
        subtitle: 'Full transaction and transfer ledger',
        onTap: onMoneyInOut,
      ),
      _ReportTile(
        icon: Icons.calendar_view_day_outlined,
        title: 'Daily Balance Report',
        subtitle: 'Running beginning/ending balance, day by day',
        onTap: onDailyBalance,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => tiles[index],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
