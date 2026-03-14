import 'pdf_choice_option.dart';
import 'pdf_form_field.dart';
import 'pdf_rect.dart';

final class PdfComboBoxFormField extends PdfFormField {
  const PdfComboBoxFormField({
    required super.id,
    required super.name,
    required super.pageIndex,
    required super.bounds,
    required this.options,
    this.selectedValue = '',
    super.isReadOnly = false,
  });

  final List<PdfChoiceOption> options;
  final String selectedValue;

  String get selectedLabel {
    for (final option in options) {
      if (option.value == selectedValue) {
        return option.label;
      }
    }
    return selectedValue;
  }

  @override
  PdfFormFieldType get type => PdfFormFieldType.comboBox;

  PdfComboBoxFormField copyWith({
    String? id,
    String? name,
    int? pageIndex,
    PdfRect? bounds,
    List<PdfChoiceOption>? options,
    String? selectedValue,
    bool? isReadOnly,
  }) {
    return PdfComboBoxFormField(
      id: id ?? this.id,
      name: name ?? this.name,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      options: options ?? this.options,
      selectedValue: selectedValue ?? this.selectedValue,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }
}
