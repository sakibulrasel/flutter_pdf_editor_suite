import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'pdf_renderer_bridge_platform_interface.dart';

class PdfRendererBridge {
  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source) {
    return PdfRendererBridgePlatform.instance.openDocument(source);
  }

  Future<PdfPageInfo> getPageInfo({
    required int documentId,
    required int pageIndex,
  }) {
    return PdfRendererBridgePlatform.instance.getPageInfo(
      documentId: documentId,
      pageIndex: pageIndex,
    );
  }

  Future<PdfRenderedPage> renderPage(PdfRenderRequest request) {
    return PdfRendererBridgePlatform.instance.renderPage(request);
  }

  Future<void> closeDocument(int documentId) {
    return PdfRendererBridgePlatform.instance.closeDocument(documentId);
  }
}
