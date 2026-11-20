import 'dart:io';
import 'dart:typed_data';

import 'package:pdf_engine_core/cos.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

/// Error thrown when editable PDF write-back cannot be completed.
///
/// When the file uses a feature editable save does not support yet,
/// [cause] holds the typed reason, for example a
/// [PdfUnsupportedFeatureException]. Apps usually fall back to flattened
/// export when they catch this.
class PdfEditableExportException extends PdfException {
  /// Creates an editable export exception.
  const PdfEditableExportException(super.message, {super.cause});

  @override
  String toString() => 'PdfEditableExportException: $message';
}

/// Writes form values back into an existing AcroForm PDF.
///
/// Values are appended as an incremental update, so the original content,
/// earlier revisions and the fields themselves stay intact and editable.
/// Works with classic PDFs and with PDF 1.5+ files that use compressed object
/// streams and cross-reference streams.
final class PdfEditableExporter {
  /// Exports an editable PDF as bytes.
  Future<Uint8List> exportToBytes({
    required PdfDocumentSource source,
    required List<PdfFormField> formFields,
  }) async {
    final bytes = switch (source.type) {
      PdfDocumentSourceType.bytes => source.bytes!,
      PdfDocumentSourceType.file => await _readFile(source.path!),
    };
    final PdfCosDocument document;
    try {
      document = PdfCosDocument.open(bytes);
    } on PdfException catch (error) {
      throw PdfEditableExportException(error.message, cause: error);
    }
    return _EditablePdfWriter(document).applyFields(formFields);
  }

  /// Writes an editable PDF file to [outputPath].
  Future<File> exportToFile({
    required PdfDocumentSource source,
    required List<PdfFormField> formFields,
    required String outputPath,
  }) async {
    final bytes = await exportToBytes(source: source, formFields: formFields);
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes, flush: true);
  }
}

Future<Uint8List> _readFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw PdfFileNotFoundException(path);
  }
  return file.readAsBytes();
}

final class _EditablePdfWriter {
  _EditablePdfWriter(this._document);

  final PdfCosDocument _document;

  /// Working copies of the objects being changed, by object number.
  final Map<int, PdfDict> _edited = <int, PdfDict>{};

  Uint8List applyFields(List<PdfFormField> formFields) {
    if (formFields.isEmpty) {
      return _document.bytes;
    }

    var valuesChanged = false;
    for (final field in formFields) {
      final widget = field._objectNumber;
      switch (field) {
        case PdfTextFormField(:final value):
          _setFieldValue(widget, PdfString.fromText(value));
          valuesChanged = true;
        case PdfCheckboxFormField(:final isChecked, :final onValue):
          final state = PdfName(isChecked ? onValue : 'Off');
          _setFieldValue(widget, state);
          _dictFor(widget)['AS'] = state;
        case PdfRadioFormField(:final isSelected, :final optionValue):
          _dictFor(widget)['AS'] = PdfName(isSelected ? optionValue : 'Off');
          if (isSelected) {
            _setFieldValue(widget, PdfName(optionValue));
          }
        case PdfComboBoxFormField(:final selectedValue):
          _setFieldValue(widget, PdfString.fromText(selectedValue));
          valuesChanged = true;
        case PdfListBoxFormField(:final isMultiSelect, :final selectedValues):
          _setFieldValue(
            widget,
            isMultiSelect
                ? PdfArray(<PdfObject>[
                    for (final value in selectedValues)
                      PdfString.fromText(value),
                  ])
                : PdfString.fromText(
                    selectedValues.isEmpty ? '' : selectedValues.first,
                  ),
          );
          valuesChanged = true;
        case PdfSignatureFormField(:final hasSignature):
          if (hasSignature) {
            throw const PdfEditableExportException(
              'Editable export does not yet support signature image write-back.',
            );
          }
      }
    }

    if (valuesChanged) {
      // Appearance streams are not regenerated yet (Phase 10), so ask
      // viewers to rebuild them from the new values.
      _setNeedAppearances();
    }
    if (_edited.isEmpty) {
      return _document.bytes;
    }
    final update = PdfIncrementalUpdate(_document);
    for (final entry in _edited.entries) {
      update.set(entry.key, entry.value);
    }
    return update.build();
  }

  /// Returns the working copy of object [number], creating it on first use.
  PdfDict _dictFor(int number) {
    final existing = _edited[number];
    if (existing != null) {
      return existing;
    }
    final object = _document.getObject(number);
    if (object is! PdfDict) {
      throw PdfEditableExportException('Object $number not found.');
    }
    return _edited[number] = object.copy();
  }

  /// Sets `/V` on the field that owns [widgetNumber]: the widget itself when
  /// it has a `/T` name, otherwise the nearest named `/Parent`.
  void _setFieldValue(int widgetNumber, PdfObject value) {
    _dictFor(_fieldNumberFor(widgetNumber))['V'] = value;
  }

  int _fieldNumberFor(int widgetNumber) {
    var number = widgetNumber;
    for (var depth = 0; depth < 32; depth++) {
      final dict = _document.getObject(number);
      if (dict is! PdfDict || dict.containsKey('T')) {
        return number;
      }
      final parent = dict['Parent'];
      if (parent is! PdfRef) {
        return number;
      }
      number = parent.number;
    }
    return widgetNumber;
  }

  void _setNeedAppearances() {
    final rootRef = _document.trailer['Root'];
    if (rootRef is! PdfRef) {
      return;
    }
    final acroFormEntry = _document.catalog['AcroForm'];
    if (acroFormEntry is PdfRef) {
      _dictFor(acroFormEntry.number)['NeedAppearances'] = const PdfBool(true);
    } else if (acroFormEntry is PdfDict) {
      final catalog = _dictFor(rootRef.number);
      catalog['AcroForm'] = acroFormEntry.copy()
        ..['NeedAppearances'] = const PdfBool(true);
    }
  }
}

extension on PdfFormField {
  int get _objectNumber {
    final match = RegExp(r'^form_(\d+)$').firstMatch(id);
    if (match == null) {
      throw PdfEditableExportException('Unsupported field id format: $id');
    }
    return int.parse(match.group(1)!);
  }
}
