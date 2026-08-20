import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/categories_provider.dart';
import '../../domain/expense_category.dart';
import '../../domain/income_category.dart';

/// Lists income or expense categories (chosen via [isIncome]), with search
/// and a disable action for non-default categories.
///
/// Navigation is exposed as callbacks ([onAdd], [onEditCategory]) rather
/// than hardcoded router calls, so this screen stays routing-agnostic —
/// consistent with the accounts screens in this app.
class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({
    super.key,
    required this.isIncome,
    required this.onAdd,
    required this.onEditCategory,
  });

  final bool isIncome;
  final VoidCallback onAdd;
  final void Function(dynamic category) onEditCategory;

  @override
  ConsumerState<CategoryListScreen> createState() =>
      _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncCategories = widget.isIncome
        ? ref.watch(incomeCategoriesStreamProvider)
        : ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isIncome ? 'Income Categories' : 'Expense Categories'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: asyncCategories.when(
        loading: () =>
            const LoadingOverlay(visible: true, child: SizedBox.expand()),
        error: (error, stack) =>
            Center(child: Text('Failed to load categories: $error')),
        data: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              title: widget.isIncome
                  ? 'No income categories yet'
                  : 'No expense categories yet',
              message: 'Add one to start categorizing your transactions.',
            );
          }

          final filtered = _query.isEmpty
              ? categories
              : categories
                  .where((c) => _nameOf(c).toLowerCase().contains(_query.toLowerCase()))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search categories',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'No matching categories',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final category = filtered[index];
                          return _CategoryTile(
                            name: _nameOf(category),
                            description: _descriptionOf(category),
                            isDefault: _isDefaultOf(category),
                            onTap: () => widget.onEditCategory(category),
                            onDisable: () => _confirmDisable(context, category),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _nameOf(dynamic category) => category.name as String;
  String? _descriptionOf(dynamic category) => category.description as String?;
  bool _isDefaultOf(dynamic category) => category.isDefault as bool;

  Future<void> _confirmDisable(BuildContext context, dynamic category) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Disable Category',
      message: 'Disable "${_nameOf(category)}"? It will no longer appear when '
          'recording new transactions.',
      confirmLabel: 'Disable',
      destructive: true,
    );
    if (!confirmed) return;

    final controller = ref.read(categoryFormControllerProvider);
    final id = category.id as int;
    if (category is IncomeCategory) {
      await controller.disableIncomeCategory(id);
    } else if (category is ExpenseCategory) {
      await controller.disableExpenseCategory(id);
    }
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.description,
    required this.isDefault,
    required this.onTap,
    required this.onDisable,
  });

  final String name;
  final String? description;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
            tooltip: 'Disable',
            onPressed: onDisable,
          ),
        ],
      ),
    );
  }
}
