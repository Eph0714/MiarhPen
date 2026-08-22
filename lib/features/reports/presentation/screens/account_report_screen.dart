import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../application/report_filters.dart';
import '../../application/reports_provider.dart';
import '../widgets/account_summary_section.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/report_export_button.dart';

/// Account Report: total in, total out, and current balance for every
/// active account over a date range — the standalone screen for
/// [AccountSummarySection], the same per-account breakdown every other
/// report also shows at the bottom of its own screen.
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
          AccountSummarySection(filter: _filter),
        ],
      ),
    );
  }
}
