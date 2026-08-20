import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../../categories/application/categories_provider.dart';
import '../../application/transactions_provider.dart';
import '../../domain/transaction_entry.dart';
import '../widgets/attachment_picker.dart';

/// Shared form used by both [IncomeEntryScreen] and [ExpenseEntryScreen] —
/// ~90% identical between income/expense, parameterized by [isIncome].
class TransactionEntryForm extends ConsumerStatefulWidget {
  final bool isIncome;
  final TransactionEntry? editing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const TransactionEntryForm({
    super.key,
    required this.isIncome,
    this.editing,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  ConsumerState<TransactionEntryForm> createState() =>
      _TransactionEntryFormState();
}

class _TransactionEntryFormState extends ConsumerState<TransactionEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _date;
  int? _accountId;
  int? _categoryId;
  String? _attachmentPath;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _date = editing?.date ?? DateTime.now();
    _accountId = editing?.accountId;
    _categoryId = editing?.categoryId;
    _attachmentPath = editing?.attachmentPath;
    if (editing != null) {
      _amountController.text = editing.amount.toString();
      _descriptionController.text = editing.description ?? '';
      _referenceController.text = editing.referenceNumber ?? '';
      _notesController.text = editing.notes ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
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
    if (_accountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an account')));
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    await ref
        .read(addTransactionControllerProvider.notifier)
        .submit(
          isIncome: widget.isIncome,
          date: _date,
          accountId: _accountId!,
          categoryId: _categoryId!,
          amount: amount,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          referenceNumber: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          attachmentPath: _attachmentPath,
          accountingPeriodId: widget.editing?.accountingPeriodId,
          editing: widget.editing,
        );

    final state = ref.read(addTransactionControllerProvider);
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
    final isIncome = widget.isIncome;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final accountsAsync = ref.watch(activeAccountsProvider);
    // Income/expense categories are distinct model types with no shared
    // interface, so both branches are normalized to a common (id, name)
    // record here rather than exposing the raw model to the dropdown below.
    final categoriesAsync = isIncome
        ? ref
              .watch(incomeCategoriesStreamProvider)
              .whenData(
                (cats) => cats.map((c) => (id: c.id, name: c.name)).toList(),
              )
        : ref
              .watch(expenseCategoriesStreamProvider)
              .whenData(
                (cats) => cats.map((c) => (id: c.id, name: c.name)).toList(),
              );
    final submitState = ref.watch(addTransactionControllerProvider);
    final isSubmitting = submitState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing != null
              ? (isIncome ? 'Edit Income' : 'Edit Expense')
              : (isIncome ? 'Add Income' : 'Add Expense'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
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
              categoriesAsync.when(
                data: (categories) {
                  final validIds = categories.map((c) => c.id).toSet();
                  final value = validIds.contains(_categoryId)
                      ? _categoryId
                      : null;
                  return DropdownButtonFormField<int>(
                    initialValue: value,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) =>
                        v == null ? 'Please select a category' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Failed to load categories: $e'),
              ),
              const SizedBox(height: AppSpacing.md),
              accountsAsync.when(
                data: (accounts) {
                  final validIds = accounts.map((a) => a.id).toSet();
                  final value = validIds.contains(_accountId)
                      ? _accountId
                      : null;
                  return DropdownButtonFormField<int>(
                    initialValue: value,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _accountId = v),
                    validator: (v) =>
                        v == null ? 'Please select an account' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Failed to load accounts: $e'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.payments_outlined, color: color),
                ),
                validator: Validators.positiveAmount,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
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
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: AttachmentPicker(
                  initialPath: _attachmentPath,
                  onChanged: (path) => setState(() => _attachmentPath = path),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: color),
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
