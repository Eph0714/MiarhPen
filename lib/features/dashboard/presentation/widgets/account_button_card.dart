import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/account_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../accounts/domain/account.dart';

/// One account's button on the Dashboard's "Accounts" section — a solid,
/// color-coded tile (see [AccountColors]) with a type icon avatar, the
/// account's full name, and its current balance, all in white against
/// that account's own solid color, so a row of many accounts stays
/// visually scannable instead of reading as identical gray boxes.
///
/// Deliberately has no `maxLines`/`overflow` on the name or balance —
/// every account should read in full, even a long one — so this sizes
/// itself to its content rather than being forced into a fixed-height
/// grid cell (see how the Dashboard lays these out with [Wrap], not a
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
    final brightness = Theme.of(context).brightness;
    final color = AccountColors.forAccount(account.id, brightness);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      account.type.icon,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      account.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                CurrencyFormatter.format(account.currentBalance),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
