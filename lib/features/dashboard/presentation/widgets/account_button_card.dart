import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../accounts/domain/account.dart';

/// One account's button on the Dashboard's "Accounts" section — a plain
/// card with a single-color type-icon avatar (cash, bank, card, etc.),
/// the account's full name, and its current balance. Deliberately
/// monochrome (every account uses the same accent color, not a color
/// picked per account) for a simple, uncluttered look.
///
/// Has no `maxLines`/`overflow` on the name or balance — every account
/// should read in full, even a long one — so this sizes itself to its
/// content rather than being forced into a fixed-height grid cell (see
/// how the Dashboard lays these out with [Wrap], not a
/// fixed-aspect-ratio `GridView`).
class AccountButtonCard extends StatelessWidget {
  const AccountButtonCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  account.type.icon,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                account.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                CurrencyFormatter.format(account.currentBalance),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
