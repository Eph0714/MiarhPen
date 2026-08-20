import 'dart:io';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/recurring_payment.dart';

/// Schedules/cancels the local "due today" alarm/reminder notification for
/// a [RecurringPayment], using a sound the user picked from their own
/// phone's alarm list (see RingtonePickerService) instead of a sound
/// bundled with the app.
///
/// One Android notification channel per payment (`recurring_payment_<id>`)
/// is used because Android 8+ locks a channel's sound at creation time —
/// giving each schedule its own channel lets each one play a different
/// picked sound, and [_ensureChannel] deletes + recreates it on every
/// (re)schedule so changing the sound later actually takes effect.
class RecurringPaymentAlarmService {
  RecurringPaymentAlarmService._internal();
  static final RecurringPaymentAlarmService instance =
      RecurringPaymentAlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Falls back to whatever the `timezone` package defaults to (UTC) —
      // reminders will still fire, just possibly off by the device's UTC
      // offset until this resolves; not worth failing setup over.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    }
    _initialized = true;
  }

  String _channelId(int paymentId) => 'recurring_payment_$paymentId';

  /// (Re)schedules the monthly reminder for [payment]. No-ops on non-
  /// Android platforms (no alarm/notification backend wired up there) and
  /// if [RecurringPayment.alarmEnabled] is false or the payment has no id
  /// yet (must be saved first).
  Future<void> schedule(RecurringPayment payment) async {
    if (!Platform.isAndroid) return;
    final id = payment.id;
    if (id == null || !payment.alarmEnabled) {
      if (id != null) await cancel(id);
      return;
    }

    await _ensureInitialized();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final channelId = _channelId(id);
    final sound = payment.alarmSoundUri != null
        ? UriAndroidNotificationSound(payment.alarmSoundUri!)
        : null;

    // Delete-then-recreate so a changed sound choice actually takes
    // effect — Android locks a channel's sound the first time it's
    // created and silently ignores later changes to the same channel id.
    await android?.deleteNotificationChannel(channelId);
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        'Recurring Payment: ${payment.name}',
        description: 'Reminder for "${payment.name}"',
        importance: Importance.high,
        sound: sound,
      ),
    );

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Recurring Payment: ${payment.name}',
        channelDescription: 'Reminder for "${payment.name}"',
        importance: Importance.high,
        priority: Priority.high,
        sound: sound,
        playSound: true,
      ),
    );

    final scheduled = _nextOccurrence(payment);

    await _plugin.zonedSchedule(
      id,
      payment.name,
      _bodyFor(payment),
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> cancel(int paymentId) async {
    if (!Platform.isAndroid) return;
    await _ensureInitialized();
    await _plugin.cancel(paymentId);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.deleteNotificationChannel(_channelId(paymentId));
  }

  /// Re-schedules every active, alarm-enabled payment — called once on
  /// app start so schedules self-heal after a reboot without needing a
  /// dedicated boot BroadcastReceiver (the app itself re-registers them
  /// the next time it's opened; already-fired/still-pending exact alarms
  /// set via [zonedSchedule] on a previous run also survive reboot on
  /// their own via the plugin's own boot receiver — see AndroidManifest).
  Future<void> rescheduleAll(List<RecurringPayment> payments) async {
    if (!Platform.isAndroid) return;
    for (final payment in payments) {
      if (payment.alarmEnabled) await schedule(payment);
    }
  }

  String _bodyFor(RecurringPayment payment) {
    if (payment.amount != null) {
      return 'Payment due today${payment.description != null ? ' — ${payment.description}' : ''}';
    }
    return payment.description ?? 'Payment due today';
  }

  tz.TZDateTime _nextOccurrence(RecurringPayment payment) {
    final now = tz.TZDateTime.now(tz.local);
    final due = payment.nextDueDate(reference: now);
    final time = payment.startTime ?? const TimeOfDay(hour: 8, minute: 0);

    var occurrence = tz.TZDateTime(
      tz.local,
      due.year,
      due.month,
      due.day,
      time.hour,
      time.minute,
    );
    if (!occurrence.isAfter(now)) {
      final nextMonthRef = DateTime(due.year, due.month + 1, 1);
      final nextDue = payment.nextDueDate(reference: nextMonthRef);
      occurrence = tz.TZDateTime(
        tz.local,
        nextDue.year,
        nextDue.month,
        nextDue.day,
        time.hour,
        time.minute,
      );
    }
    return occurrence;
  }
}
