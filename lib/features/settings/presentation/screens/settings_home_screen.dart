import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Top-level Settings screen: a grouped list of sections. Routing-agnostic
/// — each row navigates via the callback the caller supplies, so this
/// screen doesn't know or care what navigation stack (go_router, Navigator,
/// etc.) is wired up above it.
class SettingsHomeScreen extends StatelessWidget {
  const SettingsHomeScreen({
    super.key,
    required this.onAccount,
    required this.onAccounting,
    required this.onAccounts,
    required this.onIncomeCategories,
    required this.onExpenseCategories,
    required this.onData,
    required this.onSecurity,
    required this.onAbout,
  });

  final VoidCallback onAccount;
  final VoidCallback onAccounting;
  final VoidCallback onAccounts;
  final VoidCallback onIncomeCategories;
  final VoidCallback onExpenseCategories;
  final VoidCallback onData;
  final VoidCallback onSecurity;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account'),
            subtitle: const Text('Username, password, log out'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAccount,
          ),
          _SectionHeader('Accounting'),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Accounting'),
            subtitle: const Text('Periods, currency'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAccounting,
          ),
          _SectionHeader('Accounts'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Manage Accounts'),
            subtitle: const Text('Cash, bank, cards, e-wallets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAccounts,
          ),
          _SectionHeader('Categories'),
          ListTile(
            leading: const Icon(Icons.arrow_downward_rounded),
            title: const Text('Income Categories'),
            subtitle: const Text('Sales, salary, service income, and more'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onIncomeCategories,
          ),
          ListTile(
            leading: const Icon(Icons.arrow_upward_rounded),
            title: const Text('Expense Categories'),
            subtitle: const Text('Food, transportation, utilities, and more'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onExpenseCategories,
          ),
          _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Data Management'),
            subtitle: const Text('Backup, restore, export, import'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onData,
          ),
          _SectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Security'),
            subtitle: const Text('PIN, biometric, session timeout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onSecurity,
          ),
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('App info, version, privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAbout,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
