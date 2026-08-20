import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/categories_provider.dart';
import '../../domain/expense_category.dart';
import '../../domain/income_category.dart';

/// Create/edit form for an income or expense category, selected via
/// [isIncome]. Pass [existing] (an [IncomeCategory] or [ExpenseCategory],
/// matching [isIncome]) to edit; leave it null to create a new category.
///
/// Navigation is exposed as callbacks ([onSaved], [onCancel]) rather than
/// hardcoded router calls, consistent with the accounts form screen.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({
    super.key,
    required this.isIncome,
    this.existing,
    required this.onSaved,
    required this.onCancel,
  });

  final bool isIncome;
  final dynamic existing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<CategoryFormScreen> createState() =>
      _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(
      text: existing != null ? existing.name as String : '',
    );
    _descriptionController = TextEditingController(
      text: existing != null ? (existing.description as String? ?? '') : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final controller = ref.read(categoryFormControllerProvider);
    final name = _nameController.text.trim();
    final description =
        _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();

    try {
      if (_isEditing) {
        final existing = widget.existing;
        if (widget.isIncome) {
          await controller.updateIncomeCategory(
            existing as IncomeCategory,
            name: name,
            description: description,
          );
        } else {
          await controller.updateExpenseCategory(
            existing as ExpenseCategory,
            name: name,
            description: description,
          );
        }
      } else {
        if (widget.isIncome) {
          await controller.createIncomeCategory(
            name: name,
            description: description,
          );
        } else {
          await controller.createExpenseCategory(
            name: name,
            description: description,
          );
        }
      }
      if (!mounted) return;
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isIncome ? 'Income Category' : 'Expense Category';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit $title' : 'Add $title'),
        leading: IconButton(
          icon: const Icon(Icons.close),
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
                decoration: const InputDecoration(labelText: 'Category Name'),
                validator: (v) => Validators.required(v, fieldName: 'Category name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_isEditing ? 'Save Changes' : 'Add Category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
