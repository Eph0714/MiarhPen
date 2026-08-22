/// One dated line in an [AccountStatement]'s ledger: a single income
/// transaction, expense transaction, or transfer leg posted to that
/// account, with the running balance immediately after it.
class AccountStatementRow {
  final DateTime date;
  final String description;
  final double cashIn;
  final double cashOut;
  final double balance;

  const AccountStatementRow({
    required this.date,
    required this.description,
    required this.cashIn,
    required this.cashOut,
    required this.balance,
  });
}

/// The totals block shown under an [AccountStatement]'s ledger — e.g.
/// "Eph Cash Summary: Beginning Balance / Current Balance / Total Cash
/// In / Total Cash Out".
class AccountStatementSummary {
  final double beginningBalance;
  final double endingBalance;
  final double totalCashIn;
  final double totalCashOut;

  const AccountStatementSummary({
    required this.beginningBalance,
    required this.endingBalance,
    required this.totalCashIn,
    required this.totalCashOut,
  });
}

/// A single account's statement for a date range: the balance it opened
/// the range with, every dated line item within the range with a
/// running balance, and the totals summary.
class AccountStatement {
  final String accountName;
  final AccountStatementSummary summary;
  final List<AccountStatementRow> rows;

  const AccountStatement({
    required this.accountName,
    required this.summary,
    required this.rows,
  });
}
