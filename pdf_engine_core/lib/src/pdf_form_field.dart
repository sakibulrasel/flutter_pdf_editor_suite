import 'pdf_rect.dart';

/// Supported AcroForm field categories handled by the package.
enum PdfFormFieldType { text, checkbox, radio, comboBox, listBox, signature }

/// Base class for parsed and editable PDF form fields.
abstract base class PdfFormField {
  /// Creates a form field model.
  const PdfFormField({
    required this.id,
    required this.name,
    required this.pageIndex,
    required this.bounds,
    this.isReadOnly = false,
  });

  /// Stable identifier for the field within editor/controller state.
  final String id;

  /// Field name from the PDF form dictionary.
  final String name;

  /// Zero-based page index that contains the field widget.
  final int pageIndex;

  /// Field bounds in PDF page coordinates.
  final PdfRect bounds;

  /// Whether the field should be treated as read-only by the editor.
  final bool isReadOnly;

  /// Runtime field category.
  PdfFormFieldType get type;
}
