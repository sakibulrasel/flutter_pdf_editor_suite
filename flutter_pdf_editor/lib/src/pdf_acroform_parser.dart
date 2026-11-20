import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf_engine_core/cos.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

/// Parser for extracting common AcroForm field types from a PDF.
///
/// Built on the `pdf_engine_core` object model, so it reads classic PDFs as
/// well as PDF 1.5+ files with compressed object streams and cross-reference
/// streams (the layout Acrobat and Word use).
final class PdfAcroFormParser {
  /// Parses form fields from a [source] PDF.
  Future<List<PdfFormField>> parse(PdfDocumentSource source) async {
    final bytes = switch (source.type) {
      PdfDocumentSourceType.bytes => source.bytes!,
      PdfDocumentSourceType.file => await _readFile(source.path!),
    };
    return parseBytes(bytes);
  }

  /// Parses form fields directly from raw PDF [bytes].
  ///
  /// Returns an empty list when the PDF has no form. Throws
  /// [PdfInvalidDocumentException] when [bytes] are not a readable PDF, and
  /// [PdfUnsupportedFeatureException] for encrypted PDFs and XFA-only forms.
  List<PdfFormField> parseBytes(Uint8List bytes) {
    return parseDocument(PdfCosDocument.open(bytes));
  }

  /// Parses form fields from an already opened [document].
  List<PdfFormField> parseDocument(PdfCosDocument document) {
    final acroForm = document.resolve(document.catalog['AcroForm']);
    if (acroForm is! PdfDict) {
      return const <PdfFormField>[];
    }

    final pages = document.pages;
    final pageIndexByRef = <int, int>{};
    final annotationPageIndex = <int, int>{};
    for (final page in pages) {
      if (page.ref case final PdfRef ref) {
        pageIndexByRef[ref.number] = page.index;
      }
      final annots = document.resolve(page.dict['Annots']);
      if (annots is PdfArray) {
        for (final annot in annots.items) {
          if (annot is PdfRef) {
            annotationPageIndex[annot.number] = page.index;
          }
        }
      }
    }

    final context = _ParseContext(
      document: document,
      pages: pages,
      pageIndexByRef: pageIndexByRef,
      annotationPageIndex: annotationPageIndex,
    );
    final fields = <PdfFormField>[];
    final rootFields = document.resolve(acroForm['Fields']);
    if (rootFields is PdfArray) {
      for (final field in rootFields.items) {
        fields.addAll(
          _collectFields(
            context: context,
            node: field,
            inheritedName: null,
            inheritedType: null,
            inheritedValue: null,
            inheritedFlags: null,
          ),
        );
      }
    }

    if (fields.isEmpty && acroForm['XFA'] != null) {
      throw PdfUnsupportedFeatureException(
        PdfUnsupportedFeature.xfaForms,
        operation: 'Form parsing',
      );
    }
    return fields;
  }

  List<PdfFormField> _collectFields({
    required _ParseContext context,
    required PdfObject node,
    required String? inheritedName,
    required String? inheritedType,
    required PdfObject? inheritedValue,
    required int? inheritedFlags,
  }) {
    final document = context.document;
    final dictionary = document.resolve(node);
    if (dictionary is! PdfDict || !context.seen.add(dictionary)) {
      return const <PdfFormField>[];
    }
    final objectNumber = node is PdfRef ? node.number : null;

    final name =
        _text(document.resolve(dictionary['T'])) ??
        inheritedName ??
        'field_${objectNumber ?? context.seen.length}';
    final type = _name(document.resolve(dictionary['FT'])) ?? inheritedType;
    final value = document.resolve(dictionary['V']) ?? inheritedValue;
    final flags =
        _int(document.resolve(dictionary['Ff'])) ?? inheritedFlags ?? 0;

    if (_name(document.resolve(dictionary['Subtype'])) == 'Widget') {
      if (objectNumber == null) {
        // Widgets must be indirect objects; without a number the field
        // cannot be saved back, so it is skipped.
        return const <PdfFormField>[];
      }
      final field = _buildField(
        context: context,
        objectNumber: objectNumber,
        dictionary: dictionary,
        name: name,
        type: type,
        value: value,
        flags: flags,
      );
      return field == null ? const <PdfFormField>[] : <PdfFormField>[field];
    }

    final kids = document.resolve(dictionary['Kids']);
    if (kids is! PdfArray) {
      return const <PdfFormField>[];
    }
    return <PdfFormField>[
      for (final kid in kids.items)
        ..._collectFields(
          context: context,
          node: kid,
          inheritedName: name,
          inheritedType: type,
          inheritedValue: value,
          inheritedFlags: flags,
        ),
    ];
  }

  PdfFormField? _buildField({
    required _ParseContext context,
    required int objectNumber,
    required PdfDict dictionary,
    required String name,
    required String? type,
    required PdfObject? value,
    required int flags,
  }) {
    final document = context.document;
    final rect = _numbers(document, dictionary['Rect']);
    if (rect.length != 4 || type == null) {
      return null;
    }

    final pageRef = dictionary['P'];
    final pageIndex =
        (pageRef is PdfRef ? context.pageIndexByRef[pageRef.number] : null) ??
        context.annotationPageIndex[objectNumber] ??
        -1;
    if (pageIndex < 0 || pageIndex >= context.pages.length) {
      return null;
    }

    // Convert from PDF space (origin bottom-left of the media box) to
    // top-left page coordinates.
    final mediaBox = context.pages[pageIndex].mediaBox;
    final left = math.min(rect[0], rect[2]);
    final right = math.max(rect[0], rect[2]);
    final bottom = math.min(rect[1], rect[3]);
    final top = math.max(rect[1], rect[3]);
    final bounds = PdfRect(
      left: left - mediaBox[0],
      top: mediaBox[3] - top,
      width: right - left,
      height: top - bottom,
    );
    final isReadOnly = (flags & 1) != 0;
    final id = 'form_$objectNumber';

    switch (type) {
      case 'Tx':
        return PdfTextFormField(
          id: id,
          name: name,
          pageIndex: pageIndex,
          bounds: bounds,
          value: _valueToString(value),
          defaultValue: _text(document.resolve(dictionary['DV'])) ?? '',
          isMultiline: (flags & (1 << 12)) != 0,
          isReadOnly: isReadOnly,
        );
      case 'Btn':
        if ((flags & (1 << 16)) != 0) {
          return null; // push button
        }
        final onValue = _appearanceOnValue(document, dictionary) ?? 'Yes';
        final current = _valueToString(value);
        if ((flags & (1 << 15)) != 0) {
          return PdfRadioFormField(
            id: id,
            name: name,
            groupName: name,
            pageIndex: pageIndex,
            bounds: bounds,
            optionValue: onValue,
            isSelected: current == onValue,
            isReadOnly: isReadOnly,
          );
        }
        return PdfCheckboxFormField(
          id: id,
          name: name,
          pageIndex: pageIndex,
          bounds: bounds,
          isChecked: current == onValue,
          onValue: onValue,
          markStyle: _checkboxMarkStyle(document, dictionary),
          isReadOnly: isReadOnly,
        );
      case 'Sig':
        return PdfSignatureFormField(
          id: id,
          name: name,
          pageIndex: pageIndex,
          bounds: bounds,
          isReadOnly: isReadOnly,
        );
      case 'Ch':
        final options = _choiceOptions(document, dictionary);
        if ((flags & (1 << 17)) != 0) {
          return PdfComboBoxFormField(
            id: id,
            name: name,
            pageIndex: pageIndex,
            bounds: bounds,
            options: options,
            selectedValue: _valueToString(value),
            isReadOnly: isReadOnly,
          );
        }
        return PdfListBoxFormField(
          id: id,
          name: name,
          pageIndex: pageIndex,
          bounds: bounds,
          options: options,
          selectedValues: _valueToStrings(document, value),
          isMultiSelect: (flags & (1 << 21)) != 0,
          isReadOnly: isReadOnly,
        );
    }
    return null;
  }

  String? _appearanceOnValue(PdfCosDocument document, PdfDict dictionary) {
    final appearance = document.resolve(dictionary['AP']);
    if (appearance is! PdfDict) {
      return null;
    }
    final normal = document.resolve(appearance['N']);
    if (normal is! PdfDict) {
      return null;
    }
    for (final key in normal.entries.keys) {
      if (key != 'Off') {
        return key;
      }
    }
    return null;
  }

  PdfCheckboxMarkStyle _checkboxMarkStyle(
    PdfCosDocument document,
    PdfDict dictionary,
  ) {
    final characteristics = document.resolve(dictionary['MK']);
    final caption = characteristics is PdfDict
        ? _text(document.resolve(characteristics['CA']))
        : null;
    return switch (caption) {
      '4' => PdfCheckboxMarkStyle.check,
      '5' => PdfCheckboxMarkStyle.cross,
      'l' || 'n' => PdfCheckboxMarkStyle.circle,
      'N' || 'H' => PdfCheckboxMarkStyle.star,
      _ => PdfCheckboxMarkStyle.check,
    };
  }

  List<PdfChoiceOption> _choiceOptions(
    PdfCosDocument document,
    PdfDict dictionary,
  ) {
    final rawOptions = document.resolve(dictionary['Opt']);
    if (rawOptions is! PdfArray) {
      return const <PdfChoiceOption>[];
    }
    final options = <PdfChoiceOption>[];
    for (final item in rawOptions.items) {
      final option = document.resolve(item);
      if (option is PdfString) {
        options.add(PdfChoiceOption(value: option.text, label: option.text));
        continue;
      }
      if (option is PdfArray && option.length >= 2) {
        final value = _text(document.resolve(option[0])) ?? '';
        final label = _text(document.resolve(option[1])) ?? '';
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

  static String? _text(PdfObject? object) => switch (object) {
    PdfString string => string.text,
    PdfName(:final value) => value,
    _ => null,
  };

  static String? _name(PdfObject? object) => switch (object) {
    PdfName(:final value) => value,
    _ => null,
  };

  static int? _int(PdfObject? object) => switch (object) {
    PdfNumber number => number.intValue,
    _ => null,
  };

  static List<double> _numbers(PdfCosDocument document, PdfObject? object) {
    final array = document.resolve(object);
    if (array is! PdfArray) {
      return const <double>[];
    }
    return <double>[
      for (final item in array.items)
        if (document.resolve(item) case final PdfNumber number)
          number.doubleValue,
    ];
  }

  static String _valueToString(PdfObject? value) => _text(value) ?? '';

  static List<String> _valueToStrings(
    PdfCosDocument document,
    PdfObject? value,
  ) {
    if (value is PdfArray) {
      return <String>[
        for (final item in value.items)
          if (_text(document.resolve(item)) case final String text
              when text.isNotEmpty)
            text,
      ];
    }
    final single = _text(value);
    return single == null || single.isEmpty
        ? const <String>[]
        : <String>[single];
  }
}

final class _ParseContext {
  _ParseContext({
    required this.document,
    required this.pages,
    required this.pageIndexByRef,
    required this.annotationPageIndex,
  });

  final PdfCosDocument document;
  final List<PdfCosPage> pages;
  final Map<int, int> pageIndexByRef;
  final Map<int, int> annotationPageIndex;

  /// Field dictionaries already visited (guards against /Kids cycles).
  final Set<PdfDict> seen = Set<PdfDict>.identity();
}

Future<Uint8List> _readFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw PdfFileNotFoundException(path);
  }
  return file.readAsBytes();
}
