import '../../../core/utils/date_range_presets.dart';

/// Immutable date filter used by every report screen/provider in
/// `lib/features/reports/`. Wraps a [DateRangePreset] plus optional custom
/// bounds (only meaningful when [preset] is [DateRangePreset.custom]).
class ReportDateFilter {
  final DateRangePreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;

  const ReportDateFilter({
    this.preset = DateRangePreset.thisMonth,
    this.customFrom,
    this.customTo,
  });

  /// Resolves this filter to a concrete (start, end) range.
  ///
  /// Delegates to [DateRangePresetX.range] for every preset except
  /// [DateRangePreset.custom], for which [customFrom]/[customTo] are used
  /// as-is. Throws a [StateError] if [preset] is custom but either bound is
  /// missing.
  ({DateTime start, DateTime end}) resolve() {
    if (preset == DateRangePreset.custom) {
      if (customFrom == null || customTo == null) {
        throw StateError(
          'ReportDateFilter.resolve(): preset is DateRangePreset.custom but '
          'customFrom/customTo were not both supplied.',
        );
      }
      return (start: customFrom!, end: customTo!);
    }
    return preset.range();
  }

  ReportDateFilter copyWith({
    DateRangePreset? preset,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearCustomFrom = false,
    bool clearCustomTo = false,
  }) {
    return ReportDateFilter(
      preset: preset ?? this.preset,
      customFrom: clearCustomFrom ? null : (customFrom ?? this.customFrom),
      customTo: clearCustomTo ? null : (customTo ?? this.customTo),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReportDateFilter &&
        other.preset == preset &&
        other.customFrom == customFrom &&
        other.customTo == customTo;
  }

  @override
  int get hashCode => Object.hash(preset, customFrom, customTo);
}
