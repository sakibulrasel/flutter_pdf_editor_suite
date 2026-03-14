/// Two-dimensional point used in PDF and screen coordinate conversions.
final class PdfPoint {
  /// Creates a point.
  const PdfPoint({required this.x, required this.y});

  /// Horizontal coordinate.
  final double x;

  /// Vertical coordinate.
  final double y;
}
