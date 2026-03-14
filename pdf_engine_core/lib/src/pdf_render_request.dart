/// Parameters used when requesting a rendered PDF page bitmap.
final class PdfRenderRequest {
  /// Creates a page render request.
  const PdfRenderRequest({
    required this.documentId,
    required this.pageIndex,
    this.scale = 1.0,
    this.backgroundColor = 0xFFFFFFFF,
  }) : assert(scale > 0, 'scale must be greater than zero');

  /// Renderer-specific document handle.
  final int documentId;

  /// Zero-based page index to render.
  final int pageIndex;

  /// Render scale multiplier.
  final double scale;

  /// Background color for transparent PDF content, encoded as ARGB.
  final int backgroundColor;
}
