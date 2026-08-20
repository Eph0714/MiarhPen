import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data_management/application/export_service.dart';

/// App bar action that lets any report be printed/exported as PDF, Excel,
/// or CSV, then shared/saved via the OS share sheet (which on Android
/// includes "Print" for PDFs through any installed print service).
///
/// Routing/report-agnostic: the report screen supplies its own [title]
/// and a [rowsBuilder] that returns the current filtered data as plain
/// string rows matching [headers] — this widget only handles the
/// format choice, file generation, and sharing.
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
              title: const Text('Export as PDF'),
              subtitle: const Text('Also lets you print, via the share sheet'),
              onTap: () => Navigator.of(context).pop('pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export as Excel'),
              onTap: () => Navigator.of(context).pop('excel'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Export as CSV'),
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
    return IconButton(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Print / Export',
      onPressed: _showFormatPicker,
    );
  }
}
