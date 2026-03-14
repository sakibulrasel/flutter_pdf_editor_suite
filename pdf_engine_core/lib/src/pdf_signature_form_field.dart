import 'dart:typed_data';

import 'pdf_form_field.dart';
import 'pdf_rect.dart';

final class PdfSignatureFormField extends PdfFormField {
  const PdfSignatureFormField({
    required super.id,
    required super.name,
    required super.pageIndex,
    required super.bounds,
    this.pngBytes,
    super.isReadOnly = false,
  });

  final Uint8List? pngBytes;

  bool get hasSignature => pngBytes != null && pngBytes!.isNotEmpty;

  @override
  PdfFormFieldType get type => PdfFormFieldType.signature;

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
