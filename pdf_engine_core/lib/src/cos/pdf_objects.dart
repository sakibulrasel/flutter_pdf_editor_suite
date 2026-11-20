import 'dart:convert';
import 'dart:typed_data';

/// A PDF object (PDF 32000-1, section 7.3).
///
/// These are the low-level "COS" objects that every PDF is built from. Most
/// apps do not need them; they are the foundation for form parsing, page
/// operations and saving.
sealed class PdfObject {
  const PdfObject();
}

/// The PDF `null` object.
final class PdfNull extends PdfObject {
  const PdfNull._();

  /// The single `null` instance.
  static const PdfNull instance = PdfNull._();

  @override
  String toString() => 'null';
}

/// A PDF boolean.
final class PdfBool extends PdfObject {
  /// Creates a boolean object.
  const PdfBool(this.value);

  /// The boolean value.
  final bool value;

  @override
  bool operator ==(Object other) => other is PdfBool && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}

/// A PDF integer or real number.
final class PdfNumber extends PdfObject {
  /// Creates a number object.
  const PdfNumber(this.value);

  /// The numeric value; an `int` for PDF integers.
  final num value;

  /// The value as an integer (reals are truncated).
  int get intValue => value.toInt();

  /// The value as a double.
  double get doubleValue => value.toDouble();

  @override
  bool operator ==(Object other) => other is PdfNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}

/// A PDF name such as `/Type`. [value] holds the name without the slash,
/// with `#xx` escapes decoded, one character per byte.
final class PdfName extends PdfObject {
  /// Creates a name object.
  const PdfName(this.value);

  /// The name without the leading slash.
  final String value;

  @override
  bool operator ==(Object other) => other is PdfName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '/$value';
}

/// A PDF string. PDF strings are byte sequences; use [text] for the decoded
/// text-string value.
final class PdfString extends PdfObject {
  /// Creates a string from raw [bytes].
  PdfString(this.bytes, {this.isHex = false});

  /// Encodes [text] as a PDF text string: PDFDocEncoding when every character
  /// fits, otherwise UTF-16BE with a byte order mark.
  factory PdfString.fromText(String text) =>
      PdfString(encodePdfTextString(text));

  /// The raw bytes of the string.
  final Uint8List bytes;

  /// Whether the string was written in hexadecimal form (`<...>`).
  final bool isHex;

  /// The string decoded as a PDF text string (section 7.9.2.2).
  String get text => decodePdfTextString(bytes);

  @override
  bool operator ==(Object other) =>
      other is PdfString && _bytesEqual(other.bytes, bytes);

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => '($text)';
}

/// A PDF array.
final class PdfArray extends PdfObject {
  /// Creates an array, optionally with initial [items].
  PdfArray([List<PdfObject>? items]) : items = items ?? <PdfObject>[];

  /// The array elements.
  final List<PdfObject> items;

  /// Number of elements.
  int get length => items.length;

  /// Element at [index].
  PdfObject operator [](int index) => items[index];

  @override
  String toString() => '[${items.join(' ')}]';
}

/// A PDF dictionary. Keys are names without the slash.
final class PdfDict extends PdfObject {
  /// Creates a dictionary, optionally with initial [entries].
  PdfDict([Map<String, PdfObject>? entries])
    : entries = entries ?? <String, PdfObject>{};

  /// The dictionary entries.
  final Map<String, PdfObject> entries;

  /// Value for [key], or `null` when absent.
  PdfObject? operator [](String key) => entries[key];

  /// Sets [key] to [value].
  void operator []=(String key, PdfObject value) => entries[key] = value;

  /// Removes [key].
  void remove(String key) => entries.remove(key);

  /// Whether [key] is present.
  bool containsKey(String key) => entries.containsKey(key);

  /// A shallow copy; nested objects are shared.
  PdfDict copy() => PdfDict(Map<String, PdfObject>.of(entries));

  @override
  String toString() =>
      '<<${entries.entries.map((e) => ' /${e.key} ${e.value}').join()} >>';
}

/// An indirect reference such as `12 0 R`.
final class PdfRef extends PdfObject {
  /// Creates a reference to object [number] with [generation].
  const PdfRef(this.number, [this.generation = 0]);

  /// The object number.
  final int number;

  /// The generation number.
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is PdfRef &&
      other.number == number &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(number, generation);

  @override
  String toString() => '$number $generation R';
}

/// A PDF stream: a dictionary plus a byte sequence. [rawData] is the data as
/// stored in the file, still encoded by the stream's filters.
final class PdfStream extends PdfObject {
  /// Creates a stream object.
  PdfStream(this.dict, this.rawData);

  /// The stream dictionary.
  final PdfDict dict;

  /// The encoded stream bytes.
  Uint8List rawData;

  @override
  String toString() => '$dict stream(${rawData.length} bytes)';
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

// PDFDocEncoding (PDF 32000-1, Annex D.2) matches Latin-1 except for these
// code points.
const Map<int, int> _pdfDocToUnicode = <int, int>{
  0x18: 0x02D8, 0x19: 0x02C7, 0x1A: 0x02C6, 0x1B: 0x02D9, //
  0x1C: 0x02DD, 0x1D: 0x02DB, 0x1E: 0x02DA, 0x1F: 0x02DC, //
  0x80: 0x2022, 0x81: 0x2020, 0x82: 0x2021, 0x83: 0x2026, //
  0x84: 0x2014, 0x85: 0x2013, 0x86: 0x0192, 0x87: 0x2044, //
  0x88: 0x2039, 0x89: 0x203A, 0x8A: 0x2212, 0x8B: 0x2030, //
  0x8C: 0x201E, 0x8D: 0x201C, 0x8E: 0x201D, 0x8F: 0x2018, //
  0x90: 0x2019, 0x91: 0x201A, 0x92: 0x2122, 0x93: 0xFB01, //
  0x94: 0xFB02, 0x95: 0x0141, 0x96: 0x0152, 0x97: 0x0160, //
  0x98: 0x0178, 0x99: 0x017D, 0x9A: 0x0131, 0x9B: 0x0142, //
  0x9C: 0x0153, 0x9D: 0x0161, 0x9E: 0x017E, 0xA0: 0x20AC, //
};

final Map<int, int> _unicodeToPdfDoc = <int, int>{
  for (final entry in _pdfDocToUnicode.entries) entry.value: entry.key,
};

/// Decodes PDF text-string [bytes]: UTF-16BE or UTF-8 when a byte order
/// mark is present, otherwise PDFDocEncoding.
String decodePdfTextString(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    final units = <int>[];
    for (var i = 2; i + 1 < bytes.length; i += 2) {
      units.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.writeCharCode(_pdfDocToUnicode[byte] ?? byte);
  }
  return buffer.toString();
}

/// Encodes [text] as a PDF text string (see [PdfString.fromText]).
Uint8List encodePdfTextString(String text) {
  final out = <int>[];
  for (final unit in text.codeUnits) {
    final mapped = _unicodeToPdfDoc[unit];
    if (mapped != null) {
      out.add(mapped);
    } else if (unit <= 0xFF && !_pdfDocToUnicode.containsKey(unit)) {
      out.add(unit);
    } else {
      // Not representable in PDFDocEncoding: use UTF-16BE with a BOM.
      final utf16 = <int>[0xFE, 0xFF];
      for (final u in text.codeUnits) {
        utf16
          ..add(u >> 8)
          ..add(u & 0xFF);
      }
      return Uint8List.fromList(utf16);
    }
  }
  return Uint8List.fromList(out);
}
