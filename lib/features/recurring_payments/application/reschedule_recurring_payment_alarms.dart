import '../../../core/db/daos/recurring_payment_dao.dart';
import 'recurring_payment_alarm_service.dart';

/// Re-registers every active, alarm-enabled recurring payment's reminder
/// with Android's AlarmManager. Safe/idempotent to call on every app
/// start (fire-and-forget from app.dart's initState, same as the other
/// startup repair passes) — this is how schedules "self-heal" after a
/// device reboot or app update without needing a dedicated boot
/// BroadcastReceiver of our own.
Future<void> rescheduleRecurringPaymentAlarmsIfNeeded() async {
  final dao = RecurringPaymentDao();
  final payments = await dao.getAll();
  await RecurringPaymentAlarmService.instance.rescheduleAll(payments);
}
