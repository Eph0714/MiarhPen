import '../../../core/constants/default_categories.dart';
import '../../../core/db/daos/expense_category_dao.dart';
import '../../../core/db/daos/income_category_dao.dart';

/// Seeds the built-in default income/expense categories on app startup.
///
/// Safe to call unconditionally on every app start: [IncomeCategoryDao] and
/// [ExpenseCategoryDao].seedDefaults already skip any name that already
/// exists (the `name` column is UNIQUE), so this never duplicates rows.
Future<void> seedDefaultCategoriesIfNeeded() async {
  await IncomeCategoryDao().seedDefaults(DefaultCategories.income);
  await ExpenseCategoryDao().seedDefaults(DefaultCategories.expense);
}
