import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/account_dao.dart';
import '../../../core/db/daos/expense_category_dao.dart';
import '../../../core/db/daos/income_category_dao.dart';
import '../../../core/db/daos/transaction_dao.dart';
import '../../../core/db/daos/transfer_dao.dart';

/// Column layout produced by [ExportService.exportTransactionsCsv] and
/// [ExportService.exportTransactionsExcel], and expected back by
/// [ExportService.importTransactionsCsv]:
///
/// `Date, Type, Account, Category, Amount, Description, Reference, Notes`
///
/// `Type` is one of `Income`, `Expense`, `Transfer Out`, `Transfer In`.
/// `Category` is blank for transfer rows.
class ExportService {
  static const _csvHeader = [
    'Date',
    'Type',
    'Account',
    'Category',
    'Amount',
    'Description',
    'Reference',
    'Notes',
  ];

  Future<List<List<String>>> _buildRows({DateTime? from, DateTime? to}) async {
    final transactionDao = TransactionDao();
    final transferDao = TransferDao();
    final accountDao = AccountDao();
    final incomeCategoryDao = IncomeCategoryDao();
    final expenseCategoryDao = ExpenseCategoryDao();

    final accounts = {for (final a in await accountDao.getAll()) a.id: a.name};
    final incomeCategories = {
      for (final c in await incomeCategoryDao.getAll()) c.id: c.name,
    };
    final expenseCategories = {
      for (final c in await expenseCategoryDao.getAll()) c.id: c.name,
    };

    final transactions = await transactionDao.getFiltered(from: from, to: to);
    final transfers = await transferDao.getAll(from: from, to: to);

    final dateFmt = DateFormat('yyyy-MM-dd');
    final rows = <List<String>>[];

    for (final t in transactions) {
      final categoryName = t.isIncome
          ? (incomeCategories[t.incomeCategoryId] ?? '')
          : (expenseCategories[t.expenseCategoryId] ?? '');
      rows.add([
        dateFmt.format(t.date),
        t.isIncome ? 'Income' : 'Expense',
        accounts[t.accountId] ?? '',
        categoryName,
        t.amount.toStringAsFixed(2),
        t.description ?? '',
        t.referenceNumber ?? '',
        t.notes ?? '',
      ]);
    }

    for (final tr in transfers) {
      final from = accounts[tr.fromAccountId] ?? '';
      final to = accounts[tr.toAccountId] ?? '';
      rows.add([
        dateFmt.format(tr.date),
        'Transfer Out',
        from,
        '',
        tr.amount.toStringAsFixed(2),
        'Transfer to $to',
        tr.referenceNumber ?? '',
        tr.notes ?? '',
      ]);
      rows.add([
        dateFmt.format(tr.date),
        'Transfer In',
        to,
        '',
        tr.amount.toStringAsFixed(2),
        'Transfer from $from',
        tr.referenceNumber ?? '',
        tr.notes ?? '',
      ]);
    }

    return rows;
  }

  Future<Directory> _exportsDir() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documentsDir.path, 'exports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _timestamp() => DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());

  /// Builds a CSV of transactions + transfers in [from]..[to] (inclusive,
  /// unbounded when null) and writes it under `exports/`. Returns the path.
  Future<String> exportTransactionsCsv({DateTime? from, DateTime? to}) async {
    final rows = await _buildRows(from: from, to: to);
    final csv = const ListToCsvConverter().convert([_csvHeader, ...rows]);

    final dir = await _exportsDir();
    final path = p.join(dir.path, 'miarhpen_transactions_${_timestamp()}.csv');
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }

  /// Builds a single-sheet Excel workbook of transactions + transfers in
  /// [from]..[to] and writes it under `exports/`. Returns the path.
  Future<String> exportTransactionsExcel({DateTime? from, DateTime? to}) async {
    final rows = await _buildRows(from: from, to: to);

    final excel = Excel.createExcel();
    final sheetName = 'Transactions';
    final sheet = excel[sheetName];
    // Excel.createExcel() ships a default 'Sheet1' — drop it once our
    // named sheet exists so the workbook only has the one sheet.
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    sheet.appendRow(_csvHeader.map((h) => TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to build the Excel workbook.');
    }

    final dir = await _exportsDir();
    final path = p.join(dir.path, 'miarhpen_transactions_${_timestamp()}.xlsx');
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// Builds the same MiarhPen-titled PDF used by [exportReportPdf] — a
  /// header with a generated-date stamp, and a table of
  /// [tableHeaders]/[tableRows] — but returns the raw bytes instead of
  /// writing a file. Used directly by the Print Preview action (via the
  /// `printing` package's native preview, which wants bytes, not a path)
  /// so a report can be previewed without leaving a throwaway file behind
  /// for every preview.
  Future<Uint8List> buildReportPdfBytes({
    required String title,
    required List<List<String>> tableRows,
    required List<String> tableHeaders,
  }) async {
    final doc = pw.Document();
    final generatedAt = DateFormat(
      'MMM d, yyyy - h:mm a',
    ).format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  AppConstants.appName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(title, style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Generated: $generatedAt',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: tableHeaders,
            data: tableRows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Generic reusable PDF report builder: a MiarhPen-titled header with a
  /// generated-date stamp, and a table of [tableHeaders]/[tableRows].
  /// Saved under `exports/`. Returns the path.
  Future<String> exportReportPdf({
    required String title,
    required List<List<String>> tableRows,
    required List<String> tableHeaders,
  }) async {
    final bytes = await buildReportPdfBytes(
      title: title,
      tableRows: tableRows,
      tableHeaders: tableHeaders,
    );

    final dir = await _exportsDir();
    final safeTitle = title.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final path = p.join(dir.path, '${safeTitle}_${_timestamp()}.pdf');
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// Generic CSV export for any report screen (Financial Summary, Income,
  /// Expense, Account, Money In/Out) — just a title used for the filename
  /// plus whatever headers/rows the caller has already built for display.
  Future<String> exportGenericCsv({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final csv = const ListToCsvConverter().convert([headers, ...rows]);
    final dir = await _exportsDir();
    final path = p.join(
      dir.path,
      '${_safeFileName(title)}_${_timestamp()}.csv',
    );
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }

  /// Generic single-sheet Excel export, same shape as [exportGenericCsv].
  Future<String> exportGenericExcel({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Report';
    final sheet = excel[sheetName];
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to build the Excel workbook.');
    }
    final dir = await _exportsDir();
    final path = p.join(
      dir.path,
      '${_safeFileName(title)}_${_timestamp()}.xlsx',
    );
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  String _safeFileName(String title) =>
      title.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

  /// Parses a CSV file matching the header layout documented at the top of
  /// this file. Returns parsed rows as maps keyed by header name for the
  /// caller to preview/validate — this method never writes to the DB.
  ///
  /// NOTE: actual insertion should go through `TransactionRepository`
  /// (validating accounts/categories exist, resolving amounts, recomputing
  /// balances, etc.) once that wiring is added later — not direct DAO
  /// writes from here.
  Future<List<Map<String, String>>> importTransactionsCsv(
    String filePath,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('CSV file not found.');
    }
    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.isEmpty) return [];

    final header = rows.first.map((h) => h.toString().trim()).toList();
    final result = <Map<String, String>>[];
    for (final row in rows.skip(1)) {
      if (row.isEmpty ||
          (row.length == 1 && row.first.toString().trim().isEmpty)) {
        continue;
      }
      final map = <String, String>{};
      for (var i = 0; i < header.length && i < row.length; i++) {
        map[header[i]] = row[i]?.toString() ?? '';
      }
      result.add(map);
    }
    return result;
  }
}
