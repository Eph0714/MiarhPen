import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/periods_provider.dart';

/// Detail view for a single accounting period: beginning balance, totals,
/// and (for open periods) an ending-balance preview computed live from the
/// three source numbers — never a possibly-stale stored value while the
/// period is still open. Once closed, the stored endingBalance is
/// authoritative and is shown instead.
class PeriodDetailScreen extends ConsumerStatefulWidget {
  const PeriodDetailScreen({
    super.key,
    required this.periodId,
    required this.onClosed,
  });

  final int periodId;
  final VoidCallback onClosed;

  @override
  ConsumerState<PeriodDetailScreen> createState() => _PeriodDetailScreenState();
}

class _PeriodDetailScreenState extends ConsumerState<PeriodDetailScreen> {
  bool _closing = false;

  Future<void> _handleClose() async {
    final confirmed = await showConfirmDialog(
      context,
      destructive: false,
      title: 'Close Accounting Period',
      message:
          'This freezes the ending balance for this period. You can review it later but not edit its totals. Continue?',
      confirmLabel: 'Close Period',
    );
    if (!confirmed) return;

    setState(() => _closing = true);
    try {
      await ref
          .read(closePeriodControllerProvider)
          .closePeriod(widget.periodId);
      if (!mounted) return;
      widget.onClosed();
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodAsync = ref.watch(periodByIdProvider(widget.periodId));

    return Scaffold(
      appBar: AppBar(title: const Text('Period Detail')),
      body: periodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Failed to load period: $err')),
        data: (period) {
          if (period == null) {
            return const Center(child: Text('This period no longer exists.'));
          }

          final isOpen = period.status == AccountingPeriodStatus.open;
          final liveEndingBalance =
              period.beginningBalance +
              period.totalIncome -
              period.totalExpense;
          final displayedEndingBalance = isOpen
              ? liveEndingBalance
              : (period.endingBalance ?? liveEndingBalance);

          return LoadingOverlay(
            visible: _closing,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  period.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  period.endDate != null
                      ? '${DateFormatter.long(period.startDate)} – ${DateFormatter.long(period.endDate!)}'
                      : 'Started ${DateFormatter.long(period.startDate)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    children: [
                      _StatRow(
                        label: 'Beginning Balance',
                        amount: period.beginningBalance,
                      ),
                      const Divider(height: AppSpacing.lg),
                      _StatRow(
                        label: 'Total Income',
                        amount: period.totalIncome,
                        color: AppColors.income,
                      ),
                      const Divider(height: AppSpacing.lg),
                      _StatRow(
                        label: 'Total Expense',
                        amount: period.totalExpense,
                        color: AppColors.expense,
                      ),
                      const Divider(height: AppSpacing.lg),
                      _StatRow(
                        label: isOpen
                            ? 'Ending Balance (live)'
                            : 'Ending Balance',
                        amount: displayedEndingBalance,
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (isOpen)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _closing ? null : _handleClose,
                      child: const Text('Close Period'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
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
        BalanceText(
          amount: amount,
          color: color,
          compact: false,
          style: emphasize
              ? Theme.of(context).textTheme.headlineMedium
              : Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
