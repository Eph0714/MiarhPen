import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/charts/income_vs_expense_chart.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../../../core/platform/update_checker_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/update_banner.dart';
import '../../../accounting_periods/application/periods_provider.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../../reports/application/report_filters.dart';
import '../../../reports/application/reports_provider.dart';
import '../../../reports/presentation/widgets/date_filter_bar.dart';
import '../../../transactions/domain/transaction_entry.dart';
import '../../application/dashboard_provider.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/summary_card.dart';

/// MiarhPen's home screen: total available funds, an income-vs-expense
/// chart (all accounts, including credit cards, over a selectable date
/// range), quick actions (including an Accounts button showing the
/// account count), and recent transactions. Purely routing-agnostic —
/// all navigation is delegated to the callbacks passed in.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onTransfer,
    required this.onViewTransactions,
    required this.onReports,
    required this.onViewAccounts,
    required this.onRecurringPayments,
    required this.onTotalAvailableFundsTap,
    required this.onAccountStatementTap,
  });

  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onTransfer;
  final VoidCallback onViewTransactions;
  final VoidCallback onReports;
  final VoidCallback onViewAccounts;
  final VoidCallback onRecurringPayments;

  /// Total Available Funds opens the Account Report (the per-account
  /// breakdown that adds up to that total).
  final VoidCallback onTotalAvailableFundsTap;

  /// Tapping any account button in the "Accounts" section below opens
  /// that account's statement (running-balance ledger + summary).
  final void Function(int accountId) onAccountStatementTap;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ReportDateFilter _chartFilter = const ReportDateFilter(
    preset: DateRangePreset.thisMonth,
  );

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final openPeriodAsync = ref.watch(openPeriodProvider);
    final accountsAsync = ref.watch(accountsStreamProvider(true));
    final recentTransactionsAsync = ref.watch(recentTransactionsProvider);
    // All accounts, including credit cards — same reasoning already
    // applied to every other report: excluding credit cards here would
    // hide real spending/income just because it happened on a card.
    final chartSummaryAsync = ref.watch(financialSummaryProvider(_chartFilter));

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
                    onPressed: widget.onAddIncome,
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
                    onPressed: widget.onAddExpense,
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
                        onTap: widget.onTotalAvailableFundsTap,
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
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Income vs Expense',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DateFilterBar(
                        value: _chartFilter,
                        onChanged: (f) => setState(() => _chartFilter = f),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        child: chartSummaryAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, st) =>
                              Text('Failed to load chart: $err'),
                          data: (chartSummary) => IncomeVsExpenseChart(
                            income: chartSummary.totalIncome,
                            expense: chartSummary.totalExpense,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Accounts',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      accountsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, st) =>
                            Text('Failed to load accounts: $err'),
                        data: (accounts) {
                          if (accounts.isEmpty) {
                            return const EmptyState(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'No accounts yet',
                            );
                          }
                          return GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 2.1,
                            children: [
                              for (final account in accounts)
                                SummaryCard(
                                  label: account.name,
                                  amount: account.currentBalance,
                                  compact: true,
                                  onTap: () =>
                                      widget.onAccountStatementTap(account.id!),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      QuickActionsRow(
                        accountCount: accountsAsync.value?.length ?? 0,
                        onViewAccounts: widget.onViewAccounts,
                        onTransfer: widget.onTransfer,
                        onViewTransactions: widget.onViewTransactions,
                        onReports: widget.onReports,
                        onRecurringPayments: widget.onRecurringPayments,
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
