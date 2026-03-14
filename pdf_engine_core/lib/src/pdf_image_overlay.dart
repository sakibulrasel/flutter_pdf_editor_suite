import 'dart:typed_data';

import 'pdf_overlay_item.dart';
import 'pdf_rect.dart';

/// Raster image overlay placed on top of a PDF page.
final class PdfImageOverlay extends PdfOverlayItem {
  /// Creates an image overlay from already-loaded image bytes.
  PdfImageOverlay({
    required super.id,
    required super.pageIndex,
    required super.bounds,
    required this.imageBytes,
    super.rotation = 0,
  });

  /// Source PNG or JPEG bytes for the placed image.
  final Uint8List imageBytes;

  @override
  PdfOverlayType get type => PdfOverlayType.image;

  /// Returns a copy of this overlay with updated values.
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
