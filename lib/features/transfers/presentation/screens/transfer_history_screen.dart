import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../application/transfers_provider.dart';
import '../../domain/transfer.dart';

/// List of all account-to-account transfers: date, from -> to account
/// names, amount, reference number, notes.
class TransferHistoryScreen extends ConsumerWidget {
  final void Function(Transfer) onTapTransfer;

  const TransferHistoryScreen({super.key, required this.onTapTransfer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfersAsync = ref.watch(
      transfersStreamProvider(const TransfersFilter()),
    );
    final accountsAsync = ref.watch(accountsStreamProvider(false));

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer History')),
      body: transfersAsync.when(
        data: (transfers) {
          if (transfers.isEmpty) {
            return const EmptyState(
              icon: Icons.swap_horiz_rounded,
              title: 'No transfers yet',
              message: 'Move money between your accounts to see it here.',
            );
          }

          String accountName(int? id) {
            return accountsAsync.maybeWhen(
              data: (accounts) {
                for (final a in accounts) {
                  if (a.id == id) return a.name;
                }
                return 'Unknown Account';
              },
              orElse: () => '…',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: transfers.length,
            itemBuilder: (context, index) {
              final t = transfers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => onTapTransfer(t),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.transfer.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.transfer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${accountName(t.fromAccountId)} → ${accountName(t.toAccountId)}',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                DateFormatter.short(t.date),
                                if (t.referenceNumber != null &&
                                    t.referenceNumber!.isNotEmpty)
                                  t.referenceNumber!,
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (t.notes != null && t.notes!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                t.notes!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        CurrencyFormatter.format(t.amount),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.transfer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Failed to load transfers: $e')),
      ),
    );
  }
}
