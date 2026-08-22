import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/report_filters.dart';
import '../../application/reports_provider.dart';

/// A per-account breakdown — current balance, Total In, Total Out for
/// [filter]'s resolved date range — dropped into every report screen so
/// each report can be read both by its own metric (income by category,
/// the daily ledger, etc.) and by which account it actually touched,
/// without having to switch over to the standalone Account Report.
/// Reuses [accountReportProvider], the same data source that report is
/// built from, so the two always agree.
class AccountSummarySection extends ConsumerWidget {
  const AccountSummarySection({
    super.key,
    required this.filter,
    this.rowFilter,
    this.showHeading = true,
  });

  final ReportDateFilter filter;

  /// When set, only rows this returns `true` for are shown — e.g. the
  /// Dashboard's "Available Funds in Cash" / "Available Funds Online"
  /// reports narrow this down to just their own account group. Null (the
  /// default) shows every active account, same as the standalone
  /// Account Report.
  final bool Function(AccountReportRow row)? rowFilter;

  /// Set false when the caller already has its own "Account Summary"-style
  /// heading (e.g. a dedicated Cash/Online funds report screen) and this
  /// section's own heading would just duplicate it.
  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(accountReportProvider(filter));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            'Account Summary',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        rowsAsync.when(
          data: (allRows) {
            final rows = rowFilter == null
                ? allRows
                : allRows.where(rowFilter!).toList();
            if (rows.isEmpty) {
              return const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No accounts found',
                message: 'Add an account to see it here.',
              );
            }
            return Column(
              children: [
                for (final row in rows) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                row.account.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            BalanceText(
                              amount: row.currentBalance,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _AmountLabel(
                                label: 'Total In',
                                amount: row.totalIn,
                                color: AppColors.income,
                              ),
                            ),
                            Expanded(
                              child: _AmountLabel(
                                label: 'Total Out',
                                amount: row.totalOut,
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: Text('Failed to load account summary: $err')),
          ),
        ),
      ],
    );
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
