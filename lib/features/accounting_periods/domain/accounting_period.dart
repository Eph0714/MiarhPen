import '../../../core/constants/app_constants.dart';

class AccountingPeriod {
  final int? id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final double beginningBalance;
  final double totalIncome;
  final double totalExpense;
  final double? endingBalance;
  final AccountingPeriodStatus status;
  final DateTime createdAt;
  final DateTime? closedAt;

  const AccountingPeriod({
    this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    this.beginningBalance = 0,
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.endingBalance,
    this.status = AccountingPeriodStatus.open,
    required this.createdAt,
    this.closedAt,
  });

  bool get isOpen => status == AccountingPeriodStatus.open;
  bool get isClosed => status == AccountingPeriodStatus.closed;

  AccountingPeriod copyWith({
    int? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    double? beginningBalance,
    double? totalIncome,
    double? totalExpense,
    double? endingBalance,
    AccountingPeriodStatus? status,
    DateTime? createdAt,
    DateTime? closedAt,
  }) {
    return AccountingPeriod(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      beginningBalance: beginningBalance ?? this.beginningBalance,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      endingBalance: endingBalance ?? this.endingBalance,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  static AccountingPeriodStatus _statusFromStorage(String value) {
    switch (value) {
      case 'CLOSED':
        return AccountingPeriodStatus.closed;
      case 'OPEN':
      default:
        return AccountingPeriodStatus.open;
    }
  }

  static String _statusToStorage(AccountingPeriodStatus status) {
    switch (status) {
      case AccountingPeriodStatus.open:
        return 'OPEN';
      case AccountingPeriodStatus.closed:
        return 'CLOSED';
    }
  }

  factory AccountingPeriod.fromMap(Map<String, Object?> map) {
    return AccountingPeriod(
      id: map['id'] as int?,
      name: map['name'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      beginningBalance: (map['beginning_balance'] as num).toDouble(),
      totalIncome: (map['total_income'] as num).toDouble(),
      totalExpense: (map['total_expense'] as num).toDouble(),
      endingBalance: (map['ending_balance'] as num?)?.toDouble(),
      status: _statusFromStorage(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      closedAt: map['closed_at'] != null
          ? DateTime.parse(map['closed_at'] as String)
          : null,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'beginning_balance': beginningBalance,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'ending_balance': endingBalance,
      'status': _statusToStorage(status),
      'created_at': createdAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}
