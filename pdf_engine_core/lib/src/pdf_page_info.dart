/// Static information about a page inside an opened PDF document.
final class PdfPageInfo {
  /// Creates page metadata.
  const PdfPageInfo({
    required this.documentId,
    required this.pageIndex,
    required this.width,
    required this.height,
  });

  /// Renderer-specific document handle that owns the page.
  final int documentId;

  /// Zero-based page index.
  final int pageIndex;

  /// Page width in PDF points.
  final double width;

  /// Page height in PDF points.
  final double height;
}
