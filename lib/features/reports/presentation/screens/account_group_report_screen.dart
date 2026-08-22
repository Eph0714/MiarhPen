import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../application/report_filters.dart';
import '../../application/reports_provider.dart';
import '../widgets/account_summary_section.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/report_export_button.dart';

/// A pure report — no search box, no account-management actions, just the
/// figures — for one half of the Dashboard's Total Available Funds split:
/// [cashOnly] true shows only [AccountType.cash] accounts ("Available
/// Funds in Cash"), false shows every *other* active account type
/// ("Available Funds Online" — bank, GCash, Maya, PayPal, other
/// e-wallets/online payment methods, and debit/credit cards).
///
/// Deliberately not the Accounts list screen (which is a searchable
/// account-management tool) — this is read-only, report-shaped, and
/// matches every other report screen's layout (date range + totals +
/// per-account breakdown + Download/Print Preview).
class AccountGroupReportScreen extends ConsumerStatefulWidget {
  const AccountGroupReportScreen({
    super.key,
    required this.title,
    required this.cashOnly,
  });

  final String title;
  final bool cashOnly;

  @override
  ConsumerState<AccountGroupReportScreen> createState() =>
      _AccountGroupReportScreenState();
}

class _AccountGroupReportScreenState
    extends ConsumerState<AccountGroupReportScreen> {
  ReportDateFilter _filter = const ReportDateFilter(
    preset: DateRangePreset.thisMonth,
  );

  bool _inGroup(AccountReportRow row) =>
      widget.cashOnly == (row.account.type == AccountType.cash);

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(accountReportProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ReportExportButton(
            title: widget.title,
            headers: const ['Account', 'Total In', 'Total Out', 'Balance'],
            rowsBuilder: () async {
              final rows = await ref.read(
                accountReportProvider(_filter).future,
              );
              return [
                for (final r in rows.where(_inGroup))
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
          AppCard(
            color: widget.cashOnly
                ? const Color(0xFF2E7D32)
                : const Color(0xFF1E5FD9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                rowsAsync.when(
                  data: (rows) => BalanceText(
                    amount: rows
                        .where(_inGroup)
                        .fold<double>(0, (sum, r) => sum + r.currentBalance),
                    color: Colors.white,
                  ),
                  loading: () => const SizedBox(
                    height: 32,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) =>
                      const Text('—', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AccountSummarySection(
            filter: _filter,
            rowFilter: _inGroup,
            showHeading: false,
          ),
        ],
      ),
    );
  }
}
