import 'package:flutter/material.dart';

import '../../domain/transaction_entry.dart';
import '_transaction_entry_form.dart';

/// Add/edit an income entry. Thin wrapper around the shared
/// `_TransactionEntryForm` (see `_transaction_entry_form.dart`), pinned to
/// `isIncome: true`.
class IncomeEntryScreen extends StatelessWidget {
  final TransactionEntry? editing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const IncomeEntryScreen({
    super.key,
    this.editing,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return TransactionEntryForm(
      isIncome: true,
      editing: editing,
      onSaved: onSaved,
      onCancel: onCancel,
    );
  }
}
