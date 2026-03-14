import 'pdf_overlay_item.dart';
import 'pdf_rect.dart';

final class PdfTextOverlay extends PdfOverlayItem {
  PdfTextOverlay({
    required super.id,
    required super.pageIndex,
    required super.bounds,
    this.text = 'Text',
    this.fontSize = 16,
    this.color = 0xFF111827,
    super.rotation = 0,
  });

  final String text;
  final double fontSize;
  final int color;

  @override
  PdfOverlayType get type => PdfOverlayType.text;

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
