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

  group('typed errors', () {
    void throwFromNative(String code) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(code: code, message: 'native $code');
          });
    }

    test('password_required becomes PdfPasswordRequiredException', () {
      throwFromNative('password_required');
      expect(
        platform.openDocument(const PdfDocumentSource.file('/tmp/a.pdf')),
        throwsA(isA<PdfPasswordRequiredException>()),
      );
    });

    test('file_not_found becomes PdfFileNotFoundException with path', () {
      throwFromNative('file_not_found');
      expect(
        platform.openDocument(const PdfDocumentSource.file('/tmp/a.pdf')),
        throwsA(
          isA<PdfFileNotFoundException>().having(
            (error) => error.path,
            'path',
            '/tmp/a.pdf',
          ),
        ),
      );
    });

    test('invalid_pdf becomes PdfInvalidDocumentException', () {
      throwFromNative('invalid_pdf');
      expect(
        platform.openDocument(const PdfDocumentSource.file('/tmp/a.pdf')),
        throwsA(isA<PdfInvalidDocumentException>()),
      );
    });

    test('other codes become PdfRenderException with the code', () {
      throwFromNative('pdf_renderer_error');
      expect(
        platform.renderPage(
          const PdfRenderRequest(documentId: 1, pageIndex: 0),
        ),
        throwsA(
          isA<PdfRenderException>().having(
            (error) => error.code,
            'code',
            'pdf_renderer_error',
          ),
        ),
      );
    });

    test('missing native plugin becomes PdfUnsupportedPlatformException', () {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(
        platform.openDocument(const PdfDocumentSource.file('/tmp/a.pdf')),
        throwsA(isA<PdfUnsupportedPlatformException>()),
      );
    });

    test('all typed errors are PdfExceptions', () {
      throwFromNative('anything');
      expect(
        platform.getPageInfo(documentId: 1, pageIndex: 0),
        throwsA(isA<PdfException>()),
      );
    });
  });
}
