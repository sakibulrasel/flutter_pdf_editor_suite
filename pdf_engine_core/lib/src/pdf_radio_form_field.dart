import 'pdf_form_field.dart';
import 'pdf_rect.dart';

final class PdfRadioFormField extends PdfFormField {
  const PdfRadioFormField({
    required super.id,
    required super.name,
    required super.pageIndex,
    required super.bounds,
    required this.groupName,
    required this.optionValue,
    this.isSelected = false,
    super.isReadOnly = false,
  });

  final String groupName;
  final String optionValue;
  final bool isSelected;

  @override
  PdfFormFieldType get type => PdfFormFieldType.radio;

  PdfRadioFormField copyWith({
    String? id,
    String? name,
    int? pageIndex,
    PdfRect? bounds,
    String? groupName,
    String? optionValue,
    bool? isSelected,
    bool? isReadOnly,
  }) {
    return PdfRadioFormField(
      id: id ?? this.id,
      name: name ?? this.name,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      groupName: groupName ?? this.groupName,
      optionValue: optionValue ?? this.optionValue,
      isSelected: isSelected ?? this.isSelected,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }
}
