import 'pdf_overlay_item.dart';
import 'pdf_rect.dart';

final class PdfRectangleOverlay extends PdfOverlayItem {
  PdfRectangleOverlay({
    required super.id,
    required super.pageIndex,
    required super.bounds,
    this.color = 0xFF2563EB,
    super.rotation = 0,
  });

  final int color;

  @override
  PdfOverlayType get type => PdfOverlayType.rectangle;

  PdfRectangleOverlay copyWith({
    String? id,
    int? pageIndex,
    PdfRect? bounds,
    int? color,
    double? rotation,
  }) {
    return PdfRectangleOverlay(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      color: color ?? this.color,
      rotation: rotation ?? this.rotation,
    );
  }
}
