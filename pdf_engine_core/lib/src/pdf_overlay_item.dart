import 'pdf_rect.dart';

enum PdfOverlayType { text, checkmark, signature, rectangle, image }

abstract base class PdfOverlayItem {
  const PdfOverlayItem({
    required this.id,
    required this.pageIndex,
    required this.bounds,
    required this.rotation,
  });

  final String id;
  final int pageIndex;
  final PdfRect bounds;
  final double rotation;
  PdfOverlayType get type;
}
