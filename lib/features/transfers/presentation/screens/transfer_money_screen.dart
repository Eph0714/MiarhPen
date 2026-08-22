import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../application/transfers_provider.dart';
import '../../domain/transfer.dart';

/// Add/edit an account-to-account money transfer. Clearly marked as NOT
/// income/expense via an info banner (spec: transfers must never be
/// counted in income/expense totals).
class TransferMoneyScreen extends ConsumerStatefulWidget {
  final Transfer? editing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const TransferMoneyScreen({
    super.key,
    this.editing,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  ConsumerState<TransferMoneyScreen> createState() =>
      _TransferMoneyScreenState();
}

class _TransferMoneyScreenState extends ConsumerState<TransferMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _date;
  int? _fromAccountId;
  int? _toAccountId;
  String? _accountsError;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _date = editing?.date ?? DateTime.now();
    _fromAccountId = editing?.fromAccountId;
    _toAccountId = editing?.toAccountId;
    if (editing != null) {
      _amountController.text = editing.amount.toString();
      _referenceController.text = editing.referenceNumber ?? '';
      _notesController.text = editing.notes ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final validationError = Validators.differentAccounts(
      _fromAccountId,
      _toAccountId,
    );
    setState(() => _accountsError = validationError);
    if (validationError != null) return;

    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both accounts')),
      );
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    await ref
        .read(addTransferControllerProvider.notifier)
        .submit(
          date: _date,
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          amount: amount,
          referenceNumber: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          editing: widget.editing,
        );

    final state = ref.read(addTransferControllerProvider);
    if (state.hasError) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: ${state.error}')));
      return;
    }

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final submitState = ref.watch(addTransferControllerProvider);
    final isSubmitting = submitState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing != null ? 'Edit Transfer' : 'Transfer Money',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onCancel,
        ),
      ),
      body: LoadingOverlay(
        visible: isSubmitting,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.transfer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  border: Border.all(
                    color: AppColors.transfer.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.transfer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Transfers move money between your own accounts. They are NOT '
                        'counted as income or expense.',
                        style: TextStyle(color: AppColors.transfer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(
                    '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              accountsAsync.when(
                data: (allAccounts) {
                  // Debit cards mirror their linked bank account rather
                  // than holding a balance of their own — transferring
                  // to/from one directly instead of the bank account it's
                  // linked to would silently leave that money out of
                  // every balance-based dashboard figure. Still shown if
                  // it's the account already on this transfer, so editing
                  // an existing one doesn't blank out its selection.
                  final accounts = allAccounts
                      .where((a) => !a.isDebitCard || a.id == _fromAccountId)
                      .toList();
                  final validIds = accounts.map((a) => a.id).toSet();
                  final fromValue = validIds.contains(_fromAccountId)
                      ? _fromAccountId
                      : null;
                  return DropdownButtonFormField<int>(
                    initialValue: fromValue,
                    decoration: const InputDecoration(
                      labelText: 'From Account',
                      helperText:
                          'Debit cards aren\'t listed — use the '
                          'linked bank account instead.',
                      helperMaxLines: 2,
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _fromAccountId = v;
                      _accountsError = null;
                    }),
                    validator: (v) =>
                        v == null ? 'Please select a source account' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Failed to load accounts: $e'),
              ),
              const SizedBox(height: AppSpacing.md),
              accountsAsync.when(
                data: (allAccounts) {
                  final accounts = allAccounts
                      .where((a) => !a.isDebitCard || a.id == _toAccountId)
                      .toList();
                  final validIds = accounts.map((a) => a.id).toSet();
                  final toValue = validIds.contains(_toAccountId)
                      ? _toAccountId
                      : null;
                  return DropdownButtonFormField<int>(
                    initialValue: toValue,
                    decoration: const InputDecoration(
                      labelText: 'To Account',
                      helperText:
                          'Debit cards aren\'t listed — use the '
                          'linked bank account instead.',
                      helperMaxLines: 2,
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _toAccountId = v;
                      _accountsError = null;
                    }),
                    validator: (v) => v == null
                        ? 'Please select a destination account'
                        : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Failed to load accounts: $e'),
              ),
              if (_accountsError != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _accountsError!,
                  style: TextStyle(color: AppColors.expense),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                    color: AppColors.transfer,
                  ),
                ),
                validator: Validators.positiveAmount,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference Number',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.transfer,
                ),
                onPressed: isSubmitting ? null : _save,
                child: const Text('Save'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: isSubmitting ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
