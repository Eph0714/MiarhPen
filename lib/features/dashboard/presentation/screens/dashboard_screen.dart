import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/charts/income_vs_expense_chart.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../../../core/platform/update_checker_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/update_banner.dart';
import '../../../accounting_periods/application/periods_provider.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../../transactions/domain/transaction_entry.dart';
import '../../application/dashboard_provider.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/summary_card.dart';

/// MiarhPen's home screen: total available funds, current-period totals,
/// an income-vs-expense chart, quick actions (including an Accounts
/// button showing the account count), and recent transactions. Purely
/// routing-agnostic — all navigation is delegated to the callbacks
/// passed in.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onTransfer,
    required this.onViewTransactions,
    required this.onReports,
    required this.onViewAccounts,
    required this.onRecurringPayments,
    required this.onBeginningBalanceTap,
    required this.onMoneyInTap,
    required this.onMoneyOutTap,
    required this.onNetMovementTap,
    required this.onEndingBalanceTap,
    required this.onTotalAvailableFundsTap,
    required this.onCashOnHandTap,
    required this.onCashInBankTap,
  });

  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onTransfer;
  final VoidCallback onViewTransactions;
  final VoidCallback onReports;
  final VoidCallback onViewAccounts;
  final VoidCallback onRecurringPayments;

  /// Tapping each summary tile jumps to where that figure is broken down
  /// in more detail — Beginning/Ending Balance to the accounting period
  /// that produced them, Money IN to the Income Report, Money OUT to the
  /// Expense Report, and Net Movement to the Financial Summary report.
  final VoidCallback onBeginningBalanceTap;
  final VoidCallback onMoneyInTap;
  final VoidCallback onMoneyOutTap;
  final VoidCallback onNetMovementTap;
  final VoidCallback onEndingBalanceTap;

  /// Total Available Funds opens the Account Report (the per-account
  /// breakdown that adds up to that total). Cash On Hand / Cash in Bank
  /// open the Accounts list pre-filtered to just that account type.
  final VoidCallback onTotalAvailableFundsTap;
  final VoidCallback onCashOnHandTap;
  final VoidCallback onCashInBankTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final openPeriodAsync = ref.watch(openPeriodProvider);
    final accountsAsync = ref.watch(accountsStreamProvider(true));
    final recentTransactionsAsync = ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Column(
        children: [
          const UpdateBanner(),
          // Pinned above the scrollable content (not inside the ListView
          // below) so Add Income / Add Expense — the two most frequent
          // actions in the app — are always reachable in one tap, with
          // zero scrolling, no matter how far down the dashboard is
          // scrolled.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddIncome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.income,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Income'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Add Expense'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) =>
                  Center(child: Text('Failed to load dashboard: $err')),
              data: (summary) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dashboardSummaryProvider);
                    // So a pulled-to-refresh Dashboard also picks up a
                    // newer release that came out since the app was
                    // opened, not just whatever was available at launch.
                    ref.invalidate(updateCheckProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      openPeriodAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (period) {
                          if (period == null) {
                            return Text(
                              'No open accounting period — set one up in Settings.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.liability),
                            );
                          }
                          final dateRange = period.endDate != null
                              ? '${DateFormatter.short(period.startDate)} – ${DateFormatter.short(period.endDate!)}'
                              : 'Since ${DateFormatter.short(period.startDate)}';
                          return Text(
                            '${period.name} · $dateRange',
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        onTap: onTotalAvailableFundsTap,
                        color: const Color(0xFFFFF176),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Available Funds',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.black87),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            BalanceText(
                              amount: summary.totalAvailableFunds,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: SummaryCard(
                              label: 'Cash On Hand',
                              amount: summary.cashOnHand,
                              compact: true,
                              onTap: onCashOnHandTap,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: SummaryCard(
                              label: 'Cash in Bank',
                              amount: summary.cashInBank,
                              compact: true,
                              onTap: onCashInBankTap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 2.1,
                        children: [
                          SummaryCard(
                            label: 'Beginning Balance',
                            amount: summary.beginningBalance,
                            compact: true,
                            onTap: onBeginningBalanceTap,
                          ),
                          SummaryCard(
                            label: 'Money IN',
                            amount: summary.totalMoneyIn,
                            color: AppColors.income,
                            compact: true,
                            onTap: onMoneyInTap,
                          ),
                          SummaryCard(
                            label: 'Money OUT',
                            amount: summary.totalMoneyOut,
                            color: AppColors.expense,
                            compact: true,
                            onTap: onMoneyOutTap,
                          ),
                          SummaryCard(
                            label: 'Net Movement',
                            amount: summary.netMovement,
                            color: summary.netMovement < 0
                                ? AppColors.expense
                                : AppColors.income,
                            compact: true,
                            onTap: onNetMovementTap,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SummaryCard(
                        label: 'Ending Balance',
                        amount: summary.endingBalance,
                        compact: true,
                        onTap: onEndingBalanceTap,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: IncomeVsExpenseChart(
                          income: summary.totalMoneyIn,
                          expense: summary.totalMoneyOut,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      QuickActionsRow(
                        accountCount: accountsAsync.value?.length ?? 0,
                        onViewAccounts: onViewAccounts,
                        onTransfer: onTransfer,
                        onViewTransactions: onViewTransactions,
                        onReports: onReports,
                        onRecurringPayments: onRecurringPayments,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Recent Transactions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      recentTransactionsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, st) =>
                            Text('Failed to load transactions: $err'),
                        data: (transactions) {
                          if (transactions.isEmpty) {
                            return const EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet',
                            );
                          }
                          return AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final txn in transactions)
                                  _RecentTransactionTile(transaction: txn),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple fallback row for a recent transaction.
///
/// NOTE: `lib/features/transactions/presentation/widgets/transaction_tile.dart`
/// did not exist yet at the time this file was written by a parallel agent
/// — this is a minimal local `ListTile`-based fallback. Once that widget
/// lands, swap it in here (dedup candidate).
class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.transaction});

  final TransactionEntry transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final color = isIncome ? AppColors.income : AppColors.expense;
    return ListTile(
      leading: Icon(
        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
        color: color,
      ),
      title: Text(
        transaction.description?.isNotEmpty == true
            ? transaction.description!
            : (isIncome ? 'Income' : 'Expense'),
      ),
      subtitle: Text(DateFormatter.short(transaction.date)),
      trailing: Text(
        '${isIncome ? '+' : '-'}${CurrencyFormatter.format(transaction.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
