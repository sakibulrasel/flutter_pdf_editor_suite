import 'pdf_rect.dart';

/// Supported overlay categories used by the authoring/editor layers.
enum PdfOverlayType { text, checkmark, signature, rectangle, image }

/// Base class for movable, resizable overlay items drawn over a PDF page.
abstract base class PdfOverlayItem {
  /// Creates an overlay item.
  const PdfOverlayItem({
    required this.id,
    required this.pageIndex,
    required this.bounds,
    required this.rotation,
  });

  /// Stable identifier for this overlay item.
  final String id;

  /// Zero-based page index that contains the overlay.
  final int pageIndex;

  /// Overlay bounds in PDF page coordinates.
  final PdfRect bounds;

  /// Clockwise rotation in degrees.
  final double rotation;

  /// Runtime overlay category.
  PdfOverlayType get type;
}
