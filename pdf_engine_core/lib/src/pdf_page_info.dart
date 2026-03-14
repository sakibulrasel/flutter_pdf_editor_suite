final class PdfPageInfo {
  const PdfPageInfo({
    required this.documentId,
    required this.pageIndex,
    required this.width,
    required this.height,
  });

  final int documentId;
  final int pageIndex;
  final double width;
  final double height;
}
