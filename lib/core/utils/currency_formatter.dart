import 'package:intl/intl.dart';

/// Formats [double] amounts as currency strings for display.
class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {String symbol = '₱'}) {
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  /// Compact form for tight spaces (e.g. dashboard tiles), like "₱1.2K".
  static String formatCompact(double amount, {String symbol = '₱'}) {
    final formatter = NumberFormat.compactCurrency(symbol: symbol);
    return formatter.format(amount);
  }
}
