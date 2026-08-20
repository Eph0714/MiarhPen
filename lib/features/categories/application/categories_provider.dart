import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/expense_category_dao.dart';
import '../../../core/db/daos/income_category_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../domain/expense_category.dart';
import '../domain/income_category.dart';

final incomeCategoryDaoProvider = Provider<IncomeCategoryDao>(
  (ref) => IncomeCategoryDao(),
);

final expenseCategoryDaoProvider = Provider<ExpenseCategoryDao>(
  (ref) => ExpenseCategoryDao(),
);

final incomeCategoriesStreamProvider =
    StreamProvider.autoDispose<List<IncomeCategory>>((ref) {
      final dao = ref.watch(incomeCategoryDaoProvider);
      return DbChangeNotifier.instance
          .watch(DbTable.incomeCategories)
          .asyncMap((_) => dao.getAll());
    });

final expenseCategoriesStreamProvider =
    StreamProvider.autoDispose<List<ExpenseCategory>>((ref) {
      final dao = ref.watch(expenseCategoryDaoProvider);
      return DbChangeNotifier.instance
          .watch(DbTable.expenseCategories)
          .asyncMap((_) => dao.getAll());
    });

/// Handles create/update/disable for both income and expense categories.
/// Mutations rely on the DAOs' own [DbChangeNotifier] calls to refresh the
/// streams above — no manual invalidation needed.
class CategoryFormController {
  CategoryFormController(this._incomeDao, this._expenseDao);

  final IncomeCategoryDao _incomeDao;
  final ExpenseCategoryDao _expenseDao;

  Future<void> createIncomeCategory({
    required String name,
    String? description,
  }) async {
    await _incomeDao.insert(
      IncomeCategory(
        name: name,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateIncomeCategory(
    IncomeCategory existing, {
    String? name,
    String? description,
  }) async {
    await _incomeDao.update(
      existing.copyWith(
        name: name ?? existing.name,
        description: description ?? existing.description,
      ),
    );
  }

  Future<void> disableIncomeCategory(int id) async {
    await _incomeDao.disable(id);
  }

  Future<void> createExpenseCategory({
    required String name,
    String? description,
  }) async {
    await _expenseDao.insert(
      ExpenseCategory(
        name: name,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateExpenseCategory(
    ExpenseCategory existing, {
    String? name,
    String? description,
  }) async {
    await _expenseDao.update(
      existing.copyWith(
        name: name ?? existing.name,
        description: description ?? existing.description,
      ),
    );
  }

  Future<void> disableExpenseCategory(int id) async {
    await _expenseDao.disable(id);
  }
}

final categoryFormControllerProvider = Provider<CategoryFormController>((ref) {
  return CategoryFormController(
    ref.watch(incomeCategoryDaoProvider),
    ref.watch(expenseCategoryDaoProvider),
  );
});
