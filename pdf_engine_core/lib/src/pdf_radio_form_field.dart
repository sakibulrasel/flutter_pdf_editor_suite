import 'pdf_form_field.dart';
import 'pdf_rect.dart';

/// One widget option inside a radio-button group.
final class PdfRadioFormField extends PdfFormField {
  /// Creates a radio-button field model.
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

  /// Shared group name that links sibling radio options.
  final String groupName;

  /// Export value associated with this option.
  final String optionValue;

  /// Whether this radio option is currently selected.
  final bool isSelected;

  @override
  PdfFormFieldType get type => PdfFormFieldType.radio;

  /// Returns a copy of this field with updated values.
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
