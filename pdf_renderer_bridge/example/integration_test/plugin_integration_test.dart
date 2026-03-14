import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens bytes and renders first page', (
    WidgetTester tester,
  ) async {
    final PdfRendererBridge plugin = PdfRendererBridge();
    final bytes = _buildSamplePdf();

    final document = await plugin.openDocument(PdfDocumentSource.bytes(bytes));
    final pageInfo = await plugin.getPageInfo(
      documentId: document.documentId,
      pageIndex: 0,
    );
    final rendered = await plugin.renderPage(
      PdfRenderRequest(
        documentId: document.documentId,
        pageIndex: 0,
        scale: 1.5,
      ),
    );

    expect(document.pageCount, 1);
    expect(pageInfo.width, greaterThan(0));
    expect(pageInfo.height, greaterThan(0));
    expect(rendered.width, greaterThan(0));
    expect(rendered.height, greaterThan(0));
    expect(rendered.pngBytes, isNotEmpty);

    await plugin.closeDocument(document.documentId);
  });
}

Uint8List _buildSamplePdf() {
  const streamContent =
      'BT\n/F1 24 Tf\n40 140 Td\n(Phase 1 sample PDF) Tj\nET\n';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 220] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    '<< /Length ${streamContent.length} >>\nstream\n$streamContent'
        'endstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];

  for (var index = 0; index < objects.length; index++) {
    offsets.add(buffer.toString().length);
    buffer.write('${index + 1} 0 obj\n');
    buffer.write(objects[index]);
    buffer.write('\nendobj\n');
  }

  final xrefOffset = buffer.toString().length;
  buffer.write('xref\n');
  buffer.write('0 ${objects.length + 1}\n');
  buffer.write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer\n');
  buffer.write('<< /Root 1 0 R /Size ${objects.length + 1} >>\n');
  buffer.write('startxref\n');
  buffer.write('$xrefOffset\n');
  buffer.write('%%EOF\n');

  return Uint8List.fromList(ascii.encode(buffer.toString()));
}
