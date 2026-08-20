import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

/// Large, readable balance figure used on dashboard/account-detail headers.
/// Color reflects sign: green for positive/neutral, red for negative
/// (e.g. an over-drawn account), unless [color] is explicitly given.
class BalanceText extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final TextStyle? style;
  final Color? color;
  final bool compact;

  const BalanceText({
    super.key,
    required this.amount,
    this.currencySymbol = '₱',
    this.style,
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? (amount < 0 ? AppColors.expense : AppColors.textPrimary);
    final text = compact
        ? CurrencyFormatter.formatCompact(amount, symbol: currencySymbol)
        : CurrencyFormatter.format(amount, symbol: currencySymbol);
    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.displayMedium)?.copyWith(
        color: resolvedColor,
      ),
    );
  }
}
