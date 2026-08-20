import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';

/// A compact [AppCard] pairing a label with a [BalanceText] figure — used
/// for the Dashboard's Beginning/Money IN/Money OUT/Net/Ending tiles and
/// the headline Total Available Funds card.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.amount,
    this.color,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final double amount;
  final Color? color;
  final bool compact;

  /// When set, the whole tile becomes tappable (e.g. Money IN opens
  /// Transaction History pre-filtered to income) and a chevron hints at
  /// that.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          BalanceText(
            amount: amount,
            color: color,
            compact: compact,
            style: compact
                ? Theme.of(context).textTheme.titleLarge
                : Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}
