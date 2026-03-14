import 'pdf_overlay_item.dart';
import 'pdf_rect.dart';

/// A simple checkmark overlay placed on top of a PDF page.
final class PdfCheckmarkOverlay extends PdfOverlayItem {
  /// Creates a checkmark overlay.
  PdfCheckmarkOverlay({
    required super.id,
    required super.pageIndex,
    required super.bounds,
    this.color = 0xFF059669,
    super.rotation = 0,
  });

  /// ARGB color of the checkmark.
  final int color;

  @override
  PdfOverlayType get type => PdfOverlayType.checkmark;

  /// Returns a copy of this overlay with updated values.
  PdfCheckmarkOverlay copyWith({
    String? id,
    int? pageIndex,
    PdfRect? bounds,
    int? color,
    double? rotation,
  }) {
    return PdfCheckmarkOverlay(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      color: color ?? this.color,
      rotation: rotation ?? this.rotation,
    );
  }
}
