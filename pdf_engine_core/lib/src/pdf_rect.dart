final class PdfRect {
  const PdfRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  PdfRect copyWith({double? left, double? top, double? width, double? height}) {
    return PdfRect(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  PdfRect translate(double deltaX, double deltaY) {
    return PdfRect(
      left: left + deltaX,
      top: top + deltaY,
      width: width,
      height: height,
    );
  }

  PdfRect resize(double nextWidth, double nextHeight) {
    return PdfRect(left: left, top: top, width: nextWidth, height: nextHeight);
  }

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
