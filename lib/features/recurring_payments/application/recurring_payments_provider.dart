import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/recurring_payment_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../domain/recurring_payment.dart';
import 'recurring_payment_alarm_service.dart';

final recurringPaymentDaoProvider = Provider<RecurringPaymentDao>(
  (ref) => RecurringPaymentDao(),
);

/// All active recurring payment schedules, soonest day-of-month first.
final recurringPaymentsProvider =
    StreamProvider.autoDispose<List<RecurringPayment>>((ref) {
      final dao = ref.watch(recurringPaymentDaoProvider);
      return DbChangeNotifier.instance
          .watch(DbTable.recurringPayments)
          .asyncMap((_) => dao.getAll());
    });

/// A single schedule by id, kept live via the recurringPayments table
/// stream — used by the edit form.
final recurringPaymentByIdProvider = StreamProvider.autoDispose
    .family<RecurringPayment?, int>((ref, id) {
      final dao = ref.watch(recurringPaymentDaoProvider);
      return DbChangeNotifier.instance
          .watch(DbTable.recurringPayments)
          .asyncMap((_) => dao.getById(id));
    });

class RecurringPaymentController {
  RecurringPaymentController(this._dao, this._alarmService);

  final RecurringPaymentDao _dao;
  final RecurringPaymentAlarmService _alarmService;

  Future<int> create({
    required String name,
    String? description,
    double? amount,
    int? accountId,
    int? expenseCategoryId,
    required int dayOfMonth,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool alarmEnabled = false,
    String? alarmSoundUri,
    String? alarmSoundName,
  }) async {
    final now = DateTime.now();
    final payment = RecurringPayment(
      name: name,
      description: description,
      amount: amount,
      accountId: accountId,
      expenseCategoryId: expenseCategoryId,
      dayOfMonth: dayOfMonth,
      startTime: startTime,
      endTime: endTime,
      alarmEnabled: alarmEnabled,
      alarmSoundUri: alarmSoundUri,
      alarmSoundName: alarmSoundName,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _dao.insert(payment);
    await _alarmService.schedule(payment.copyWith(id: id));
    return id;
  }

  Future<void> save(RecurringPayment payment) async {
    final updated = payment.copyWith(updatedAt: DateTime.now());
    await _dao.update(updated);
    await _alarmService.schedule(updated);
  }

  Future<void> setStatus(int id, RecurringPaymentStatus status) {
    return _dao.setStatus(id, status);
  }

  Future<void> disable(int id) async {
    await _dao.disable(id);
    await _alarmService.cancel(id);
  }
}

final recurringPaymentControllerProvider = Provider<RecurringPaymentController>(
  (ref) => RecurringPaymentController(
    ref.watch(recurringPaymentDaoProvider),
    RecurringPaymentAlarmService.instance,
  ),
);
