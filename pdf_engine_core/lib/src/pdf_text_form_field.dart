import 'pdf_form_field.dart';
import 'pdf_rect.dart';

final class PdfTextFormField extends PdfFormField {
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

  final String value;
  final String defaultValue;
  final bool isMultiline;

  @override
  PdfFormFieldType get type => PdfFormFieldType.text;

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
