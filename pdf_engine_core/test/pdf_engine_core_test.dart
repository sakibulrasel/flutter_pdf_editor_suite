import 'dart:typed_data';

import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:test/test.dart';

void main() {
  test('creates file and bytes document sources', () {
    const fileSource = PdfDocumentSource.file('/tmp/sample.pdf');
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    final memorySource = PdfDocumentSource.bytes(bytes);

    expect(fileSource.type, PdfDocumentSourceType.file);
    expect(fileSource.path, '/tmp/sample.pdf');
    expect(fileSource.bytes, isNull);

    expect(memorySource.type, PdfDocumentSourceType.bytes);
    expect(memorySource.path, isNull);
    expect(memorySource.bytes, same(bytes));
  });

  test('stores render request and rendered page metadata', () {
    const request = PdfRenderRequest(
      documentId: 7,
      pageIndex: 2,
      scale: 2.5,
      backgroundColor: 0xFF000000,
    );
    final renderedPage = PdfRenderedPage(
      documentId: 7,
      pageIndex: 2,
      width: 320,
      height: 480,
      pngBytes: Uint8List.fromList(<int>[137, 80, 78, 71]),
    );

    expect(request.documentId, 7);
    expect(request.pageIndex, 2);
    expect(request.scale, 2.5);
    expect(request.backgroundColor, 0xFF000000);

    expect(renderedPage.width, 320);
    expect(renderedPage.height, 480);
    expect(renderedPage.pngBytes, isNotEmpty);
  });

  test('maps between screen space and PDF space', () {
    const pageInfo = PdfPageInfo(
      documentId: 7,
      pageIndex: 0,
      width: 300,
      height: 200,
    );
    const viewport = PdfPageViewport(
      pageInfo: pageInfo,
      renderedWidth: 600,
      renderedHeight: 400,
    );

    const screenPoint = PdfPoint(x: 150, y: 100);
    final pdfPoint = viewport.screenToPdf(screenPoint);
    final roundTripPoint = viewport.pdfToScreen(pdfPoint);

    expect(pdfPoint.x, 75);
    expect(pdfPoint.y, 50);
    expect(roundTripPoint.x, 150);
    expect(roundTripPoint.y, 100);
  });

  test('stores text overlay bounds and style data', () {
    final overlay = PdfTextOverlay(
      id: 'text_1',
      pageIndex: 2,
      bounds: const PdfRect(left: 10, top: 20, width: 80, height: 24),
      text: 'Hello',
      fontSize: 18,
      color: 0xFF2563EB,
    );

    expect(overlay.type, PdfOverlayType.text);
    expect(overlay.pageIndex, 2);
    expect(overlay.bounds.right, 90);
    expect(overlay.bounds.bottom, 44);
    expect(overlay.text, 'Hello');
    expect(overlay.fontSize, 18);
    expect(overlay.color, 0xFF2563EB);
  });
}
