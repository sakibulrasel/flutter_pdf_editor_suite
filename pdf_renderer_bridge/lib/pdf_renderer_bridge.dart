import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'pdf_renderer_bridge_platform_interface.dart';

/// Public bridge API for opening PDFs and rendering pages through native code.
class PdfRendererBridge {
  /// Creates a renderer bridge backed by the current platform implementation.
  PdfRendererBridge();

  /// Opens a PDF [source] and returns document metadata.
  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source) {
    return PdfRendererBridgePlatform.instance.openDocument(source);
  }

  /// Returns metadata for a single page in an opened document.
  Future<PdfPageInfo> getPageInfo({
    required int documentId,
    required int pageIndex,
  }) {
    return PdfRendererBridgePlatform.instance.getPageInfo(
      documentId: documentId,
      pageIndex: pageIndex,
    );
  }

  /// Renders a page bitmap for the given [request].
  Future<PdfRenderedPage> renderPage(PdfRenderRequest request) {
    return PdfRendererBridgePlatform.instance.renderPage(request);
  }

  /// Closes a previously opened document handle.
  Future<void> closeDocument(int documentId) {
    return PdfRendererBridgePlatform.instance.closeDocument(documentId);
  }
}
