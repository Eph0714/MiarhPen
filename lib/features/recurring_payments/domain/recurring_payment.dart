import 'package:flutter/material.dart' show TimeOfDay;

import '../../../core/constants/app_constants.dart';

/// A recurring payment schedule entry — e.g. "Payment of Housing Loan,
/// every 6 of the month, 08:00 AM - 05:00 PM, Unpaid". Purely a reminder/
/// schedule record: marking one [RecurringPaymentStatus.paid] does NOT
/// itself create a transaction — the user still records the actual
/// Add Expense entry separately, same as any other expense.
class RecurringPayment {
  final int? id;
  final String name;
  final String? description;
  final double? amount;
  final int? accountId;
  final int? expenseCategoryId;

  /// Day of month this payment recurs on (1-31). Months shorter than the
  /// chosen day (e.g. day 31 in February) are handled by the UI clamping
  /// to that month's last day when computing the next due date.
  final int dayOfMonth;

  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final RecurringPaymentStatus status;
  final bool isActive;
  final DateTime? lastPaidDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringPayment({
    this.id,
    required this.name,
    this.description,
    this.amount,
    this.accountId,
    this.expenseCategoryId,
    required this.dayOfMonth,
    this.startTime,
    this.endTime,
    this.status = RecurringPaymentStatus.unpaid,
    this.isActive = true,
    this.lastPaidDate,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPaid => status == RecurringPaymentStatus.paid;
  bool get isUnpaid => status == RecurringPaymentStatus.unpaid;

  /// This cycle's due date: [dayOfMonth] within the given [reference]
  /// month (defaults to now), clamped to the last day of that month.
  DateTime nextDueDate({DateTime? reference}) {
    final ref = reference ?? DateTime.now();
    final lastDayOfMonth = DateTime(ref.year, ref.month + 1, 0).day;
    final day = dayOfMonth > lastDayOfMonth ? lastDayOfMonth : dayOfMonth;
    return DateTime(ref.year, ref.month, day);
  }

  RecurringPayment copyWith({
    int? id,
    String? name,
    String? description,
    double? amount,
    int? accountId,
    int? expenseCategoryId,
    int? dayOfMonth,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    RecurringPaymentStatus? status,
    bool? isActive,
    DateTime? lastPaidDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringPayment(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      expenseCategoryId: expenseCategoryId ?? this.expenseCategoryId,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static RecurringPaymentStatus _statusFromStorage(String value) {
    switch (value) {
      case 'PAID':
        return RecurringPaymentStatus.paid;
      case 'UNPAID':
      default:
        return RecurringPaymentStatus.unpaid;
    }
  }

  static String _statusToStorage(RecurringPaymentStatus status) {
    switch (status) {
      case RecurringPaymentStatus.paid:
        return 'PAID';
      case RecurringPaymentStatus.unpaid:
        return 'UNPAID';
    }
  }

  static TimeOfDay? _timeFromStorage(Object? value) {
    if (value == null) return null;
    final parts = (value as String).split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String? _timeToStorage(TimeOfDay? time) {
    if (time == null) return null;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  factory RecurringPayment.fromMap(Map<String, Object?> map) {
    return RecurringPayment(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      accountId: map['account_id'] as int?,
      expenseCategoryId: map['expense_category_id'] as int?,
      dayOfMonth: map['day_of_month'] as int,
      startTime: _timeFromStorage(map['start_time']),
      endTime: _timeFromStorage(map['end_time']),
      status: _statusFromStorage(map['status'] as String),
      isActive: (map['is_active'] as int) == 1,
      lastPaidDate: map['last_paid_date'] != null
          ? DateTime.parse(map['last_paid_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'amount': amount,
      'account_id': accountId,
      'expense_category_id': expenseCategoryId,
      'day_of_month': dayOfMonth,
      'start_time': _timeToStorage(startTime),
      'end_time': _timeToStorage(endTime),
      'status': _statusToStorage(status),
      'is_active': isActive ? 1 : 0,
      'last_paid_date': lastPaidDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
