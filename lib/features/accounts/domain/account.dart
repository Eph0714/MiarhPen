import '../../../core/constants/app_constants.dart';

class Account {
  final int? id;
  final String name;
  final AccountType type;
  final String? description;
  final double beginningBalance;
  final double currentBalance;
  final double? creditLimit;
  final double? outstandingBalance;
  final int? statementDate; // day-of-month 1-31
  final int? dueDate; // day-of-month 1-31
  final int? linkedAccountId; // debit card -> bank account
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.description,
    this.beginningBalance = 0,
    this.currentBalance = 0,
    this.creditLimit,
    this.outstandingBalance,
    this.statementDate,
    this.dueDate,
    this.linkedAccountId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCreditCard => type == AccountType.creditCard;
  bool get isDebitCard => type == AccountType.debitCard;

  /// Available credit = credit limit - outstanding balance (credit cards only).
  double? get availableCredit {
    if (!isCreditCard) return null;
    return (creditLimit ?? 0) - (outstandingBalance ?? 0);
  }

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    String? description,
    double? beginningBalance,
    double? currentBalance,
    double? creditLimit,
    double? outstandingBalance,
    int? statementDate,
    int? dueDate,
    int? linkedAccountId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      beginningBalance: beginningBalance ?? this.beginningBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      statementDate: statementDate ?? this.statementDate,
      dueDate: dueDate ?? this.dueDate,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Account.fromMap(Map<String, Object?> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: AccountTypeX.fromStorage(map['type'] as String),
      description: map['description'] as String?,
      beginningBalance: (map['beginning_balance'] as num).toDouble(),
      currentBalance: (map['current_balance'] as num).toDouble(),
      creditLimit: (map['credit_limit'] as num?)?.toDouble(),
      outstandingBalance: (map['outstanding_balance'] as num?)?.toDouble(),
      statementDate: map['statement_date'] as int?,
      dueDate: map['due_date'] as int?,
      linkedAccountId: map['linked_account_id'] as int?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type.storageValue,
      'description': description,
      'beginning_balance': beginningBalance,
      'current_balance': currentBalance,
      'credit_limit': creditLimit,
      'outstanding_balance': outstandingBalance,
      'statement_date': statementDate,
      'due_date': dueDate,
      'linked_account_id': linkedAccountId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
