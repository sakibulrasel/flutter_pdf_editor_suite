import 'pdf_checkbox_mark_style.dart';
import 'pdf_form_field.dart';
import 'pdf_rect.dart';

/// Boolean AcroForm field rendered as a checkbox widget.
final class PdfCheckboxFormField extends PdfFormField {
  /// Creates a checkbox field model.
  const PdfCheckboxFormField({
    required super.id,
    required super.name,
    required super.pageIndex,
    required super.bounds,
    this.isChecked = false,
    this.onValue = 'Yes',
    this.markStyle = PdfCheckboxMarkStyle.check,
    super.isReadOnly = false,
  });

  /// Whether the checkbox is currently selected.
  final bool isChecked;

  /// Export value written for the checked state in classic AcroForm PDFs.
  final String onValue;

  /// Visual mark style used when the checkbox is checked.
  final PdfCheckboxMarkStyle markStyle;

  @override
  PdfFormFieldType get type => PdfFormFieldType.checkbox;

  /// Returns a copy of this field with updated values.
  PdfCheckboxFormField copyWith({
    String? id,
    String? name,
    int? pageIndex,
    PdfRect? bounds,
    bool? isChecked,
    String? onValue,
    PdfCheckboxMarkStyle? markStyle,
    bool? isReadOnly,
  }) {
    return PdfCheckboxFormField(
      id: id ?? this.id,
      name: name ?? this.name,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      isChecked: isChecked ?? this.isChecked,
      onValue: onValue ?? this.onValue,
      markStyle: markStyle ?? this.markStyle,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }
}
