import 'dart:io';
import 'dart:typed_data';

import 'package:pdf_engine_core/pdf_engine_core.dart';

class PdfEditableExportException implements Exception {
  const PdfEditableExportException(this.message);

  final String message;

  @override
  String toString() => 'PdfEditableExportException: $message';
}

final class PdfEditableExporter {
  Future<Uint8List> exportToBytes({
    required PdfDocumentSource source,
    required List<PdfFormField> formFields,
  }) async {
    final bytes = switch (source.type) {
      PdfDocumentSourceType.bytes => source.bytes!,
      PdfDocumentSourceType.file => await File(source.path!).readAsBytes(),
    };
    return _EditablePdfWriter(bytes).applyFields(formFields);
  }

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

final class _EditablePdfWriter {
  _EditablePdfWriter(Uint8List bytes)
    : _originalBytes = bytes,
      _index = _ObjectIndex.parse(String.fromCharCodes(bytes));

  final Uint8List _originalBytes;
  final _ObjectIndex _index;

  Uint8List applyFields(List<PdfFormField> formFields) {
    if (formFields.isEmpty) {
      return _originalBytes;
    }

    final updatedObjects = <int, _UpdatedObject>{};
    final radioGroups = <int, PdfRadioFormField>{};

    for (final field in formFields) {
      switch (field) {
        case PdfTextFormField textField:
          updatedObjects[textField._objectNumber] = _replaceObjectValue(
            objectNumber: textField._objectNumber,
            key: 'V',
            valueToken: _pdfString(textField.value),
          );
        case PdfCheckboxFormField checkboxField:
          final token = checkboxField.isChecked
              ? '/${checkboxField.onValue}'
              : '/Off';
          updatedObjects[checkboxField._objectNumber] = _replaceWidgetState(
            objectNumber: checkboxField._objectNumber,
            valueToken: token,
          );
        case PdfRadioFormField radioField:
          final widgetToken = radioField.isSelected
              ? '/${radioField.optionValue}'
              : '/Off';
          updatedObjects[radioField._objectNumber] = _replaceKey(
            objectNumber: radioField._objectNumber,
            key: 'AS',
            valueToken: widgetToken,
          );
          final parentRef = _index.parentRefFor(radioField._objectNumber);
          if (parentRef != null && radioField.isSelected) {
            radioGroups[parentRef] = radioField;
          }
        case PdfComboBoxFormField comboBoxField:
          updatedObjects[comboBoxField._objectNumber] = _replaceObjectValue(
            objectNumber: comboBoxField._objectNumber,
            key: 'V',
            valueToken: _pdfString(comboBoxField.selectedValue),
          );
        case PdfListBoxFormField listBoxField:
          final token = listBoxField.isMultiSelect
              ? _pdfStringArray(listBoxField.selectedValues)
              : (listBoxField.selectedValues.isEmpty
                    ? '()'
                    : _pdfString(listBoxField.selectedValues.first));
          updatedObjects[listBoxField._objectNumber] = _replaceObjectValue(
            objectNumber: listBoxField._objectNumber,
            key: 'V',
            valueToken: token,
          );
        case PdfSignatureFormField signatureField:
          if (signatureField.hasSignature) {
            throw const PdfEditableExportException(
              'Editable export does not yet support signature image write-back.',
            );
          }
      }
    }

    for (final entry in radioGroups.entries) {
      updatedObjects[entry.key] = _replaceObjectValue(
        objectNumber: entry.key,
        key: 'V',
        valueToken: '/${entry.value.optionValue}',
      );
    }

    if (updatedObjects.isEmpty) {
      return _originalBytes;
    }

    final lastStartXref = _index.lastStartXref;
    final buffer = StringBuffer()..write('\n');
    final offsets = <int, int>{};

    for (final objectNumber in updatedObjects.keys.toList()..sort()) {
      final updated = updatedObjects[objectNumber]!;
      offsets[objectNumber] = _originalBytes.length + buffer.length;
      buffer.write('$objectNumber ${updated.generation} obj\n');
      buffer.write(updated.body);
      if (!updated.body.endsWith('\n')) {
        buffer.write('\n');
      }
      buffer.write('endobj\n');
    }

    final xrefOffset = _originalBytes.length + buffer.length;
    buffer.write('xref\n');
    for (final range in _contiguousRanges(offsets.keys.toList()..sort())) {
      buffer.write('${range.start} ${range.length}\n');
      for (
        var objectNumber = range.start;
        objectNumber < range.start + range.length;
        objectNumber++
      ) {
        final offset = offsets[objectNumber]!;
        final generation = updatedObjects[objectNumber]!.generation;
        buffer.write(
          '${offset.toString().padLeft(10, '0')} ${generation.toString().padLeft(5, '0')} n \n',
        );
      }
    }
    buffer.write('trailer\n');
    buffer.write(
      '<< /Size ${_index.size} /Root ${_index.rootRef} '
      '${_index.infoRef == null ? '' : '/Info ${_index.infoRef} '}'
      '/Prev $lastStartXref >>\n',
    );
    buffer.write('startxref\n');
    buffer.write('$xrefOffset\n');
    buffer.write('%%EOF\n');

    return Uint8List.fromList(<int>[
      ..._originalBytes,
      ...buffer.toString().codeUnits,
    ]);
  }

  _UpdatedObject _replaceWidgetState({
    required int objectNumber,
    required String valueToken,
  }) {
    final afterValue = _replaceKey(
      objectNumber: objectNumber,
      key: 'V',
      valueToken: valueToken,
    );
    final body = _replaceOrAppend(afterValue.body, 'AS', valueToken);
    return _UpdatedObject(body: body, generation: afterValue.generation);
  }

  _UpdatedObject _replaceObjectValue({
    required int objectNumber,
    required String key,
    required String valueToken,
  }) {
    return _replaceKey(
      objectNumber: objectNumber,
      key: key,
      valueToken: valueToken,
    );
  }

  _UpdatedObject _replaceKey({
    required int objectNumber,
    required String key,
    required String valueToken,
  }) {
    final object = _index.objects[objectNumber];
    if (object == null) {
      throw PdfEditableExportException('Object $objectNumber not found.');
    }
    return _UpdatedObject(
      body: _replaceOrAppend(object.body, key, valueToken),
      generation: object.generation + 1,
    );
  }

  String _replaceOrAppend(String body, String key, String valueToken) {
    final pattern = RegExp(
      '/$key\\s+(\\[[^\\]]*\\]|\\((?:\\\\.|[^)])*\\)|/[^\\s<>\\[\\]()]+)',
    );
    if (pattern.hasMatch(body)) {
      return body.replaceFirst(pattern, '/$key $valueToken');
    }
    final end = body.lastIndexOf('>>');
    if (end < 0) {
      throw PdfEditableExportException('Object body is not a dictionary.');
    }
    return '${body.substring(0, end)} /$key $valueToken ${body.substring(end)}';
  }

  String _pdfString(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\012');
    return '($escaped)';
  }

  String _pdfStringArray(List<String> values) {
    return '[ ${values.map(_pdfString).join(' ')} ]';
  }

  List<_ObjectRange> _contiguousRanges(List<int> sortedObjects) {
    if (sortedObjects.isEmpty) {
      return const <_ObjectRange>[];
    }
    final ranges = <_ObjectRange>[];
    var start = sortedObjects.first;
    var previous = start;
    for (final objectNumber in sortedObjects.skip(1)) {
      if (objectNumber == previous + 1) {
        previous = objectNumber;
        continue;
      }
      ranges.add(_ObjectRange(start: start, length: previous - start + 1));
      start = objectNumber;
      previous = objectNumber;
    }
    ranges.add(_ObjectRange(start: start, length: previous - start + 1));
    return ranges;
  }
}

final class _ObjectIndex {
  _ObjectIndex({
    required this.objects,
    required this.rootRef,
    required this.infoRef,
    required this.size,
    required this.lastStartXref,
  });

  final Map<int, _ParsedObject> objects;
  final String rootRef;
  final String? infoRef;
  final int size;
  final int lastStartXref;

  static _ObjectIndex parse(String content) {
    final objectPattern = RegExp(
      r'(\d+)\s+(\d+)\s+obj\s*(.*?)\s*endobj',
      dotAll: true,
    );
    final objects = <int, _ParsedObject>{};
    for (final match in objectPattern.allMatches(content)) {
      final objectNumber = int.parse(match.group(1)!);
      final generation = int.parse(match.group(2)!);
      objects[objectNumber] = _ParsedObject(
        objectNumber: objectNumber,
        generation: generation,
        body: match.group(3)!,
      );
    }

    final trailerPattern = RegExp(
      r'trailer\s*<<(.*?)>>\s*startxref\s+(\d+)',
      dotAll: true,
    );
    final trailers = trailerPattern.allMatches(content).toList(growable: false);
    if (trailers.isEmpty) {
      throw const PdfEditableExportException('Could not find trailer.');
    }
    final lastTrailer = trailers.last;
    final trailerBody = lastTrailer.group(1)!;
    final rootMatch = RegExp(
      r'/Root\s+(\d+\s+\d+\s+R)',
    ).firstMatch(trailerBody);
    if (rootMatch == null) {
      throw const PdfEditableExportException('Could not find trailer root.');
    }
    final infoMatch = RegExp(
      r'/Info\s+(\d+\s+\d+\s+R)',
    ).firstMatch(trailerBody);
    final sizeMatch = RegExp(r'/Size\s+(\d+)').firstMatch(trailerBody);
    final lastStartXref = int.parse(lastTrailer.group(2)!);
    return _ObjectIndex(
      objects: objects,
      rootRef: rootMatch.group(1)!,
      infoRef: infoMatch?.group(1),
      size: sizeMatch == null
          ? (objects.keys.isEmpty
                ? 0
                : objects.keys.reduce((a, b) => a > b ? a : b) + 1)
          : int.parse(sizeMatch.group(1)!),
      lastStartXref: lastStartXref,
    );
  }

  int? parentRefFor(int widgetObjectNumber) {
    final object = objects[widgetObjectNumber];
    if (object == null) {
      return null;
    }
    final match = RegExp(r'/Parent\s+(\d+)\s+\d+\s+R').firstMatch(object.body);
    return match == null ? null : int.parse(match.group(1)!);
  }
}

final class _ParsedObject {
  const _ParsedObject({
    required this.objectNumber,
    required this.generation,
    required this.body,
  });

  final int objectNumber;
  final int generation;
  final String body;
}

final class _UpdatedObject {
  const _UpdatedObject({required this.body, required this.generation});

  final String body;
  final int generation;
}

final class _ObjectRange {
  const _ObjectRange({required this.start, required this.length});

  final int start;
  final int length;
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
