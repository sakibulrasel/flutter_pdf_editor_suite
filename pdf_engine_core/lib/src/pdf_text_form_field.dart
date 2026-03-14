import 'pdf_form_field.dart';
import 'pdf_rect.dart';

/// Text-entry AcroForm field.
final class PdfTextFormField extends PdfFormField {
  /// Creates a text field model.
  const PdfTextFormField({
    required super.id,
    required super.name,
    required super.pageIndex,
    required super.bounds,
    this.value = '',
    this.defaultValue = '',
    this.isMultiline = false,
    super.isReadOnly = false,
  });

  /// Current text value.
  final String value;

  /// Default text value from the original PDF, if available.
  final String defaultValue;

  /// Whether the field accepts multiple lines.
  final bool isMultiline;

  @override
  PdfFormFieldType get type => PdfFormFieldType.text;

  /// Returns a copy of this field with updated values.
  PdfTextFormField copyWith({
    String? id,
    String? name,
    int? pageIndex,
    PdfRect? bounds,
    String? value,
    String? defaultValue,
    bool? isMultiline,
    bool? isReadOnly,
  }) {
    return PdfTextFormField(
      id: id ?? this.id,
      name: name ?? this.name,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      value: value ?? this.value,
      defaultValue: defaultValue ?? this.defaultValue,
      isMultiline: isMultiline ?? this.isMultiline,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }
}
