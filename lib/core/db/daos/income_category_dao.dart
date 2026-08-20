import '../../../features/categories/domain/income_category.dart';
import '../app_database.dart';
import '../db_change_notifier.dart';

class IncomeCategoryDao {
  Future<int> insert(IncomeCategory category) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('income_categories', category.toMap());
    DbChangeNotifier.instance.notify(DbTable.incomeCategories);
    return id;
  }

  Future<int> update(IncomeCategory category) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'income_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    DbChangeNotifier.instance.notify(DbTable.incomeCategories);
    return count;
  }

  Future<IncomeCategory?> getById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'income_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IncomeCategory.fromMap(rows.first);
  }

  Future<List<IncomeCategory>> getAll({bool activeOnly = false}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'income_categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(IncomeCategory.fromMap).toList();
  }

  Future<List<IncomeCategory>> search(String query) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'income_categories',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return rows.map(IncomeCategory.fromMap).toList();
  }

  /// Soft-disable only — categories may have transaction history, so no
  /// hard-delete method is provided.
  Future<int> disable(int id) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'income_categories',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.incomeCategories);
    return count;
  }

  /// Inserts each name as a default, active category, skipping any name
  /// that already exists (the `name` column is UNIQUE).
  Future<void> seedDefaults(List<String> names) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final name in names) {
      final existing = await db.query(
        'income_categories',
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      batch.insert('income_categories', {
        'name': name,
        'description': null,
        'is_active': 1,
        'is_default': 1,
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
    DbChangeNotifier.instance.notify(DbTable.incomeCategories);
  }
}
