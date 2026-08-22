import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Full-screen, pinch-to-zoom preview of a report's PDF, with print and
/// share actions built into the `printing` package's own [PdfPreview]
/// widget — unlike [Printing.layoutPdf] (which just hands the bytes
/// straight to the OS print dialog, whose own preview pane isn't
/// pinch-zoomable from inside MiarhPen), this renders the PDF in-app so
/// the report can actually be zoomed in/out before printing or sharing.
class PrintPreviewScreen extends StatelessWidget {
  const PrintPreviewScreen({
    super.key,
    required this.title,
    required this.bytes,
  });

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (format) async => bytes,
        pdfFileName: title,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}
