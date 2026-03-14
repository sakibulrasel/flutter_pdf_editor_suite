import 'dart:typed_data';

/// How a PDF document is provided to the renderer.
enum PdfDocumentSourceType { file, bytes }

/// A PDF document source backed by a file path or in-memory bytes.
final class PdfDocumentSource {
  /// Creates a document source from a file path.
  const PdfDocumentSource.file(this.path)
    : bytes = null,
      type = PdfDocumentSourceType.file;

  /// Creates a document source from raw PDF bytes.
  const PdfDocumentSource.bytes(this.bytes)
    : path = null,
      type = PdfDocumentSourceType.bytes;

  /// Source representation type.
  final PdfDocumentSourceType type;

  /// File path when [type] is [PdfDocumentSourceType.file].
  final String? path;

  /// Raw bytes when [type] is [PdfDocumentSourceType.bytes].
  final Uint8List? bytes;
}
