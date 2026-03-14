import 'pdf_choice_option.dart';
import 'pdf_form_field.dart';
import 'pdf_rect.dart';

/// Choice field rendered as a visible list box.
final class PdfListBoxFormField extends PdfFormField {
  /// Creates a list box field model.
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

  /// Available choice entries for the field.
  final List<PdfChoiceOption> options;

  /// Selected option values.
  final List<String> selectedValues;

  /// Whether multiple selections are allowed.
  final bool isMultiSelect;

  /// User-facing labels for the selected values.
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

  /// Returns a copy of this field with updated values.
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
