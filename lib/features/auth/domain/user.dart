class AppUser {
  final int? id;
  final String username;
  final String passwordHash;
  final String? passwordSalt;
  final String? pinHash;
  final bool biometricEnabled;
  final bool rememberMe;
  final int sessionTimeoutMin;
  final String currencyCode;
  final String currencySymbol;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    this.id,
    required this.username,
    required this.passwordHash,
    this.passwordSalt,
    this.pinHash,
    this.biometricEnabled = false,
    this.rememberMe = false,
    this.sessionTimeoutMin = 5,
    this.currencyCode = 'PHP',
    this.currencySymbol = '₱',
    required this.createdAt,
    required this.updatedAt,
  });

  AppUser copyWith({
    int? id,
    String? username,
    String? passwordHash,
    String? passwordSalt,
    String? pinHash,
    bool? biometricEnabled,
    bool? rememberMe,
    int? sessionTimeoutMin,
    String? currencyCode,
    String? currencySymbol,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      pinHash: pinHash ?? this.pinHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      rememberMe: rememberMe ?? this.rememberMe,
      sessionTimeoutMin: sessionTimeoutMin ?? this.sessionTimeoutMin,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: map['id'] as int?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      passwordSalt: map['password_salt'] as String?,
      pinHash: map['pin_hash'] as String?,
      biometricEnabled: (map['biometric_enabled'] as int) == 1,
      rememberMe: (map['remember_me'] as int) == 1,
      sessionTimeoutMin: map['session_timeout_min'] as int,
      currencyCode: map['currency_code'] as String,
      currencySymbol: map['currency_symbol'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'pin_hash': pinHash,
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'remember_me': rememberMe ? 1 : 0,
      'session_timeout_min': sessionTimeoutMin,
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
