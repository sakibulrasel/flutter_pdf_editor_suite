/// Metadata returned when a PDF document is opened by the renderer.
final class PdfDocumentInfo {
  /// Creates document metadata.
  const PdfDocumentInfo({required this.documentId, required this.pageCount});

  /// Renderer-specific document handle.
  final int documentId;

  /// Number of pages in the document.
  final int pageCount;
}
