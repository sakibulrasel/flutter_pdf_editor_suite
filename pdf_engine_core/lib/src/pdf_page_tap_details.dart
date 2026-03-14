import 'pdf_page_info.dart';
import 'pdf_page_viewport.dart';
import 'pdf_point.dart';

/// Details for a tap hit on a rendered PDF page.
final class PdfPageTapDetails {
  /// Creates page tap details.
  const PdfPageTapDetails({
    required this.pageInfo,
    required this.viewport,
    required this.localPosition,
    required this.pdfPosition,
  });

  /// Metadata for the tapped page.
  final PdfPageInfo pageInfo;

  /// Viewport mapping used for the tapped page.
  final PdfPageViewport viewport;

  /// Tap position in rendered widget coordinates.
  final PdfPoint localPosition;

  /// Tap position converted into PDF page coordinates.
  final PdfPoint pdfPosition;
}
