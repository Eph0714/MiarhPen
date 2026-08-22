import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../application/dashboard_provider.dart';

/// The Dashboard's full-bleed navy gradient hero panel — Total Available
/// Funds, the Cash/Online split, and a row of circular quick-action
/// buttons (Add Income, Add Expense, Transfer, Statement, More) — styled
/// after a reference design's rounded-bottom gradient header with glass
/// stat chips and avatar-style circular actions, reinterpreted in
/// MiarhPen's navy brand color.
class DashboardHero extends StatelessWidget {
  const DashboardHero({
    super.key,
    required this.summary,
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onTransfer,
    required this.onViewTransactions,
    required this.onReports,
    required this.onTotalAvailableFundsTap,
    required this.onCashFundsTap,
    required this.onOnlineFundsTap,
  });

  final DashboardSummary summary;
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onTransfer;
  final VoidCallback onViewTransactions;
  final VoidCallback onReports;
  final VoidCallback onTotalAvailableFundsTap;
  final VoidCallback onCashFundsTap;
  final VoidCallback onOnlineFundsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTotalAvailableFundsTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Available Funds',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CurrencyFormatter.format(summary.totalAvailableFunds),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _GlassStat(
                  label: 'Cash',
                  amount: summary.availableFundsCash,
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF34C38F),
                  onTap: onCashFundsTap,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _GlassStat(
                  label: 'Online',
                  amount: summary.availableFundsOnline,
                  icon: Icons.wifi_outlined,
                  color: const Color(0xFF4C7CFF),
                  onTap: onOnlineFundsTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircularAction(
                icon: Icons.add,
                label: 'Add Income',
                onTap: onAddIncome,
              ),
              _CircularAction(
                icon: Icons.remove,
                label: 'Add Expense',
                onTap: onAddExpense,
              ),
              _CircularAction(
                icon: Icons.swap_horiz,
                label: 'Transfer',
                onTap: onTransfer,
              ),
              _CircularAction(
                icon: Icons.receipt_long_outlined,
                label: 'History',
                onTap: onViewTransactions,
              ),
              _CircularAction(
                icon: Icons.grid_view_rounded,
                label: 'More',
                onTap: onReports,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A translucent "glass" stat chip inside the hero — Cash or Online's
/// slice of Total Available Funds — tinted with its own [color] icon on
/// an otherwise frosted-white tile so it reads on top of the gradient.
class _GlassStat extends StatelessWidget {
  const _GlassStat({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      CurrencyFormatter.formatCompact(amount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One circular avatar-style quick-action button in the hero's bottom row
/// — an icon in a translucent white circle with its label underneath.
class _CircularAction extends StatelessWidget {
  const _CircularAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 60,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
