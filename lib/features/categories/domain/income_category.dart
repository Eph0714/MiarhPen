class IncomeCategory {
  final int? id;
  final String name;
  final String? description;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;

  const IncomeCategory({
    this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.isDefault = false,
    required this.createdAt,
  });

  IncomeCategory copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return IncomeCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory IncomeCategory.fromMap(Map<String, Object?> map) {
    return IncomeCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int) == 1,
      isDefault: (map['is_default'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
