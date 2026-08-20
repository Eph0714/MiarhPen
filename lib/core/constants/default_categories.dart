/// Default Income and Expense categories seeded on first-time setup.
/// Spec §11 (Income) and §12 (Expense).
class DefaultCategories {
  DefaultCategories._();

  static const List<String> income = [
    'Sales',
    'Salary',
    'Service Income',
    'Donations',
    'Membership Fees',
    'Interest Income',
    'Other Income',
  ];

  static const List<String> expense = [
    'Food',
    'Transportation',
    'Office Supplies',
    'Utilities',
    'Rent',
    'Salaries',
    'Equipment',
    'Maintenance',
    'Fuel',
    'Other Expenses',
  ];
}
