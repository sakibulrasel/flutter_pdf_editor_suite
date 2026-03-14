import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelPdfRendererBridge platform = MethodChannelPdfRendererBridge();
  const MethodChannel channel = MethodChannel('pdf_renderer_bridge');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'openDocument':
              return <Object?, Object?>{'documentId': 7, 'pageCount': 3};
            case 'getPageInfo':
              return <Object?, Object?>{
                'documentId': 7,
                'pageIndex': 0,
                'width': 200.0,
                'height': 400.0,
              };
            case 'renderPage':
              return <Object?, Object?>{
                'documentId': 7,
                'pageIndex': 0,
                'width': 200,
                'height': 400,
                'pngBytes': Uint8List.fromList(<int>[1, 2, 3]),
              };
            case 'closeDocument':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps openDocument response', () async {
    final document = await platform.openDocument(
      const PdfDocumentSource.file('/tmp/sample.pdf'),
    );
    expect(document.documentId, 7);
    expect(document.pageCount, 3);
  });

  test('maps getPageInfo response', () async {
    final page = await platform.getPageInfo(documentId: 7, pageIndex: 0);
    expect(page.width, 200);
    expect(page.height, 400);
  });

  test('maps renderPage response', () async {
    final rendered = await platform.renderPage(
      const PdfRenderRequest(documentId: 7, pageIndex: 0),
    );
    expect(rendered.width, 200);
    expect(rendered.pngBytes, <int>[1, 2, 3]);
  });
}
