import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

/// Supported page presets for new blank PDFs.
enum PdfCreatePagePreset { a4, letter }

/// Orientation options for new blank PDFs.
enum PdfCreateOrientation { portrait, landscape }

/// Options used when creating a blank PDF document.
final class PdfCreateOptions {
  /// Creates blank-document options.
  const PdfCreateOptions({
    this.pagePreset = PdfCreatePagePreset.a4,
    this.orientation = PdfCreateOrientation.portrait,
    this.pageCount = 1,
  }) : assert(pageCount > 0);

  /// Base page size preset.
  final PdfCreatePagePreset pagePreset;

  /// Page orientation.
  final PdfCreateOrientation orientation;

  /// Number of pages to create.
  final int pageCount;

  /// Resolved page format with the selected orientation applied.
  pdf.PdfPageFormat get pageFormat {
    final baseFormat = switch (pagePreset) {
      PdfCreatePagePreset.a4 => pdf.PdfPageFormat.a4,
      PdfCreatePagePreset.letter => pdf.PdfPageFormat.letter,
    };
    return switch (orientation) {
      PdfCreateOrientation.portrait => baseFormat,
      PdfCreateOrientation.landscape => baseFormat.landscape,
    };
  }
}

/// Creates new blank PDFs for authoring workflows.
final class PdfDocumentCreator {
  /// Builds a blank PDF and returns its bytes.
  Future<Uint8List> createBlankPdf({
    PdfCreateOptions options = const PdfCreateOptions(),
  }) async {
    final document = pw.Document();
    for (var index = 0; index < options.pageCount; index++) {
      document.addPage(
        pw.Page(
          pageFormat: options.pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.SizedBox.expand(),
        ),
      );
    }
    return document.save();
  }
}
