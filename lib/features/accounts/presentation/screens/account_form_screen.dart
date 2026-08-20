import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/accounts_provider.dart';
import '../../domain/account.dart';

/// Create/edit form for an [Account]. Pass [existing] to edit; leave it
/// null to create a new account.
///
/// Like [AccountsListScreen], navigation is exposed as callbacks
/// ([onSaved], [onCancel]) rather than hardcoded router calls, so this
/// screen stays reusable regardless of how it's pushed.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({
    super.key,
    this.existing,
    required this.onSaved,
    required this.onCancel,
  });

  final Account? existing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _beginningBalanceController;
  late final TextEditingController _creditLimitController;

  late AccountType _type;
  int? _statementDate;
  int? _dueDate;
  int? _linkedAccountId;

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _beginningBalanceController = TextEditingController(
      text: existing != null ? existing.beginningBalance.toString() : '0',
    );
    _creditLimitController = TextEditingController(
      text: existing?.creditLimit?.toString() ?? '',
    );
    _type = existing?.type ?? AccountType.cash;
    _statementDate = existing?.statementDate;
    _dueDate = existing?.dueDate;
    _linkedAccountId = existing?.linkedAccountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _beginningBalanceController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final controller = ref.read(accountFormControllerProvider);
    try {
      if (_isEditing) {
        await controller.updateAccount(
          widget.existing!,
          name: _nameController.text.trim(),
          type: _type,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          creditLimit: double.tryParse(_creditLimitController.text.trim()),
          statementDate: _statementDate,
          dueDate: _dueDate,
          linkedAccountId: _linkedAccountId,
        );
      } else {
        await controller.createAccount(
          name: _nameController.text.trim(),
          type: _type,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          beginningBalance:
              double.tryParse(_beginningBalanceController.text.trim()) ?? 0,
          creditLimit: double.tryParse(_creditLimitController.text.trim()),
          statementDate: _statementDate,
          dueDate: _dueDate,
          linkedAccountId: _linkedAccountId,
        );
      }
      if (!mounted) return;
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAccountsAsync = ref.watch(activeAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Account' : 'Add Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onCancel,
        ),
      ),
      body: LoadingOverlay(
        visible: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
                validator: (v) =>
                    Validators.required(v, fieldName: 'Account name'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: AccountType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!_isEditing) ...[
                TextFormField(
                  controller: _beginningBalanceController,
                  decoration: const InputDecoration(
                    labelText: 'Beginning Balance',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').trim());
                    if (parsed == null) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ] else ...[
                const Text(
                  'Beginning balance can\'t be edited after creation — '
                  'changing it here would silently reshape historical '
                  'balances that were already calculated from it.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_type == AccountType.creditCard) ...[
                TextFormField(
                  controller: _creditLimitController,
                  decoration: const InputDecoration(labelText: 'Credit Limit'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: Validators.positiveAmount,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _statementDate,
                  decoration: const InputDecoration(
                    labelText: 'Statement Date (day of month)',
                  ),
                  items: List.generate(31, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                      .toList(),
                  onChanged: (value) => setState(() => _statementDate = value),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _dueDate,
                  decoration: const InputDecoration(
                    labelText: 'Due Date (day of month)',
                  ),
                  items: List.generate(31, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                      .toList(),
                  onChanged: (value) => setState(() => _dueDate = value),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_type == AccountType.debitCard) ...[
                activeAccountsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => Text('Failed to load accounts: $e'),
                  data: (accounts) {
                    final bankAccounts = accounts
                        .where((a) => a.type == AccountType.bank)
                        .where((a) => a.id != widget.existing?.id)
                        .toList();
                    return DropdownButtonFormField<int>(
                      initialValue: _linkedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Linked Bank Account',
                      ),
                      items: bankAccounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _linkedAccountId = value),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_isEditing ? 'Save Changes' : 'Add Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
