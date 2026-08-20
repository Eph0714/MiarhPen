import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/balance_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/accounts_provider.dart';
import '../../domain/account.dart';

/// Lists all accounts, grouped by [AccountType], with search and an
/// inactive-accounts toggle.
///
/// This screen deliberately accepts navigation as constructor callbacks
/// ([onTapAccount], [onAddAccount]) rather than calling a router directly,
/// so it stays routing-agnostic and can be wired into whatever navigation
/// stack (go_router, Navigator, etc.) the app composition settles on.
class AccountsListScreen extends ConsumerStatefulWidget {
  const AccountsListScreen({
    super.key,
    required this.onTapAccount,
    required this.onAddAccount,
    this.initialTypeFilter,
  });

  final void Function(Account account) onTapAccount;
  final VoidCallback onAddAccount;

  /// When set (e.g. arrived here via the Dashboard's "Cash On Hand" or
  /// "Cash in Bank" tile), the list opens pre-narrowed to just this
  /// account type instead of showing every group. The user can still
  /// clear it from the on-screen chip to see everything.
  final AccountType? initialTypeFilter;

  @override
  ConsumerState<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends ConsumerState<AccountsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showInactive = false;
  AccountType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialTypeFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider(false));

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAddAccount,
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: accountsAsync.when(
        loading: () =>
            const LoadingOverlay(visible: true, child: SizedBox.expand()),
        error: (error, stack) =>
            Center(child: Text('Failed to load accounts: $error')),
        data: (accounts) {
          var filtered = _query.isEmpty
              ? accounts
              : accounts
                    .where(
                      (a) =>
                          a.name.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList();
          if (_typeFilter != null) {
            filtered = filtered.where((a) => a.type == _typeFilter).toList();
          }

          final active = filtered.where((a) => a.isActive).toList();
          final inactive = filtered.where((a) => !a.isActive).toList();

          if (accounts.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              message:
                  'Add your first cash, bank, or e-wallet account to get started.',
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search accounts',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              if (_typeFilter != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text(_typeFilter!.label),
                      onDeleted: () => setState(() => _typeFilter = null),
                    ),
                  ),
                ),
              Expanded(
                child: active.isEmpty && (!_showInactive || inactive.isEmpty)
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'No matching accounts',
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        children: [
                          ..._buildGroupedSections(active),
                          if (inactive.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _showInactive = !_showInactive,
                              ),
                              icon: Icon(
                                _showInactive
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              label: Text(
                                _showInactive
                                    ? 'Hide inactive (${inactive.length})'
                                    : 'Show inactive (${inactive.length})',
                              ),
                            ),
                            if (_showInactive) ..._buildAccountTiles(inactive),
                          ],
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedSections(List<Account> accounts) {
    final byType = <AccountType, List<Account>>{};
    for (final account in accounts) {
      byType.putIfAbsent(account.type, () => []).add(account);
    }

    final widgets = <Widget>[];
    for (final type in AccountType.values) {
      final group = byType[type];
      if (group == null || group.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            type.label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
      widgets.addAll(_buildAccountTiles(group));
    }
    return widgets;
  }

  List<Widget> _buildAccountTiles(List<Account> accounts) {
    return accounts
        .map(
          (account) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AccountTile(
              account: account,
              onTap: () => widget.onTapAccount(account),
            ),
          ),
        )
        .toList();
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.onTap});

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  account.type.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!account.isActive) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        'Inactive',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      InkWell(
                        onTap: () => ref
                            .read(accountFormControllerProvider)
                            .activateAccount(account.id!),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.chipRadius,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.chipRadius,
                            ),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Activate',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _buildTrailingBalance(context, ref),
        ],
      ),
    );
  }

  Widget _buildTrailingBalance(BuildContext context, WidgetRef ref) {
    if (account.isDebitCard) {
      final linkedId = account.linkedAccountId;
      if (linkedId == null) {
        return const Text('See linked account');
      }
      final linkedAsync = ref.watch(accountByIdProvider(linkedId));
      final linkedName = linkedAsync.maybeWhen(
        data: (linked) => linked?.name,
        orElse: () => null,
      );
      return Text('See ${linkedName ?? 'linked account'}');
    }

    if (account.isCreditCard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Outstanding', style: Theme.of(context).textTheme.bodyMedium),
          BalanceText(
            amount: account.outstandingBalance ?? 0,
            color: AppColors.liability,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Available: ${account.availableCredit?.toStringAsFixed(2) ?? '0.00'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return BalanceText(
      amount: account.currentBalance,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
