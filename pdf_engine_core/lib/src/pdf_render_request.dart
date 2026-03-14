final class PdfRenderRequest {
  const PdfRenderRequest({
    required this.documentId,
    required this.pageIndex,
    this.scale = 1.0,
    this.backgroundColor = 0xFFFFFFFF,
  }) : assert(scale > 0, 'scale must be greater than zero');

  final int documentId;
  final int pageIndex;
  final double scale;
  final int backgroundColor;
}
