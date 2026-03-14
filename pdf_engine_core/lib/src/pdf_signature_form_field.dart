import 'dart:typed_data';

import 'pdf_form_field.dart';
import 'pdf_rect.dart';

/// Signature widget field that stores a drawn signature image.
final class PdfSignatureFormField extends PdfFormField {
  /// Creates a signature field model.
  const PdfSignatureFormField({
    required super.id,
    required super.name,
    required super.pageIndex,
    required super.bounds,
    this.pngBytes,
    super.isReadOnly = false,
  });

  /// PNG bytes representing the captured signature image, if any.
  final Uint8List? pngBytes;

  /// Whether a non-empty signature image is present.
  bool get hasSignature => pngBytes != null && pngBytes!.isNotEmpty;

  @override
  PdfFormFieldType get type => PdfFormFieldType.signature;

  /// Returns a copy of this field with updated values.
  PdfSignatureFormField copyWith({
    String? id,
    String? name,
    int? pageIndex,
    PdfRect? bounds,
    Uint8List? pngBytes,
    bool clearSignature = false,
    bool? isReadOnly,
  }) {
    return PdfSignatureFormField(
      id: id ?? this.id,
      name: name ?? this.name,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      pngBytes: clearSignature ? null : (pngBytes ?? this.pngBytes),
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }
}
