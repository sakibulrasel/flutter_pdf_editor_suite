import 'pdf_overlay_item.dart';
import 'pdf_rect.dart';

/// Rectangle shape overlay placed on a PDF page.
final class PdfRectangleOverlay extends PdfOverlayItem {
  /// Creates a rectangle overlay.
  PdfRectangleOverlay({
    required super.id,
    required super.pageIndex,
    required super.bounds,
    this.color = 0xFF2563EB,
    super.rotation = 0,
  });

  /// ARGB fill or stroke color used for the rectangle.
  final int color;

  @override
  PdfOverlayType get type => PdfOverlayType.rectangle;

  /// Returns a copy of this overlay with updated values.
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
