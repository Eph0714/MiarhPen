/// Reusable form-field validators, each returning `null` when the value is
/// valid (matching Flutter's `FormField.validator` signature) or an error
/// message otherwise.
class Validators {
  Validators._();

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? positiveAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a valid amount';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid amount';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than zero';
    }
    return null;
  }

  static String? differentAccounts(int? fromAccountId, int? toAccountId) {
    if (fromAccountId != null &&
        toAccountId != null &&
        fromAccountId == toAccountId) {
      return 'Source and destination accounts must be different';
    }
    return null;
  }
}

/// Returns true if [lastSubmitAt] falls within [window] of now — a simple
/// duplicate-submit guard callers can check before allowing a save action
/// to proceed.
bool isDuplicateSubmitGuardTripped(
  DateTime? lastSubmitAt, {
  Duration window = const Duration(seconds: 2),
}) {
  if (lastSubmitAt == null) return false;
  return DateTime.now().difference(lastSubmitAt) < window;
}
