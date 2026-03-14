import 'pdf_rect.dart';

enum PdfFormFieldType { text, checkbox, radio, comboBox, listBox, signature }

abstract base class PdfFormField {
  const PdfFormField({
    required this.id,
    required this.name,
    required this.pageIndex,
    required this.bounds,
    this.isReadOnly = false,
  });

  final String id;
  final String name;
  final int pageIndex;
  final PdfRect bounds;
  final bool isReadOnly;

  PdfFormFieldType get type;
}
