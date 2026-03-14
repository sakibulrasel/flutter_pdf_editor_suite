import 'pdf_page_info.dart';
import 'pdf_point.dart';

final class PdfPageViewport {
  const PdfPageViewport({
    required this.pageInfo,
    required this.renderedWidth,
    required this.renderedHeight,
  });

  final PdfPageInfo pageInfo;
  final double renderedWidth;
  final double renderedHeight;

  PdfPoint screenToPdf(PdfPoint point) {
    final normalizedX = (point.x / renderedWidth).clamp(0.0, 1.0);
    final normalizedY = (point.y / renderedHeight).clamp(0.0, 1.0);
    return PdfPoint(
      x: normalizedX * pageInfo.width,
      y: normalizedY * pageInfo.height,
    );
  }

  PdfPoint pdfToScreen(PdfPoint point) {
    final normalizedX = (point.x / pageInfo.width).clamp(0.0, 1.0);
    final normalizedY = (point.y / pageInfo.height).clamp(0.0, 1.0);
    return PdfPoint(
      x: normalizedX * renderedWidth,
      y: normalizedY * renderedHeight,
    );
  }
}
