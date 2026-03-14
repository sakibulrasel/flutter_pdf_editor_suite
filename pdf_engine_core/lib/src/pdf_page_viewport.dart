import 'pdf_page_info.dart';
import 'pdf_point.dart';

/// Converts between rendered screen coordinates and PDF page coordinates.
final class PdfPageViewport {
  /// Creates a viewport mapping for a rendered PDF page.
  const PdfPageViewport({
    required this.pageInfo,
    required this.renderedWidth,
    required this.renderedHeight,
  });

  /// PDF page metadata.
  final PdfPageInfo pageInfo;

  /// Rendered page width in logical pixels.
  final double renderedWidth;

  /// Rendered page height in logical pixels.
  final double renderedHeight;

  /// Converts a rendered-screen point into PDF page coordinates.
  PdfPoint screenToPdf(PdfPoint point) {
    final normalizedX = (point.x / renderedWidth).clamp(0.0, 1.0);
    final normalizedY = (point.y / renderedHeight).clamp(0.0, 1.0);
    return PdfPoint(
      x: normalizedX * pageInfo.width,
      y: normalizedY * pageInfo.height,
    );
  }

  /// Converts a PDF page point into rendered-screen coordinates.
  PdfPoint pdfToScreen(PdfPoint point) {
    final normalizedX = (point.x / pageInfo.width).clamp(0.0, 1.0);
    final normalizedY = (point.y / pageInfo.height).clamp(0.0, 1.0);
    return PdfPoint(
      x: normalizedX * renderedWidth,
      y: normalizedY * renderedHeight,
    );
  }
}
