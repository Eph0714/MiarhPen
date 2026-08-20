import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_range_presets.dart';

/// Immutable filter used by [transactionsFilteredProvider] and the
/// transaction history screen's filter bar. All fields are nullable ("no
/// constraint"). Implements `==`/`hashCode` so it can be used directly as a
/// Riverpod `.family` argument.
class TransactionFilter {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? accountId;
  final int? categoryId;
  final TransactionType? type;
  final String? searchText;
  final DateRangePreset preset;

  const TransactionFilter({
    this.dateFrom,
    this.dateTo,
    this.accountId,
    this.categoryId,
    this.type,
    this.searchText,
    this.preset = DateRangePreset.thisMonth,
  });

  /// Builds a filter with [dateFrom]/[dateTo] resolved from [preset] (unless
  /// [preset] is [DateRangePreset.custom], in which case the caller-supplied
  /// dates are used as-is).
  factory TransactionFilter.fromPreset(
    DateRangePreset preset, {
    DateTime? dateFrom,
    DateTime? dateTo,
    int? accountId,
    int? categoryId,
    TransactionType? type,
    String? searchText,
  }) {
    if (preset == DateRangePreset.custom) {
      return TransactionFilter(
        dateFrom: dateFrom,
        dateTo: dateTo,
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        searchText: searchText,
        preset: preset,
      );
    }
    final range = preset.range();
    return TransactionFilter(
      dateFrom: range.start,
      dateTo: range.end,
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      searchText: searchText,
      preset: preset,
    );
  }

  TransactionFilter copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    int? accountId,
    int? categoryId,
    TransactionType? type,
    String? searchText,
    DateRangePreset? preset,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearAccountId = false,
    bool clearCategoryId = false,
    bool clearType = false,
    bool clearSearchText = false,
  }) {
    return TransactionFilter(
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      type: clearType ? null : (type ?? this.type),
      searchText: clearSearchText ? null : (searchText ?? this.searchText),
      preset: preset ?? this.preset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionFilter &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo &&
        other.accountId == accountId &&
        other.categoryId == categoryId &&
        other.type == type &&
        other.searchText == searchText &&
        other.preset == preset;
  }

  @override
  int get hashCode => Object.hash(
    dateFrom,
    dateTo,
    accountId,
    categoryId,
    type,
    searchText,
    preset,
  );
}
