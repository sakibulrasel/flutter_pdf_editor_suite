import 'dart:typed_data';

enum PdfDocumentSourceType { file, bytes }

final class PdfDocumentSource {
  const PdfDocumentSource.file(this.path)
    : bytes = null,
      type = PdfDocumentSourceType.file;

  const PdfDocumentSource.bytes(this.bytes)
    : path = null,
      type = PdfDocumentSourceType.bytes;

  final PdfDocumentSourceType type;
  final String? path;
  final Uint8List? bytes;
}
