import 'dart:typed_data';

import 'pdf_overlay_item.dart';
import 'pdf_rect.dart';

/// Signature image overlay placed on a PDF page.
final class PdfSignatureOverlay extends PdfOverlayItem {
  /// Creates a signature overlay.
  PdfSignatureOverlay({
    required super.id,
    required super.pageIndex,
    required super.bounds,
    required this.pngBytes,
    super.rotation = 0,
  });

  /// PNG bytes representing the signature image.
  final Uint8List pngBytes;

  @override
  PdfOverlayType get type => PdfOverlayType.signature;

  /// Returns a copy of this overlay with updated values.
  PdfSignatureOverlay copyWith({
    String? id,
    int? pageIndex,
    PdfRect? bounds,
    Uint8List? pngBytes,
    double? rotation,
  }) {
    return PdfSignatureOverlay(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      pngBytes: pngBytes ?? this.pngBytes,
      rotation: rotation ?? this.rotation,
    );
  }
}
