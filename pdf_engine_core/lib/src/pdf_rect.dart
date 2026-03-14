/// Rectangle in PDF page coordinates.
final class PdfRect {
  /// Creates a rectangle from left/top origin and size.
  const PdfRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Left edge coordinate.
  final double left;

  /// Top edge coordinate.
  final double top;

  /// Rectangle width.
  final double width;

  /// Rectangle height.
  final double height;

  /// Right edge coordinate.
  double get right => left + width;

  /// Bottom edge coordinate.
  double get bottom => top + height;

  /// Returns a copy of this rectangle with updated values.
  PdfRect copyWith({double? left, double? top, double? width, double? height}) {
    return PdfRect(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  /// Returns a translated rectangle.
  PdfRect translate(double deltaX, double deltaY) {
    return PdfRect(
      left: left + deltaX,
      top: top + deltaY,
      width: width,
      height: height,
    );
  }

  /// Returns a resized rectangle keeping the same origin.
  PdfRect resize(double nextWidth, double nextHeight) {
    return PdfRect(left: left, top: top, width: nextWidth, height: nextHeight);
  }

  /// Clamps the rectangle origin so it stays within the given bounds.
  PdfRect clampWithin({required double maxWidth, required double maxHeight}) {
    final clampedLeft = left.clamp(
      0.0,
      (maxWidth - width).clamp(0.0, maxWidth),
    );
    final clampedTop = top.clamp(
      0.0,
      (maxHeight - height).clamp(0.0, maxHeight),
    );
    return PdfRect(
      left: clampedLeft,
      top: clampedTop,
      width: width,
      height: height,
    );
  }

  /// Clamps the rectangle size to the provided minimum and maximum bounds.
  PdfRect clampSize({
    required double minWidth,
    required double minHeight,
    required double maxWidth,
    required double maxHeight,
  }) {
    final clampedWidth = width.clamp(minWidth, maxWidth - left);
    final clampedHeight = height.clamp(minHeight, maxHeight - top);
    return PdfRect(
      left: left,
      top: top,
      width: clampedWidth,
      height: clampedHeight,
    );
  }
}
