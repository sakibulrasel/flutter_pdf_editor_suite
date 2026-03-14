import 'dart:typed_data';

/// Rendered bitmap result for a PDF page.
final class PdfRenderedPage {
  /// Creates a rendered page payload.
  const PdfRenderedPage({
    required this.documentId,
    required this.pageIndex,
    required this.width,
    required this.height,
    required this.pngBytes,
  });

  /// Renderer-specific document handle.
  final int documentId;

  /// Zero-based page index.
  final int pageIndex;

  /// Output bitmap width in pixels.
  final int width;

  /// Output bitmap height in pixels.
  final int height;

  /// PNG-encoded page image bytes.
  final Uint8List pngBytes;
}
