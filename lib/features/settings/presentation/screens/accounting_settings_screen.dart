import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/daos/accounting_period_dao.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/application/auth_provider.dart';

/// Local fallback provider — the accounting_periods feature may expose its
/// own `openPeriodProvider`, but this screen only needs a simple read of
/// the currently open period, so it defines its own here rather than
/// depending on that feature's application layer.
final _accountingPeriodDaoProvider = Provider((ref) => AccountingPeriodDao());

final _openPeriodProvider = FutureProvider((ref) {
  return ref.watch(_accountingPeriodDaoProvider).getOpenPeriod();
});

/// Accounting settings: current open period summary, currency (read-only
/// for now), and a button to manage accounting periods.
class AccountingSettingsScreen extends ConsumerWidget {
  const AccountingSettingsScreen({super.key, required this.onManagePeriods});

  final VoidCallback onManagePeriods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openPeriodAsync = ref.watch(_openPeriodProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounting')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Current Period', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: openPeriodAsync.when(
              data: (period) {
                if (period == null) {
                  return const Text('No accounting period is currently open.');
                }
                final dateRange = period.endDate != null
                    ? '${DateFormatter.short(period.startDate)} - ${DateFormatter.short(period.endDate!)}'
                    : 'Since ${DateFormatter.short(period.startDate)}';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(period.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(dateRange, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Unable to load the current period.'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Currency', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: currentUserAsync.when(
              data: (user) => Row(
                children: [
                  Text(
                    user?.currencySymbol ?? '-',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    user?.currencyCode ?? '-',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Unable to load currency.'),
            ),
          ),
          // TODO: allow changing currency mid-stream — would need to update
          // AppUser.currencyCode/currencySymbol via UserDao, and likely warn
          // about mixing currencies across existing transaction history.
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onManagePeriods,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Manage Accounting Periods'),
            ),
          ),
        ],
      ),
    );
  }
}
