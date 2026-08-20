import '../../../features/recurring_payments/domain/recurring_payment.dart';
import '../../constants/app_constants.dart';
import '../app_database.dart';
import '../db_change_notifier.dart';

class RecurringPaymentDao {
  Future<int> insert(RecurringPayment payment) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('recurring_payments', payment.toMap());
    DbChangeNotifier.instance.notify(DbTable.recurringPayments);
    return id;
  }

  Future<int> update(RecurringPayment payment) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'recurring_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
    DbChangeNotifier.instance.notify(DbTable.recurringPayments);
    return count;
  }

  Future<RecurringPayment?> getById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'recurring_payments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RecurringPayment.fromMap(rows.first);
  }

  /// All active schedules, soonest day-of-month first.
  Future<List<RecurringPayment>> getAll({bool activeOnly = true}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'recurring_payments',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'day_of_month ASC, name ASC',
    );
    return rows.map(RecurringPayment.fromMap).toList();
  }

  /// Flips a schedule's status for the current cycle. Marking PAID records
  /// today as [RecurringPayment.lastPaidDate]; this does NOT itself create
  /// a transaction — it is only a reminder/schedule record.
  Future<int> setStatus(int id, RecurringPaymentStatus status) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'recurring_payments',
      {
        'status': status == RecurringPaymentStatus.paid ? 'PAID' : 'UNPAID',
        if (status == RecurringPaymentStatus.paid)
          'last_paid_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.recurringPayments);
    return count;
  }

  /// Soft-disable only, consistent with categories/accounts — never
  /// hard-deletes a schedule the user has history against.
  Future<int> disable(int id) async {
    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'recurring_payments',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    DbChangeNotifier.instance.notify(DbTable.recurringPayments);
    return count;
  }
}
