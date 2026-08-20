import '../../../core/constants/app_constants.dart';

class TransactionEntry {
  final int? id;
  final TransactionType type;
  final DateTime date;
  final int accountId;
  final int? incomeCategoryId;
  final int? expenseCategoryId;
  final double amount;
  final String? description;
  final String? referenceNumber;
  final String? notes;
  final String? attachmentPath;
  final int? accountingPeriodId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionEntry({
    this.id,
    required this.type,
    required this.date,
    required this.accountId,
    this.incomeCategoryId,
    this.expenseCategoryId,
    required this.amount,
    this.description,
    this.referenceNumber,
    this.notes,
    this.attachmentPath,
    this.accountingPeriodId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  /// Whichever category id is populated, depending on [type].
  int? get categoryId => incomeCategoryId ?? expenseCategoryId;

  TransactionEntry copyWith({
    int? id,
    TransactionType? type,
    DateTime? date,
    int? accountId,
    int? incomeCategoryId,
    int? expenseCategoryId,
    double? amount,
    String? description,
    String? referenceNumber,
    String? notes,
    String? attachmentPath,
    int? accountingPeriodId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      incomeCategoryId: incomeCategoryId ?? this.incomeCategoryId,
      expenseCategoryId: expenseCategoryId ?? this.expenseCategoryId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      accountingPeriodId: accountingPeriodId ?? this.accountingPeriodId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static TransactionType _typeFromStorage(String value) {
    switch (value) {
      case 'EXPENSE':
        return TransactionType.expense;
      case 'INCOME':
      default:
        return TransactionType.income;
    }
  }

  static String _typeToStorage(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'INCOME';
      case TransactionType.expense:
        return 'EXPENSE';
    }
  }

  factory TransactionEntry.fromMap(Map<String, Object?> map) {
    return TransactionEntry(
      id: map['id'] as int?,
      type: _typeFromStorage(map['type'] as String),
      date: DateTime.parse(map['date'] as String),
      accountId: map['account_id'] as int,
      incomeCategoryId: map['income_category_id'] as int?,
      expenseCategoryId: map['expense_category_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      referenceNumber: map['reference_number'] as String?,
      notes: map['notes'] as String?,
      attachmentPath: map['attachment_path'] as String?,
      accountingPeriodId: map['accounting_period_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'type': _typeToStorage(type),
      'date': date.toIso8601String(),
      'account_id': accountId,
      'income_category_id': incomeCategoryId,
      'expense_category_id': expenseCategoryId,
      'amount': amount,
      'description': description,
      'reference_number': referenceNumber,
      'notes': notes,
      'attachment_path': attachmentPath,
      'accounting_period_id': accountingPeriodId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
