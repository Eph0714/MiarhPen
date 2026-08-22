import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data_management/application/export_service.dart';

/// A pair of app bar actions dropped into every report screen — a
/// **Download** button (PDF/Excel/CSV, saved then handed to the OS share
/// sheet, which on Android includes "Save to Downloads"/"Save to
/// Drive") and a **Print Preview** button (opens the native print
/// preview straight from the report's PDF, no intermediate file to
/// manage) — so both actions are consistent across every report without
/// each screen reimplementing them.
///
/// Routing/report-agnostic: the report screen supplies its own [title]
/// and a [rowsBuilder] that returns the current filtered data as plain
/// string rows matching [headers] — this widget only handles the
/// format choice, file generation, preview, and sharing.
class ReportExportButton extends StatefulWidget {
  const ReportExportButton({
    super.key,
    required this.title,
    required this.headers,
    required this.rowsBuilder,
  });

  final String title;
  final List<String> headers;
  final Future<List<List<String>>> Function() rowsBuilder;

  @override
  State<ReportExportButton> createState() => _ReportExportButtonState();
}

class _ReportExportButtonState extends State<ReportExportButton> {
  final _exportService = ExportService();
  bool _busy = false;

  Future<void> _printPreview() async {
    setState(() => _busy = true);
    try {
      final rows = await widget.rowsBuilder();
      final bytes = await _exportService.buildReportPdfBytes(
        title: widget.title,
        tableHeaders: widget.headers,
        tableRows: rows,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: widget.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Print preview failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(String format) async {
    setState(() => _busy = true);
    try {
      final rows = await widget.rowsBuilder();
      final String path;
      switch (format) {
        case 'pdf':
          path = await _exportService.exportReportPdf(
            title: widget.title,
            tableHeaders: widget.headers,
            tableRows: rows,
          );
        case 'excel':
          path = await _exportService.exportGenericExcel(
            title: widget.title,
            headers: widget.headers,
            rows: rows,
          );
        case 'csv':
          path = await _exportService.exportGenericCsv(
            title: widget.title,
            headers: widget.headers,
            rows: rows,
          );
        default:
          return;
      }
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: widget.title),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showFormatPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Download as PDF'),
              onTap: () => Navigator.of(context).pop('pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Download as Excel'),
              onTap: () => Navigator.of(context).pop('excel'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Download as CSV'),
              onTap: () => Navigator.of(context).pop('csv'),
            ),
          ],
        ),
      ),
    );
    if (choice != null) await _export(choice);
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.print_outlined),
          tooltip: 'Print Preview',
          onPressed: _printPreview,
        ),
        IconButton(
          icon: const Icon(Icons.download_outlined),
          tooltip: 'Download',
          onPressed: _showFormatPicker,
        ),
      ],
    );
  }
}
