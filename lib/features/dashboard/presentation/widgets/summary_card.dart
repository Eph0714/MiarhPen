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
  });

  final String label;
  final double amount;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
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
