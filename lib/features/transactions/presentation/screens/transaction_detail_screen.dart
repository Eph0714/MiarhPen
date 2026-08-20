import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../../categories/application/categories_provider.dart';
import '../../application/transactions_provider.dart';
import '../../domain/transaction_entry.dart';

/// Full detail view for a single income/expense transaction: all fields,
/// attachment viewer (tap to view full image), Edit and Delete actions.
class TransactionDetailScreen extends ConsumerWidget {
  final int transactionId;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;
  final VoidCallback onClose;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    required this.onEdit,
    required this.onDeleted,
    required this.onClose,
  });

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry entry,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Transaction',
      message:
          'Are you sure you want to delete this transaction? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    await ref.read(addTransactionControllerProvider.notifier).delete(entry);
    onDeleted();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(transactionByIdProvider(transactionId));
    final submitState = ref.watch(addTransactionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: onClose),
      ),
      body: LoadingOverlay(
        visible: submitState.isLoading,
        child: entryAsync.when(
          data: (entry) {
            if (entry == null) {
              return const Center(child: Text('Transaction not found'));
            }
            final isIncome = entry.isIncome;
            final color = isIncome ? AppColors.income : AppColors.expense;
            final accountAsync = ref.watch(
              accountByIdProvider(entry.accountId),
            );
            final incomeCategoriesAsync = ref.watch(
              incomeCategoriesStreamProvider,
            );
            final expenseCategoriesAsync = ref.watch(
              expenseCategoriesStreamProvider,
            );
            final categoryNameAsync = isIncome
                ? incomeCategoriesAsync.whenData((cats) {
                    for (final c in cats) {
                      if (c.id == entry.categoryId) return c.name;
                    }
                    return '—';
                  })
                : expenseCategoriesAsync.whenData((cats) {
                    for (final c in cats) {
                      if (c.id == entry.categoryId) return c.name;
                    }
                    return '—';
                  });

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isIncome ? '+' : '-'}${CurrencyFormatter.format(entry.amount)}',
                        style: Theme.of(
                          context,
                        ).textTheme.displayMedium?.copyWith(color: color),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        isIncome ? 'Income' : 'Expense',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Date', DateFormatter.long(entry.date)),
                      _detailRow(
                        'Category',
                        categoryNameAsync.maybeWhen(
                          data: (name) => name,
                          orElse: () => '…',
                        ),
                      ),
                      _detailRow(
                        'Account',
                        accountAsync.maybeWhen(
                          data: (a) => a?.name ?? '—',
                          orElse: () => '…',
                        ),
                      ),
                      if (entry.description != null &&
                          entry.description!.isNotEmpty)
                        _detailRow('Description', entry.description!),
                      if (entry.referenceNumber != null &&
                          entry.referenceNumber!.isNotEmpty)
                        _detailRow('Reference Number', entry.referenceNumber!),
                      if (entry.notes != null && entry.notes!.isNotEmpty)
                        _detailRow('Notes', entry.notes!),
                    ],
                  ),
                ),
                if (entry.attachmentPath != null &&
                    entry.attachmentPath!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attachment',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        GestureDetector(
                          onTap: () =>
                              _viewFullImage(context, entry.attachmentPath!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.buttonRadius,
                            ),
                            child: Image.file(
                              File(entry.attachmentPath!),
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: const BorderSide(color: AppColors.expense),
                  ),
                  onPressed: () => _handleDelete(context, ref, entry),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Failed to load: $e')),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _viewFullImage(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        child: InteractiveViewer(child: Image.file(File(path))),
      ),
    );
  }
}
