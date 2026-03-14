import 'package:flutter/foundation.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

/// Mutable controller for parsed PDF form field state.
class PdfFormEditorController extends ChangeNotifier {
  final List<PdfFormField> _fields = <PdfFormField>[];
  String? _selectedFieldId;

  /// Current form fields.
  List<PdfFormField> get fields => List<PdfFormField>.unmodifiable(_fields);

  /// Selected field identifier, if any.
  String? get selectedFieldId => _selectedFieldId;

  /// Selected field model, if any.
  PdfFormField? get selectedField {
    if (_selectedFieldId == null) {
      return null;
    }
    for (final field in _fields) {
      if (field.id == _selectedFieldId) {
        return field;
      }
    }
    return null;
  }

  /// Replaces the controller field list.
  void setFields(List<PdfFormField> fields) {
    _fields
      ..clear()
      ..addAll(fields);
    if (_selectedFieldId != null &&
        _fields.every((field) => field.id != _selectedFieldId)) {
      _selectedFieldId = null;
    }
    notifyListeners();
  }

  /// Selects a field by id, or clears selection with `null`.
  void selectField(String? fieldId) {
    if (_selectedFieldId == fieldId) {
      return;
    }
    _selectedFieldId = fieldId;
    notifyListeners();
  }

  /// Updates a text field value.
  void updateTextField(String fieldId, String value) {
    final index = _fields.indexWhere((field) => field.id == fieldId);
    if (index < 0) {
      return;
    }
    final field = _fields[index];
    if (field is! PdfTextFormField || field.isReadOnly) {
      return;
    }
    _fields[index] = field.copyWith(value: value);
    notifyListeners();
  }

  /// Toggles a checkbox field.
  void toggleCheckbox(String fieldId) {
    final index = _fields.indexWhere((field) => field.id == fieldId);
    if (index < 0) {
      return;
    }
    final field = _fields[index];
    if (field is! PdfCheckboxFormField || field.isReadOnly) {
      return;
    }
    _fields[index] = field.copyWith(isChecked: !field.isChecked);
    notifyListeners();
  }

  /// Selects a radio option and clears other options in the same group.
  void selectRadio(String fieldId) {
    final index = _fields.indexWhere((field) => field.id == fieldId);
    if (index < 0) {
      return;
    }
    final field = _fields[index];
    if (field is! PdfRadioFormField || field.isReadOnly) {
      return;
    }
    for (var i = 0; i < _fields.length; i++) {
      final current = _fields[i];
      if (current is PdfRadioFormField &&
          current.groupName == field.groupName) {
        _fields[i] = current.copyWith(isSelected: current.id == fieldId);
      }
    }
    notifyListeners();
  }

  /// Sets the selected value of a combo box field.
  void selectComboBoxValue(String fieldId, String value) {
    final index = _fields.indexWhere((field) => field.id == fieldId);
    if (index < 0) {
      return;
    }
    final field = _fields[index];
    if (field is! PdfComboBoxFormField || field.isReadOnly) {
      return;
    }
    _fields[index] = field.copyWith(selectedValue: value);
    notifyListeners();
  }

  /// Updates the selected values of a list box field.
  void selectListBoxValues(String fieldId, List<String> values) {
    final index = _fields.indexWhere((field) => field.id == fieldId);
    if (index < 0) {
      return;
    }
    final field = _fields[index];
    if (field is! PdfListBoxFormField || field.isReadOnly) {
      return;
    }
    final nextValues = field.isMultiSelect
        ? values.toSet().toList(growable: false)
        : (values.isEmpty ? const <String>[] : <String>[values.first]);
    _fields[index] = field.copyWith(selectedValues: nextValues);
    notifyListeners();
  }

  /// Stores a drawn signature image in a signature field.
  void updateSignatureField(String fieldId, Uint8List pngBytes) {
    final index = _fields.indexWhere((field) => field.id == fieldId);
    if (index < 0) {
      return;
    }
    final field = _fields[index];
    if (field is! PdfSignatureFormField || field.isReadOnly) {
      return;
    }
    _fields[index] = field.copyWith(pngBytes: pngBytes);
    notifyListeners();
  }

  /// Clears the stored signature image from a signature field.
  void clearSignatureField(String fieldId) {
    final index = _fields.indexWhere((field) => field.id == fieldId);
    if (index < 0) {
      return;
    }
    final field = _fields[index];
    if (field is! PdfSignatureFormField || field.isReadOnly) {
      return;
    }
    _fields[index] = field.copyWith(clearSignature: true);
    notifyListeners();
  }
}
