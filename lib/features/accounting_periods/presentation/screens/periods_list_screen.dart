import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/periods_provider.dart';
import '../../domain/accounting_period.dart';

/// Lists all accounting periods, newest first. A create-new action is only
/// enabled when no period is currently open (MiarhPen allows at most one
/// open period at a time).
class PeriodsListScreen extends ConsumerWidget {
  const PeriodsListScreen({
    super.key,
    required this.onTapPeriod,
    required this.onCreateNew,
  });

  final void Function(AccountingPeriod) onTapPeriod;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(periodsStreamProvider);
    final openPeriodAsync = ref.watch(openPeriodProvider);
    final canCreateNew = openPeriodAsync.maybeWhen(
      data: (open) => open == null,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Accounting Periods')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canCreateNew ? onCreateNew : null,
        backgroundColor: canCreateNew ? AppColors.primary : AppColors.border,
        icon: const Icon(Icons.add),
        label: const Text('New Period'),
      ),
      body: periodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Failed to load periods: $err')),
        data: (periods) {
          if (periods.isEmpty) {
            return EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No accounting periods yet',
              message: 'Create your first period to start tracking totals.',
              action: FilledButton(
                onPressed: onCreateNew,
                child: const Text('Create Period'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: periods.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final period = periods[index];
              return _PeriodRow(
                period: period,
                onTap: () => onTapPeriod(period),
              );
            },
          );
        },
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.onTap});

  final AccountingPeriod period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOpen = period.status == AccountingPeriodStatus.open;
    final dateRange = period.endDate != null
        ? '${DateFormatter.short(period.startDate)} – ${DateFormatter.short(period.endDate!)}'
        : 'From ${DateFormatter.short(period.startDate)}';

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(dateRange, style: Theme.of(context).textTheme.bodyMedium),
                if (period.isClosed && period.endingBalance != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ending Balance: ${CurrencyFormatter.format(period.endingBalance!)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusBadge(isOpen: isOpen),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.primaryContainer : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isOpen ? 'OPEN' : 'CLOSED',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
