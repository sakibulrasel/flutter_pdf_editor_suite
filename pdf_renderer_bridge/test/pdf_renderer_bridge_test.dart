import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge_platform_interface.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPdfRendererBridgePlatform
    with MockPlatformInterfaceMixin
    implements PdfRendererBridgePlatform {
  @override
  Future<void> closeDocument(int documentId) async {}

  @override
  Future<PdfPageInfo> getPageInfo({
    required int documentId,
    required int pageIndex,
  }) async {
    return PdfPageInfo(
      documentId: documentId,
      pageIndex: pageIndex,
      width: 300,
      height: 600,
    );
  }

  @override
  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source) async {
    return const PdfDocumentInfo(documentId: 9, pageCount: 4);
  }

  @override
  Future<PdfRenderedPage> renderPage(PdfRenderRequest request) async {
    return PdfRenderedPage(
      documentId: request.documentId,
      pageIndex: request.pageIndex,
      width: 300,
      height: 600,
      pngBytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
  }
}

void main() {
  final PdfRendererBridgePlatform initialPlatform =
      PdfRendererBridgePlatform.instance;

  test('$MethodChannelPdfRendererBridge is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPdfRendererBridge>());
  });

  test('openDocument delegates to platform', () async {
    PdfRendererBridge pdfRendererBridgePlugin = PdfRendererBridge();
    MockPdfRendererBridgePlatform fakePlatform =
        MockPdfRendererBridgePlatform();
    PdfRendererBridgePlatform.instance = fakePlatform;

    final document = await pdfRendererBridgePlugin.openDocument(
      const PdfDocumentSource.file('/tmp/sample.pdf'),
    );
    expect(document.documentId, 9);
    expect(document.pageCount, 4);
  });
}
