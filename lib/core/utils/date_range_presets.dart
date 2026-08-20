/// Common date-range presets used by filters/reports throughout the app.
enum DateRangePreset {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

/// Human-readable labels and concrete date ranges for each
/// [DateRangePreset].
extension DateRangePresetX on DateRangePreset {
  String get label {
    switch (this) {
      case DateRangePreset.today:
        return 'Today';
      case DateRangePreset.yesterday:
        return 'Yesterday';
      case DateRangePreset.thisWeek:
        return 'This Week';
      case DateRangePreset.lastWeek:
        return 'Last Week';
      case DateRangePreset.thisMonth:
        return 'This Month';
      case DateRangePreset.lastMonth:
        return 'Last Month';
      case DateRangePreset.thisYear:
        return 'This Year';
      case DateRangePreset.custom:
        return 'Custom Range';
    }
  }

  /// Computes the (start 00:00:00, end 23:59:59) range for this preset,
  /// relative to [now] (defaults to [DateTime.now]).
  ///
  /// Weeks start on Monday. [DateRangePreset.custom] is only meaningful to
  /// the caller (who supplies its own range) and throws
  /// [UnsupportedError] here.
  ({DateTime start, DateTime end}) range({DateTime? now}) {
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime endOfDay(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59);

    switch (this) {
      case DateRangePreset.today:
        return (start: startOfToday, end: endOfDay(today));
      case DateRangePreset.yesterday:
        final yesterday = startOfToday.subtract(const Duration(days: 1));
        return (start: yesterday, end: endOfDay(yesterday));
      case DateRangePreset.thisWeek:
        final monday = startOfToday.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        final sunday = monday.add(const Duration(days: 6));
        return (start: startOfDay(monday), end: endOfDay(sunday));
      case DateRangePreset.lastWeek:
        final thisMonday = startOfToday.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        final lastMonday = thisMonday.subtract(const Duration(days: 7));
        final lastSunday = lastMonday.add(const Duration(days: 6));
        return (start: startOfDay(lastMonday), end: endOfDay(lastSunday));
      case DateRangePreset.thisMonth:
        final start = DateTime(today.year, today.month, 1);
        final end = DateTime(today.year, today.month + 1, 0);
        return (start: start, end: endOfDay(end));
      case DateRangePreset.lastMonth:
        final start = DateTime(today.year, today.month - 1, 1);
        final end = DateTime(today.year, today.month, 0);
        return (start: start, end: endOfDay(end));
      case DateRangePreset.thisYear:
        final start = DateTime(today.year, 1, 1);
        final end = DateTime(today.year, 12, 31);
        return (start: start, end: endOfDay(end));
      case DateRangePreset.custom:
        throw UnsupportedError(
          'DateRangePreset.custom has no computed range; the caller must '
          'supply its own start/end dates.',
        );
    }
  }
}
