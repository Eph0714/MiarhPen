import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';

/// One row in a transaction/transfer history list: a colored left
/// icon reflecting [entryType], description/category, date, amount
/// (colored + signed), account name, and an optional running balance.
class TransactionTile extends StatelessWidget {
  final HistoryEntryType entryType;
  final String title;
  final String? subtitle;
  final DateTime date;
  final double amount;
  final String accountName;
  final double? runningBalance;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.entryType,
    required this.title,
    this.subtitle,
    required this.date,
    required this.amount,
    required this.accountName,
    this.runningBalance,
    this.onTap,
  });

  IconData get _icon {
    switch (entryType) {
      case HistoryEntryType.income:
        return Icons.south_west_rounded;
      case HistoryEntryType.expense:
        return Icons.north_east_rounded;
      case HistoryEntryType.transferIn:
      case HistoryEntryType.transferOut:
        return Icons.swap_horiz_rounded;
    }
  }

  Color get _color {
    switch (entryType) {
      case HistoryEntryType.income:
        return AppColors.income;
      case HistoryEntryType.expense:
        return AppColors.expense;
      case HistoryEntryType.transferIn:
      case HistoryEntryType.transferOut:
        return AppColors.transfer;
    }
  }

  bool get _isNegative =>
      entryType == HistoryEntryType.expense ||
      entryType == HistoryEntryType.transferOut;

  @override
  Widget build(BuildContext context) {
    final signedAmount = _isNegative ? -amount.abs() : amount.abs();
    final amountText =
        '${_isNegative ? '-' : '+'}${CurrencyFormatter.format(amount.abs())}';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon, color: _color, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
          accountName,
          DateFormatter.short(date),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amountText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: signedAmount < 0 ? AppColors.expense : AppColors.income,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (runningBalance != null) ...[
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.format(runningBalance!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
