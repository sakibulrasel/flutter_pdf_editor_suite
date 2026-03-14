import 'dart:typed_data';

import 'pdf_overlay_item.dart';
import 'pdf_rect.dart';

final class PdfImageOverlay extends PdfOverlayItem {
  PdfImageOverlay({
    required super.id,
    required super.pageIndex,
    required super.bounds,
    required this.imageBytes,
    super.rotation = 0,
  });

  final Uint8List imageBytes;

  @override
  PdfOverlayType get type => PdfOverlayType.image;

  PdfImageOverlay copyWith({
    String? id,
    int? pageIndex,
    PdfRect? bounds,
    Uint8List? imageBytes,
    double? rotation,
  }) {
    return PdfImageOverlay(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      imageBytes: imageBytes ?? this.imageBytes,
      rotation: rotation ?? this.rotation,
    );
  }
}
