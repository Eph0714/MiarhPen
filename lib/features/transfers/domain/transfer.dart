class Transfer {
  final int? id;
  final DateTime date;
  final int fromAccountId;
  final int toAccountId;
  final double amount;
  final String? referenceNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transfer({
    this.id,
    required this.date,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    this.referenceNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Transfer copyWith({
    int? id,
    DateTime? date,
    int? fromAccountId,
    int? toAccountId,
    double? amount,
    String? referenceNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transfer(
      id: id ?? this.id,
      date: date ?? this.date,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Transfer.fromMap(Map<String, Object?> map) {
    return Transfer(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      fromAccountId: map['from_account_id'] as int,
      toAccountId: map['to_account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      referenceNumber: map['reference_number'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'amount': amount,
      'reference_number': referenceNumber,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
