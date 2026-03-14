import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf_engine_core/pdf_engine_core.dart';

/// Lightweight parser for extracting common AcroForm field types from a PDF.
final class PdfAcroFormParser {
  /// Parses form fields from a [source] PDF.
  Future<List<PdfFormField>> parse(PdfDocumentSource source) async {
    final bytes = switch (source.type) {
      PdfDocumentSourceType.bytes => source.bytes!,
      PdfDocumentSourceType.file => await File(source.path!).readAsBytes(),
    };
    return parseBytes(bytes);
  }

  /// Parses form fields directly from raw PDF [bytes].
  List<PdfFormField> parseBytes(Uint8List bytes) {
    final document = _PdfObjectIndex.fromBytes(bytes);
    final acroFormRef = document.catalog.getRef('AcroForm');
    if (acroFormRef == null) {
      return const <PdfFormField>[];
    }

    final pageEntries = document.pageEntries;
    final annotsToPageIndex = <int, int>{};
    for (final page in pageEntries) {
      for (final annotRef in page.dictionary.getRefs('Annots')) {
        annotsToPageIndex[annotRef.objectNumber] = page.pageIndex;
      }
    }

    final acroForm = document.object(acroFormRef.objectNumber).dictionary;
    final fields = <PdfFormField>[];
    final seen = <int>{};
    for (final fieldRef in acroForm.getRefs('Fields')) {
      fields.addAll(
        _collectFields(
          document: document,
          fieldRef: fieldRef.objectNumber,
          pageEntries: pageEntries,
          annotsToPageIndex: annotsToPageIndex,
          seen: seen,
          inheritedName: null,
          inheritedType: null,
          inheritedValue: null,
          inheritedFlags: null,
        ),
      );
    }
    return fields;
  }

  List<PdfFormField> _collectFields({
    required _PdfObjectIndex document,
    required int fieldRef,
    required List<_PdfPageEntry> pageEntries,
    required Map<int, int> annotsToPageIndex,
    required Set<int> seen,
    required String? inheritedName,
    required String? inheritedType,
    required Object? inheritedValue,
    required int? inheritedFlags,
  }) {
    if (!seen.add(fieldRef)) {
      return const <PdfFormField>[];
    }

    final object = document.object(fieldRef);
    final dictionary = object.dictionary;
    final name =
        dictionary.getString('T') ?? inheritedName ?? 'field_$fieldRef';
    final type = dictionary.getName('FT') ?? inheritedType;
    final value = dictionary.getValue('V') ?? inheritedValue;
    final flags = dictionary.getInt('Ff') ?? inheritedFlags ?? 0;
    final kids = dictionary.getRefs('Kids');

    final isWidget = dictionary.getName('Subtype') == 'Widget';
    if (isWidget) {
      final field = _buildField(
        objectNumber: fieldRef,
        dictionary: dictionary,
        name: name,
        type: type,
        value: value,
        flags: flags,
        pageEntries: pageEntries,
        annotsToPageIndex: annotsToPageIndex,
      );
      return field == null ? const <PdfFormField>[] : <PdfFormField>[field];
    }

    if (kids.isEmpty) {
      return const <PdfFormField>[];
    }

    final fields = <PdfFormField>[];
    for (final kid in kids) {
      fields.addAll(
        _collectFields(
          document: document,
          fieldRef: kid.objectNumber,
          pageEntries: pageEntries,
          annotsToPageIndex: annotsToPageIndex,
          seen: seen,
          inheritedName: name,
          inheritedType: type,
          inheritedValue: value,
          inheritedFlags: flags,
        ),
      );
    }
    return fields;
  }

  PdfFormField? _buildField({
    required int objectNumber,
    required _PdfDictionary dictionary,
    required String name,
    required String? type,
    required Object? value,
    required int flags,
    required List<_PdfPageEntry> pageEntries,
    required Map<int, int> annotsToPageIndex,
  }) {
    final rectValues = dictionary.getNumbers('Rect');
    if (rectValues.length != 4 || type == null) {
      return null;
    }

    final pageRef = dictionary.getRef('P');
    final pageIndex =
        (pageRef != null
            ? pageEntries.indexWhere(
                (entry) => entry.objectNumber == pageRef.objectNumber,
              )
            : annotsToPageIndex[objectNumber]) ??
        -1;
    if (pageIndex < 0 || pageIndex >= pageEntries.length) {
      return null;
    }

    final pageHeight = pageEntries[pageIndex].height;
    final left = math.min(rectValues[0], rectValues[2]);
    final right = math.max(rectValues[0], rectValues[2]);
    final bottom = math.min(rectValues[1], rectValues[3]);
    final top = math.max(rectValues[1], rectValues[3]);
    final bounds = PdfRect(
      left: left,
      top: pageHeight - top,
      width: right - left,
      height: top - bottom,
    );
    final isReadOnly = (flags & 1) != 0;

    if (type == 'Tx') {
      return PdfTextFormField(
        id: 'form_$objectNumber',
        name: name,
        pageIndex: pageIndex,
        bounds: bounds,
        value: _valueToString(value),
        defaultValue: dictionary.getString('DV') ?? '',
        isMultiline: (flags & (1 << 12)) != 0,
        isReadOnly: isReadOnly,
      );
    }

    if (type == 'Btn') {
      if ((flags & (1 << 16)) != 0) {
        return null;
      }
      final isRadio = (flags & (1 << 15)) != 0;
      final onValue = dictionary.getAppearanceOnValue() ?? 'Yes';
      final currentName = value is _PdfName
          ? value.value
          : _valueToString(value);
      if (isRadio) {
        return PdfRadioFormField(
          id: 'form_$objectNumber',
          name: name,
          groupName: name,
          pageIndex: pageIndex,
          bounds: bounds,
          optionValue: onValue,
          isSelected: currentName == onValue,
          isReadOnly: isReadOnly,
        );
      }
      return PdfCheckboxFormField(
        id: 'form_$objectNumber',
        name: name,
        pageIndex: pageIndex,
        bounds: bounds,
        isChecked: currentName == onValue,
        onValue: onValue,
        markStyle: dictionary.getCheckboxMarkStyle(),
        isReadOnly: isReadOnly,
      );
    }

    if (type == 'Sig') {
      return PdfSignatureFormField(
        id: 'form_$objectNumber',
        name: name,
        pageIndex: pageIndex,
        bounds: bounds,
        isReadOnly: isReadOnly,
      );
    }

    if (type == 'Ch') {
      final isCombo = (flags & (1 << 17)) != 0;
      final options = dictionary.getChoiceOptions();
      if (isCombo) {
        return PdfComboBoxFormField(
          id: 'form_$objectNumber',
          name: name,
          pageIndex: pageIndex,
          bounds: bounds,
          options: options,
          selectedValue: _valueToString(value),
          isReadOnly: isReadOnly,
        );
      }
      return PdfListBoxFormField(
        id: 'form_$objectNumber',
        name: name,
        pageIndex: pageIndex,
        bounds: bounds,
        options: options,
        selectedValues: _valueToStrings(value),
        isMultiSelect: (flags & (1 << 21)) != 0,
        isReadOnly: isReadOnly,
      );
    }

    return null;
  }

  String _valueToString(Object? value) {
    return switch (value) {
      _PdfName(:final value) => value,
      String value => value,
      _ => '',
    };
  }

  List<String> _valueToStrings(Object? value) {
    return switch (value) {
      _PdfName(:final value) => <String>[value],
      String value when value.isNotEmpty => <String>[value],
      List<Object?> list =>
        list
            .map(_valueToString)
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      _ => const <String>[],
    };
  }
}

final class _PdfObjectIndex {
  _PdfObjectIndex(this._objects);

  final Map<int, _PdfObject> _objects;

  static _PdfObjectIndex fromBytes(Uint8List bytes) {
    final content = latin1.decode(bytes);
    final objects = <int, _PdfObject>{};
    final objectPattern = RegExp(
      r'(\d+)\s+\d+\s+obj\s*(.*?)\s*endobj',
      dotAll: true,
    );
    for (final match in objectPattern.allMatches(content)) {
      final objectNumber = int.parse(match.group(1)!);
      final body = match.group(2)!;
      objects[objectNumber] = _PdfObject(
        objectNumber: objectNumber,
        body: body,
        dictionary: _PdfDictionary.parse(body),
      );
    }
    return _PdfObjectIndex(objects);
  }

  _PdfObject object(int objectNumber) => _objects[objectNumber]!;

  _PdfDictionary get catalog => _objects.values
      .firstWhere((object) => object.dictionary.getName('Type') == 'Catalog')
      .dictionary;

  List<_PdfPageEntry> get pageEntries {
    final pages = _objects.values
        .where((object) => object.dictionary.getName('Type') == 'Page')
        .map((object) {
          final mediaBox = object.dictionary.getNumbers('MediaBox');
          final height = mediaBox.length == 4 ? mediaBox[3] - mediaBox[1] : 0.0;
          return _PdfPageEntry(
            objectNumber: object.objectNumber,
            pageIndex: 0,
            height: height,
            dictionary: object.dictionary,
          );
        })
        .toList(growable: false);
    return [
      for (var index = 0; index < pages.length; index++)
        _PdfPageEntry(
          objectNumber: pages[index].objectNumber,
          pageIndex: index,
          height: pages[index].height,
          dictionary: pages[index].dictionary,
        ),
    ];
  }
}

final class _PdfObject {
  const _PdfObject({
    required this.objectNumber,
    required this.body,
    required this.dictionary,
  });

  final int objectNumber;
  final String body;
  final _PdfDictionary dictionary;
}

final class _PdfPageEntry {
  const _PdfPageEntry({
    required this.objectNumber,
    required this.pageIndex,
    required this.height,
    required this.dictionary,
  });

  final int objectNumber;
  final int pageIndex;
  final double height;
  final _PdfDictionary dictionary;
}

final class _PdfRef {
  const _PdfRef(this.objectNumber);

  final int objectNumber;
}

final class _PdfName {
  const _PdfName(this.value);

  final String value;
}

final class _PdfDictionary {
  const _PdfDictionary(this._values);

  final Map<String, Object?> _values;

  static _PdfDictionary parse(String body) {
    final start = body.indexOf('<<');
    if (start < 0) {
      return const _PdfDictionary(<String, Object?>{});
    }
    final end = _findMatchingDictionaryEnd(body, start);
    if (end < 0) {
      return const _PdfDictionary(<String, Object?>{});
    }
    final parser = _PdfTokenizer(body.substring(start + 2, end));
    return _PdfDictionary(parser.parseDictionaryContent());
  }

  String? getName(String key) => switch (_values[key]) {
    _PdfName(:final value) => value,
    _ => null,
  };

  String? getString(String key) => switch (_values[key]) {
    String value => value,
    _PdfName(:final value) => value,
    _ => null,
  };

  int? getInt(String key) => switch (_values[key]) {
    int value => value,
    double value => value.round(),
    _ => null,
  };

  _PdfRef? getRef(String key) => switch (_values[key]) {
    _PdfRef value => value,
    _ => null,
  };

  Object? getValue(String key) => _values[key];

  List<_PdfRef> getRefs(String key) {
    final value = _values[key];
    if (value is List) {
      return value.whereType<_PdfRef>().toList(growable: false);
    }
    return const <_PdfRef>[];
  }

  List<double> getNumbers(String key) {
    final value = _values[key];
    if (value is List<Object?>) {
      return value.whereType<num>().map((item) => item.toDouble()).toList();
    }
    return const <double>[];
  }

  _PdfDictionary? getDictionary(String key) => switch (_values[key]) {
    _PdfDictionary value => value,
    _ => null,
  };

  PdfCheckboxMarkStyle getCheckboxMarkStyle() {
    final caption = getDictionary('MK')?.getString('CA');
    return switch (caption) {
      '4' => PdfCheckboxMarkStyle.check,
      '5' => PdfCheckboxMarkStyle.cross,
      'l' || 'n' => PdfCheckboxMarkStyle.circle,
      'N' || 'H' => PdfCheckboxMarkStyle.star,
      _ => PdfCheckboxMarkStyle.check,
    };
  }

  List<Object?> getArray(String key) {
    final value = _values[key];
    if (value is List<Object?>) {
      return value;
    }
    return const <Object?>[];
  }

  List<PdfChoiceOption> getChoiceOptions() {
    final rawOptions = getArray('Opt');
    if (rawOptions.isEmpty) {
      return const <PdfChoiceOption>[];
    }

    final options = <PdfChoiceOption>[];
    for (final rawOption in rawOptions) {
      if (rawOption is String) {
        options.add(PdfChoiceOption(value: rawOption, label: rawOption));
        continue;
      }
      if (rawOption is List<Object?> && rawOption.length >= 2) {
        final value = switch (rawOption.first) {
          String value => value,
          _PdfName(:final value) => value,
          _ => '',
        };
        final label = switch (rawOption[1]) {
          String value => value,
          _PdfName(:final value) => value,
          _ => value,
        };
        if (value.isNotEmpty || label.isNotEmpty) {
          options.add(
            PdfChoiceOption(
              value: value.isEmpty ? label : value,
              label: label.isEmpty ? value : label,
            ),
          );
        }
      }
    }
    return options;
  }

  String? getAppearanceOnValue() {
    final ap = _values['AP'];
    if (ap is _PdfDictionary) {
      final normal = ap._values['N'];
      if (normal is _PdfDictionary) {
        for (final entry in normal._values.entries) {
          if (entry.key != 'Off') {
            return entry.key;
          }
        }
      }
    }
    return null;
  }

  static int _findMatchingDictionaryEnd(String input, int start) {
    var depth = 0;
    for (var index = start; index < input.length - 1; index++) {
      final pair = input.substring(index, index + 2);
      if (pair == '<<') {
        depth++;
        index++;
        continue;
      }
      if (pair == '>>') {
        depth--;
        if (depth == 0) {
          return index;
        }
        index++;
      }
    }
    return -1;
  }
}

final class _PdfTokenizer {
  _PdfTokenizer(this.input);

  final String input;
  int _index = 0;

  Map<String, Object?> parseDictionaryContent() {
    final values = <String, Object?>{};
    while (true) {
      _skipWhitespace();
      if (_index >= input.length) {
        return values;
      }
      if (input[_index] != '/') {
        _index++;
        continue;
      }
      final key = _readName();
      _skipWhitespace();
      values[key] = _readValue();
    }
  }

  Object? _readValue() {
    _skipWhitespace();
    if (_index >= input.length) {
      return null;
    }
    final char = input[_index];
    if (char == '/') {
      return _PdfName(_readName());
    }
    if (char == '(') {
      return _readLiteralString();
    }
    if (char == '[') {
      return _readArray();
    }
    if (_peek('<<')) {
      _index += 2;
      return _PdfDictionary(parseDictionaryContentUntilEnd());
    }
    return _readNumberOrRefOrToken();
  }

  Map<String, Object?> parseDictionaryContentUntilEnd() {
    final values = <String, Object?>{};
    while (true) {
      _skipWhitespace();
      if (_peek('>>')) {
        _index += 2;
        return values;
      }
      if (_index >= input.length) {
        return values;
      }
      if (input[_index] != '/') {
        _index++;
        continue;
      }
      final key = _readName();
      _skipWhitespace();
      values[key] = _readValue();
    }
  }

  Object? _readNumberOrRefOrToken() {
    final first = _readToken();
    if (first.isEmpty) {
      return null;
    }
    final firstNumber = num.tryParse(first);
    final savedIndex = _index;
    _skipWhitespace();
    final second = _readToken();
    final secondNumber = num.tryParse(second);
    if (firstNumber != null && secondNumber != null) {
      _skipWhitespace();
      final third = _readToken();
      if (third == 'R') {
        return _PdfRef(firstNumber.toInt());
      }
      _index = savedIndex;
      return firstNumber;
    }
    _index = savedIndex;
    return firstNumber ?? first;
  }

  List<Object?> _readArray() {
    _index++;
    final values = <Object?>[];
    while (true) {
      _skipWhitespace();
      if (_index >= input.length) {
        return values;
      }
      if (input[_index] == ']') {
        _index++;
        return values;
      }
      values.add(_readValue());
    }
  }

  String _readLiteralString() {
    final buffer = StringBuffer();
    var depth = 0;
    while (_index < input.length) {
      final char = input[_index++];
      if (char == '(') {
        depth++;
        if (depth > 1) {
          buffer.write(char);
        }
        continue;
      }
      if (char == ')') {
        depth--;
        if (depth == 0) {
          return buffer.toString();
        }
      }
      if (char == r'\' && _index < input.length) {
        buffer.write(input[_index++]);
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  String _readName() {
    if (input[_index] == '/') {
      _index++;
    }
    final start = _index;
    while (_index < input.length) {
      final char = input[_index];
      if (_isWhitespace(char) || '[]<>()/'.contains(char)) {
        break;
      }
      _index++;
    }
    return input.substring(start, _index);
  }

  String _readToken() {
    _skipWhitespace();
    final start = _index;
    while (_index < input.length) {
      final char = input[_index];
      if (_isWhitespace(char) || '[]<>()/'.contains(char)) {
        break;
      }
      _index++;
    }
    return input.substring(start, _index);
  }

  void _skipWhitespace() {
    while (_index < input.length && _isWhitespace(input[_index])) {
      _index++;
    }
  }

  bool _peek(String value) =>
      _index + value.length <= input.length &&
      input.substring(_index, _index + value.length) == value;

  bool _isWhitespace(String char) =>
      char == ' ' || char == '\n' || char == '\r' || char == '\t';
}
