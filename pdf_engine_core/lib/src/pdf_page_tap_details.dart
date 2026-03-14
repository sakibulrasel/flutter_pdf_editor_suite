import 'pdf_page_info.dart';
import 'pdf_page_viewport.dart';
import 'pdf_point.dart';

final class PdfPageTapDetails {
  const PdfPageTapDetails({
    required this.pageInfo,
    required this.viewport,
    required this.localPosition,
    required this.pdfPosition,
  });

  final PdfPageInfo pageInfo;
  final PdfPageViewport viewport;
  final PdfPoint localPosition;
  final PdfPoint pdfPosition;
}
