/// One day's row in the Daily Balance Report: the running cash-position
/// balance carried forward day to day (see `dailyBalanceReportProvider`).
///
/// [beginningBalance] always equals the previous day's [endingBalance] —
/// never entered by hand — and on a day with no transactions,
/// [totalIncome]/[totalExpense] are both zero so [endingBalance] just
/// equals [beginningBalance] unchanged, exactly as a running balance
/// should behave.
class DailyBalanceRow {
  final DateTime date;
  final double beginningBalance;
  final double totalIncome;
  final double totalExpense;
  final double endingBalance;

  const DailyBalanceRow({
    required this.date,
    required this.beginningBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.endingBalance,
  });
}
