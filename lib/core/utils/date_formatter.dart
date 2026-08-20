import 'package:intl/intl.dart';

/// Formats [DateTime] values into the app's standard display/storage
/// string formats.
class DateFormatter {
  DateFormatter._();

  static String short(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  static String long(DateTime d) => DateFormat('MMMM d, yyyy').format(d);

  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

  /// Stable, sortable format for DB storage: 'yyyy-MM-dd'.
  static String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}
