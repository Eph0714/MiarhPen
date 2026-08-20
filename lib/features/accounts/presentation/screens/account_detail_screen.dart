import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/accounts_provider.dart';
import '../../domain/account.dart';

/// Shows an account's header (name, type, balance) plus an optional
/// transactions section injected from outside this file, with Edit and
/// Disable actions in the app bar.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({
    super.key,
    required this.accountId,
    this.transactionsSection,
    this.onEdit,
    this.onDisabled,
  });

  final int accountId;

  // TODO: wired by the transactions feature — this screen just needs to
  // exist and compile for now, the transactions agent will not edit this
  // file, so this parameter is the clearly-marked extension point: pass a
  // widget here from app-level composition to render the real "Recent
  // Transactions" list below the header without touching this file.
  final Widget? transactionsSection;

  /// Routing-agnostic navigation to the edit form — omitted (null) means
  /// no Edit action is shown.
  final VoidCallback? onEdit;

  /// Called after the account is successfully disabled (e.g. to pop back
  /// to the accounts list) — omitted (null) means no Disable action is
  /// shown.
  final VoidCallback? onDisabled;

  Future<void> _confirmDisable(
    BuildContext context,
    WidgetRef ref,
    String accountName,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Disable Account',
      message:
          'Disable "$accountName"? It will no longer appear when recording '
          'new transactions, but its history is kept.',
      confirmLabel: 'Disable',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(accountFormControllerProvider).disableAccount(accountId);
    onDisabled?.call();
  }

  Future<void> _activate(WidgetRef ref) async {
    await ref.read(accountFormControllerProvider).activateAccount(accountId);
  }

  Future<void> _adjustBeginningBalance(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final controller = TextEditingController(
      text: account.beginningBalance.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    final newValue = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adjust Beginning Balance'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Correct the starting figure for "${account.name}". The '
                'account\'s current balance will be recalculated from this '
                'new starting point plus its full transaction history — '
                'never overwritten directly.',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'New Beginning Balance',
                ),
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').trim());
                  if (parsed == null) return 'Enter a valid amount';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(
                dialogContext,
              ).pop(double.parse(controller.text.trim()));
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (newValue == null || newValue == account.beginningBalance) return;

    final delta = newValue - account.beginningBalance;
    final projectedBalance = account.currentBalance + delta;
    if (!context.mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm Adjustment',
      message:
          'Beginning balance will change from '
          '${CurrencyFormatter.format(account.beginningBalance)} to '
          '${CurrencyFormatter.format(newValue)}.\n\n'
          'Current balance will update from '
          '${CurrencyFormatter.format(account.currentBalance)} to '
          '${CurrencyFormatter.format(projectedBalance)}.',
      confirmLabel: 'Confirm',
    );
    if (!confirmed) return;

    await ref
        .read(accountFormControllerProvider)
        .adjustBeginningBalance(account, newValue);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountByIdProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
        actions: [
          accountAsync.maybeWhen(
            data: (account) {
              if (account == null) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit?.call();
                  } else if (value == 'disable') {
                    _confirmDisable(context, ref, account.name);
                  } else if (value == 'adjust_balance') {
                    _adjustBeginningBalance(context, ref, account);
                  } else if (value == 'activate') {
                    _activate(ref);
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'adjust_balance',
                    child: Text('Adjust Beginning Balance'),
                  ),
                  if (onDisabled != null && account.isActive)
                    const PopupMenuItem(
                      value: 'disable',
                      child: Text('Disable'),
                    ),
                  if (!account.isActive)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Text('Activate'),
                    ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: accountAsync.when(
        loading: () =>
            const LoadingOverlay(visible: true, child: SizedBox.expand()),
        error: (error, stack) =>
            Center(child: Text('Failed to load account: $error')),
        data: (account) {
          if (account == null) {
            return const Center(child: Text('Account not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                account.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                account.type.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (account.isCreditCard)
                _CreditCardSummary(
                  creditLimit: account.creditLimit ?? 0,
                  outstanding: account.outstandingBalance ?? 0,
                  available: account.availableCredit ?? 0,
                )
              else
                BalanceText(amount: account.currentBalance),
              if (!account.isActive) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'This account is inactive.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _activate(ref),
                      child: const Text('Activate'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              transactionsSection ??
                  Text(
                    'Transactions will appear here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _CreditCardSummary extends StatelessWidget {
  const _CreditCardSummary({
    required this.creditLimit,
    required this.outstanding,
    required this.available,
  });

  final double creditLimit;
  final double outstanding;
  final double available;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, 'Credit Limit', creditLimit, AppColors.textPrimary),
        const SizedBox(height: AppSpacing.sm),
        _row(context, 'Outstanding', outstanding, AppColors.liability),
        const SizedBox(height: AppSpacing.sm),
        _row(context, 'Available Credit', available, AppColors.primary),
      ],
    );
  }

  Widget _row(BuildContext context, String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        BalanceText(
          amount: amount,
          color: color,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}
