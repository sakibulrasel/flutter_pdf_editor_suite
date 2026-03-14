import 'pdf_overlay_item.dart';
import 'pdf_rect.dart';

/// Free-positioned text overlay placed on a PDF page.
final class PdfTextOverlay extends PdfOverlayItem {
  /// Creates a text overlay.
  PdfTextOverlay({
    required super.id,
    required super.pageIndex,
    required super.bounds,
    this.text = 'Text',
    this.fontSize = 16,
    this.color = 0xFF111827,
    super.rotation = 0,
  });

  /// Text content drawn in the overlay.
  final String text;

  /// Font size used when rendering the text.
  final double fontSize;

  /// ARGB text color.
  final int color;

  @override
  PdfOverlayType get type => PdfOverlayType.text;

  /// Returns a copy of this overlay with updated values.
  PdfTextOverlay copyWith({
    String? id,
    int? pageIndex,
    PdfRect? bounds,
    String? text,
    double? fontSize,
    int? color,
    double? rotation,
  }) {
    return PdfTextOverlay(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      rotation: rotation ?? this.rotation,
    );
  }
}
