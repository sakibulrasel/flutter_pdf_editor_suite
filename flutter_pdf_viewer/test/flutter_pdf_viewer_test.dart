import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:flutter_pdf_editor_viewer/flutter_pdf_editor_viewer.dart';

class _FakePdfRendererBridgePlatform
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
      height: 200 + (pageIndex * 20),
    );
  }

  @override
  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source) async {
    return const PdfDocumentInfo(documentId: 1, pageCount: 3);
  }

  @override
  Future<PdfRenderedPage> renderPage(PdfRenderRequest request) async {
    return PdfRenderedPage(
      documentId: request.documentId,
      pageIndex: request.pageIndex,
      width: 1,
      height: 1,
      pngBytes: Uint8List.fromList(_transparentImage),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PdfRendererBridgePlatform.instance = _FakePdfRendererBridgePlatform();
  });

  testWidgets('renders a PDF page image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PdfPageView(source: PdfDocumentSource.file('/tmp/sample.pdf')),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders multi-page viewer and updates controller state', (
    tester,
  ) async {
    final controller = PdfViewerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: PdfViewer(
              source: const PdfDocumentSource.file('/tmp/sample.pdf'),
              controller: controller,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.currentPage.value, 2);
  });

  testWidgets('tracks the last page near the end of scroll extent', (
    tester,
  ) async {
    final controller = PdfViewerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: PdfViewer(
              source: const PdfDocumentSource.file('/tmp/sample.pdf'),
              controller: controller,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
    await tester.pumpAndSettle();

    expect(controller.currentPage.value, 3);
  });

  testWidgets('tracks the first page near the top of scroll extent', (
    tester,
  ) async {
    final controller = PdfViewerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: PdfViewer(
              source: const PdfDocumentSource.file('/tmp/sample.pdf'),
              controller: controller,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
    await tester.pumpAndSettle();
    expect(controller.currentPage.value, 3);

    await tester.fling(find.byType(ListView), const Offset(0, 2000), 3000);
    await tester.pumpAndSettle();

    expect(controller.currentPage.value, 1);
  });

  testWidgets('reports PDF coordinates for page taps', (tester) async {
    PdfPageTapDetails? tapDetails;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: PdfViewer(
              source: const PdfDocumentSource.file('/tmp/sample.pdf'),
              onPageTap: (details) {
                tapDetails = details;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tapAt(const Offset(180, 160));
    await tester.pump();

    expect(tapDetails, isNotNull);
    expect(tapDetails!.pageInfo.pageIndex, 0);
    expect(tapDetails!.pdfPosition.x, greaterThanOrEqualTo(0));
    expect(tapDetails!.pdfPosition.x, lessThanOrEqualTo(300));
    expect(tapDetails!.pdfPosition.y, greaterThanOrEqualTo(0));
    expect(tapDetails!.pdfPosition.y, lessThanOrEqualTo(200));
  });

  testWidgets('renders inside an unbounded vertical parent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PdfViewer(source: PdfDocumentSource.file('/tmp/sample.pdf')),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}

const List<int> _transparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
