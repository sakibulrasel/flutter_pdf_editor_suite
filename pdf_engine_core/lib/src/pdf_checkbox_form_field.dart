import 'pdf_checkbox_mark_style.dart';
import 'pdf_form_field.dart';
import 'pdf_rect.dart';

final class PdfCheckboxFormField extends PdfFormField {
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

  final bool isChecked;
  final String onValue;
  final PdfCheckboxMarkStyle markStyle;

  @override
  PdfFormFieldType get type => PdfFormFieldType.checkbox;

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
