import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

/// Grid of quick-action buttons on the Dashboard: Accounts (with a live
/// count), Transfer Money, View Transactions, and Reports. Purely
/// routing-agnostic — all navigation is delegated to the callbacks.
///
/// Add Income / Add Expense are NOT here — they're pinned in a prominent
/// bar directly under the app bar (see [DashboardScreen]) for one-tap
/// access without scrolling, since they're the two most frequent actions
/// in the app. This grid covers the secondary actions, including the
/// account list — rather than rendering every account's own card inline
/// on the dashboard (which previously overflowed at some text scales),
/// "Accounts" is a single button showing how many accounts exist and
/// leading to the full list.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.accountCount,
    required this.onViewAccounts,
    required this.onTransfer,
    required this.onViewTransactions,
    required this.onReports,
    required this.onRecurringPayments,
  });

  final int accountCount;
  final VoidCallback onViewAccounts;
  final VoidCallback onTransfer;
  final VoidCallback onViewTransactions;
  final VoidCallback onReports;
  final VoidCallback onRecurringPayments;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.4,
      children: [
        _ActionButton(
          label: 'Accounts',
          badge: '$accountCount',
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
          onTap: onViewAccounts,
        ),
        _ActionButton(
          label: 'Transfer Money',
          icon: Icons.swap_horiz,
          color: AppColors.transfer,
          onTap: onTransfer,
        ),
        _ActionButton(
          label: 'View Transactions',
          icon: Icons.receipt_long_outlined,
          color: AppColors.primary,
          onTap: onViewTransactions,
        ),
        _ActionButton(
          label: 'Reports',
          icon: Icons.bar_chart_outlined,
          color: AppColors.primary,
          onTap: onReports,
        ),
        _ActionButton(
          label: 'Recurring Payments',
          icon: Icons.event_repeat_outlined,
          color: AppColors.liability,
          onTap: onRecurringPayments,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// Optional short badge shown next to the label, e.g. an account count.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              badge != null ? '$label ($badge)' : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
