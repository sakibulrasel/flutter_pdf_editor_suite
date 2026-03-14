import 'pdf_choice_option.dart';
import 'pdf_form_field.dart';
import 'pdf_rect.dart';

final class PdfListBoxFormField extends PdfFormField {
  const PdfListBoxFormField({
    required super.id,
    required super.name,
    required super.pageIndex,
    required super.bounds,
    required this.options,
    this.selectedValues = const <String>[],
    this.isMultiSelect = false,
    super.isReadOnly = false,
  });

  final List<PdfChoiceOption> options;
  final List<String> selectedValues;
  final bool isMultiSelect;

  List<String> get selectedLabels {
    if (selectedValues.isEmpty) {
      return const <String>[];
    }
    final labels = <String>[];
    for (final selectedValue in selectedValues) {
      final option = options.where((item) => item.value == selectedValue);
      if (option.isNotEmpty) {
        labels.add(option.first.label);
      } else {
        labels.add(selectedValue);
      }
    }
    return labels;
  }

  @override
  PdfFormFieldType get type => PdfFormFieldType.listBox;

  PdfListBoxFormField copyWith({
    String? id,
    String? name,
    int? pageIndex,
    PdfRect? bounds,
    List<PdfChoiceOption>? options,
    List<String>? selectedValues,
    bool? isMultiSelect,
    bool? isReadOnly,
  }) {
    return PdfListBoxFormField(
      id: id ?? this.id,
      name: name ?? this.name,
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      options: options ?? this.options,
      selectedValues: selectedValues ?? this.selectedValues,
      isMultiSelect: isMultiSelect ?? this.isMultiSelect,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }
}
