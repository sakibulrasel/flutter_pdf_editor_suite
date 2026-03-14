import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

enum PdfCreatePagePreset { a4, letter }

enum PdfCreateOrientation { portrait, landscape }

final class PdfCreateOptions {
  const PdfCreateOptions({
    this.pagePreset = PdfCreatePagePreset.a4,
    this.orientation = PdfCreateOrientation.portrait,
    this.pageCount = 1,
  }) : assert(pageCount > 0);

  final PdfCreatePagePreset pagePreset;
  final PdfCreateOrientation orientation;
  final int pageCount;

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

final class PdfDocumentCreator {
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
