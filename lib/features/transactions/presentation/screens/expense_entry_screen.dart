import 'package:flutter/material.dart';

import '../../domain/transaction_entry.dart';
import '_transaction_entry_form.dart';

/// Add/edit an expense entry. Thin wrapper around the shared
/// `_TransactionEntryForm` (see `_transaction_entry_form.dart`), pinned to
/// `isIncome: false`.
class ExpenseEntryScreen extends StatelessWidget {
  final TransactionEntry? editing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const ExpenseEntryScreen({
    super.key,
    this.editing,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return TransactionEntryForm(
      isIncome: false,
      editing: editing,
      onSaved: onSaved,
      onCancel: onCancel,
    );
  }
}
