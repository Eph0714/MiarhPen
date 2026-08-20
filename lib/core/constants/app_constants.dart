/// App-wide constants for MiarhPen.
class AppConstants {
  AppConstants._();

  static const String appName = 'MiarhPen';
  static const String tagline = 'Simple. Accurate. In Control.';
  static const String poweredBy = 'Powered By EMF IT Solutions';
  static const String establishedYear = 'Est. 2026';

  static const String defaultCurrencyCode = 'PHP';
  static const String defaultCurrencySymbol = '₱';

  static const int defaultSessionTimeoutMinutes = 5;
  static const int minPinLength = 4;
  static const int maxPinLength = 6;

  static const String dbFileName = 'miarhpen.db';
  // v2 adds the `recurring_payments` table; v3 adds its alarm_* columns.
  // Both are additive-only migrations — see AppDatabase.onUpgrade —
  // existing tables/rows are never touched.
  static const int dbVersion = 3;
}

/// Account types per spec section 9.
enum AccountType {
  cash,
  bank,
  debitCard,
  creditCard,
  gcash,
  maya,
  paypal,
  otherEWallet,
  otherOnlinePayment,
  custom,
}

extension AccountTypeX on AccountType {
  String get label {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.debitCard:
        return 'Debit Card';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.gcash:
        return 'GCash';
      case AccountType.maya:
        return 'Maya';
      case AccountType.paypal:
        return 'PayPal';
      case AccountType.otherEWallet:
        return 'Other E-Wallet';
      case AccountType.otherOnlinePayment:
        return 'Other Online Payment';
      case AccountType.custom:
        return 'Custom';
    }
  }

  String get storageValue => name;

  static AccountType fromStorage(String value) {
    return AccountType.values.firstWhere(
      (e) => e.storageValue == value,
      orElse: () => AccountType.custom,
    );
  }

  /// Whether this account type counts toward "Total Available Funds".
  /// Credit cards are liabilities, not cash — excluded (spec §22, §29).
  /// Debit cards mirror their linked bank account and carry no balance of
  /// their own — excluded to avoid double counting (spec §21).
  bool get countsTowardAvailableFunds =>
      this != AccountType.creditCard && this != AccountType.debitCard;
}

enum TransactionType { income, expense }

enum HistoryEntryType { income, expense, transferIn, transferOut }

enum AccountingPeriodStatus { open, closed }

/// Payment status for a [RecurringPayment] schedule entry, e.g. "Payment of
/// Housing Loan" for the current cycle.
enum RecurringPaymentStatus { unpaid, paid }
