import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/report_filters.dart';
import '../../application/reports_provider.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/report_export_button.dart';

/// Account Report: total in, total out, and current balance for every
/// active account over a date range.
class AccountReportScreen extends ConsumerStatefulWidget {
  const AccountReportScreen({super.key});

  @override
  ConsumerState<AccountReportScreen> createState() =>
      _AccountReportScreenState();
}

class _AccountReportScreenState extends ConsumerState<AccountReportScreen> {
  ReportDateFilter _filter = const ReportDateFilter(
    preset: DateRangePreset.thisMonth,
  );

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(accountReportProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Report'),
        actions: [
          ReportExportButton(
            title: 'Account Report',
            headers: const ['Account', 'Total In', 'Total Out', 'Balance'],
            rowsBuilder: () async {
              final rows = await ref.read(
                accountReportProvider(_filter).future,
              );
              return [
                for (final r in rows)
                  [
                    r.account.name,
                    r.totalIn.toStringAsFixed(2),
                    r.totalOut.toStringAsFixed(2),
                    r.currentBalance.toStringAsFixed(2),
                  ],
              ];
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          DateFilterBar(
            value: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.md),
          rowsAsync.when(
            data: (rows) {
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              BalanceText(
                                amount: row.currentBalance,
                                style: Theme.of(context).textTheme.titleLarge,
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
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('Failed to load account report: $err')),
            ),
          ),
        ],
      ),
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
