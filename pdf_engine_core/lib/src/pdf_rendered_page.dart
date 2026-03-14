import 'dart:typed_data';

final class PdfRenderedPage {
  const PdfRenderedPage({
    required this.documentId,
    required this.pageIndex,
    required this.width,
    required this.height,
    required this.pngBytes,
  });

  final int documentId;
  final int pageIndex;
  final int width;
  final int height;
  final Uint8List pngBytes;
}
