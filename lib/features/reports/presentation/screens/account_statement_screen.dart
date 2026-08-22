import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/account_statement_provider.dart';
import '../../application/report_filters.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/report_export_button.dart';

/// One account's statement: a running-balance ledger (Date | Description
/// | Cash In | Cash Out | Balance) for a selectable date range, with a
/// Beginning Balance and a totals summary — e.g.
///
/// ```
/// Beginning Balance: 0
/// 08/04/2025  From Sale of Land   17,000            17,000
/// 08/05/2025  House Material                16,000   1,000
/// -----------------------------------------------------------
/// Eph Cash Summary:
///   Beginning Balance = 0
///   Current Balance   = 1,000
///   Total Cash In (Income)   = 17,000
///   Total Cash Out (Expense) = 16,000
/// ```
class AccountStatementScreen extends ConsumerStatefulWidget {
  const AccountStatementScreen({super.key, required this.accountId});

  final int accountId;

  @override
  ConsumerState<AccountStatementScreen> createState() =>
      _AccountStatementScreenState();
}

class _AccountStatementScreenState
    extends ConsumerState<AccountStatementScreen> {
  ReportDateFilter _filter = const ReportDateFilter(
    preset: DateRangePreset.thisMonth,
  );

  @override
  Widget build(BuildContext context) {
    final statementAsync = ref.watch(
      accountStatementProvider((accountId: widget.accountId, filter: _filter)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          statementAsync.value != null
              ? '${statementAsync.value!.accountName} Statement'
              : 'Account Statement',
        ),
        actions: [
          ReportExportButton(
            title: statementAsync.value != null
                ? '${statementAsync.value!.accountName} Statement'
                : 'Account Statement',
            headers: const [
              'Date',
              'Description',
              'Cash In (Income)',
              'Cash Out (Expense)',
              'Balance',
            ],
            rowsBuilder: () async {
              final statement = await ref.read(
                accountStatementProvider((
                  accountId: widget.accountId,
                  filter: _filter,
                )).future,
              );
              return [
                for (final r in statement.rows)
                  [
                    DateFormatter.short(r.date),
                    r.description,
                    r.cashIn == 0 ? '' : r.cashIn.toStringAsFixed(2),
                    r.cashOut == 0 ? '' : r.cashOut.toStringAsFixed(2),
                    r.balance.toStringAsFixed(2),
                  ],
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DateFilterBar(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          Expanded(
            child: statementAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Failed to load statement: $err')),
              data: (statement) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  children: [
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Beginning Balance',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            CurrencyFormatter.format(
                              statement.summary.beginningBalance,
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (statement.rows.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No entries in this range',
                        message:
                            'The balance carried forward unchanged — no '
                            'income, expenses, or transfers were posted to '
                            'this account in the selected dates.',
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Description')),
                              DataColumn(label: Text('Cash In'), numeric: true),
                              DataColumn(
                                label: Text('Cash Out'),
                                numeric: true,
                              ),
                              DataColumn(label: Text('Balance'), numeric: true),
                            ],
                            rows: [
                              for (final row in statement.rows)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(DateFormatter.short(row.date)),
                                    ),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 160,
                                        ),
                                        child: Text(
                                          row.description,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        row.cashIn == 0
                                            ? '—'
                                            : CurrencyFormatter.format(
                                                row.cashIn,
                                              ),
                                        style: TextStyle(
                                          color: AppColors.income,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        row.cashOut == 0
                                            ? '—'
                                            : CurrencyFormatter.format(
                                                row.cashOut,
                                              ),
                                        style: TextStyle(
                                          color: AppColors.expense,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        CurrencyFormatter.format(row.balance),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '${statement.accountName} Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: 'Beginning Balance',
                            amount: statement.summary.beginningBalance,
                          ),
                          const Divider(height: AppSpacing.lg),
                          _SummaryRow(
                            label: 'Current Balance',
                            amount: statement.summary.endingBalance,
                            emphasize: true,
                          ),
                          const Divider(height: AppSpacing.lg),
                          _SummaryRow(
                            label: 'Total Cash In (Income)',
                            amount: statement.summary.totalCashIn,
                            color: AppColors.income,
                          ),
                          const Divider(height: AppSpacing.lg),
                          _SummaryRow(
                            label: 'Total Cash Out (Expense)',
                            amount: statement.summary.totalCashOut,
                            color: AppColors.expense,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amount,
    this.color,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final Color? color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: emphasize
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          CurrencyFormatter.format(amount),
          style:
              (emphasize
                      ? Theme.of(context).textTheme.headlineSmall
                      : Theme.of(context).textTheme.titleMedium)
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
