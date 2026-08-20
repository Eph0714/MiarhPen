import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/recurring_payments_provider.dart';
import '../../domain/recurring_payment.dart';

/// Lists every active recurring payment schedule (e.g. "Payment of Housing
/// Loan, every 6 of the month, 08:00 AM - 05:00 PM, Unpaid"), soonest
/// day-of-month first, with a tap-to-toggle paid/unpaid status.
class RecurringPaymentsListScreen extends ConsumerWidget {
  const RecurringPaymentsListScreen({
    super.key,
    required this.onCreateNew,
    required this.onTapPayment,
  });

  final VoidCallback onCreateNew;
  final void Function(RecurringPayment) onTapPayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(recurringPaymentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Payments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreateNew,
        icon: const Icon(Icons.add),
        label: const Text('New Schedule'),
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text('Failed to load recurring payments: $err')),
        data: (payments) {
          if (payments.isEmpty) {
            return EmptyState(
              icon: Icons.event_repeat_outlined,
              title: 'No recurring payments yet',
              message:
                  'Set up a schedule for bills like a housing loan or '
                  'subscription so you never miss a due date.',
              action: FilledButton(
                onPressed: onCreateNew,
                child: const Text('Add Recurring Payment'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _RecurringPaymentRow(
                payment: payment,
                onTap: () => onTapPayment(payment),
                onToggleStatus: () {
                  final next = payment.isPaid
                      ? RecurringPaymentStatus.unpaid
                      : RecurringPaymentStatus.paid;
                  ref
                      .read(recurringPaymentControllerProvider)
                      .setStatus(payment.id!, next);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _RecurringPaymentRow extends StatelessWidget {
  const _RecurringPaymentRow({
    required this.payment,
    required this.onTap,
    required this.onToggleStatus,
  });

  final RecurringPayment payment;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final scheduleLine = 'Every ${_ordinal(payment.dayOfMonth)} of the month';
    final timeLine = payment.startTime != null && payment.endTime != null
        ? 'Time: ${_formatTime(payment.startTime!)} to ${_formatTime(payment.endTime!)}'
        : null;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  scheduleLine,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (timeLine != null) ...[
                  const SizedBox(height: 2),
                  Text(timeLine, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (payment.amount != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    CurrencyFormatter.format(payment.amount!),
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
          _StatusBadge(isPaid: payment.isPaid, onTap: onToggleStatus),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPaid, required this.onTap});

  final bool isPaid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isPaid ? AppColors.income : AppColors.liability;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          isPaid ? 'PAID' : 'UNPAID',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
