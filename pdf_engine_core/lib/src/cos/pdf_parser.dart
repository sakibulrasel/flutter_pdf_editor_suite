import 'dart:typed_data';

import 'pdf_objects.dart';

/// Thrown internally when bytes cannot be parsed as a PDF object.
///
/// The document layer turns this into a `PdfInvalidDocumentException` or
/// falls back to repairing the file.
class PdfParseException implements Exception {
  /// Creates a parse exception at byte [offset].
  const PdfParseException(this.message, this.offset);

  /// What went wrong.
  final String message;

  /// Byte offset where parsing failed.
  final int offset;

  @override
  String toString() => 'PdfParseException at $offset: $message';
}

/// Resolves a `/Length` that is stored as an indirect reference.
typedef PdfLengthResolver = int? Function(PdfRef ref);

/// An indirect object read from the file: `num gen obj ... endobj`.
final class PdfIndirectObject {
  /// Creates an indirect object record.
  const PdfIndirectObject(this.number, this.generation, this.object);

  /// Object number.
  final int number;

  /// Generation number.
  final int generation;

  /// The object's value.
  final PdfObject object;
}

/// Parses PDF objects from raw bytes (PDF 32000-1, section 7.2 and 7.3).
final class PdfObjectParser {
  /// Creates a parser over [data] starting at [position].
  PdfObjectParser(this.data, [this.position = 0]);

  /// The bytes being parsed.
  final Uint8List data;

  /// Current read position.
  int position;

  /// Whether the end of the data has been reached.
  bool get isAtEnd => position >= data.length;

  /// Whether [byte] is PDF whitespace.
  static bool isWhitespace(int byte) =>
      byte == 0x20 ||
      byte == 0x0A ||
      byte == 0x0D ||
      byte == 0x09 ||
      byte == 0x0C ||
      byte == 0x00;

  /// Whether [byte] is a PDF delimiter.
  static bool isDelimiter(int byte) =>
      byte == 0x28 || // (
      byte == 0x29 || // )
      byte == 0x3C || // <
      byte == 0x3E || // >
      byte == 0x5B || // [
      byte == 0x5D || // ]
      byte == 0x7B || // {
      byte == 0x7D || // }
      byte == 0x2F || // /
      byte == 0x25; //   %

  static bool _isRegular(int byte) => !isWhitespace(byte) && !isDelimiter(byte);

  /// Skips whitespace and `%` comments.
  void skipWhitespace() {
    while (position < data.length) {
      final byte = data[position];
      if (isWhitespace(byte)) {
        position++;
      } else if (byte == 0x25) {
        while (position < data.length &&
            data[position] != 0x0A &&
            data[position] != 0x0D) {
          position++;
        }
      } else {
        return;
      }
    }
  }

  /// Reads a run of regular characters (a keyword or number) as text.
  String readToken() {
    skipWhitespace();
    final start = position;
    while (position < data.length && _isRegular(data[position])) {
      position++;
    }
    return String.fromCharCodes(data, start, position);
  }

  /// Reads a non-negative integer, or returns `null` without moving.
  int? tryReadInt() {
    final saved = position;
    final token = readToken();
    final value = int.tryParse(token);
    if (value == null) {
      position = saved;
    }
    return value;
  }

  /// Parses the next object. A pair of integers followed by `R` becomes a
  /// [PdfRef].
  PdfObject parseObject() {
    skipWhitespace();
    if (isAtEnd) {
      throw PdfParseException('Unexpected end of data', position);
    }
    final byte = data[position];
    switch (byte) {
      case 0x2F: // /
        return _parseName();
      case 0x28: // (
        return _parseLiteralString();
      case 0x3C: // <
        if (position + 1 < data.length && data[position + 1] == 0x3C) {
          return _parseDictionary();
        }
        return _parseHexString();
      case 0x5B: // [
        return _parseArray();
    }
    if (byte == 0x2B || byte == 0x2D || byte == 0x2E || _isDigit(byte)) {
      return _parseNumberOrRef();
    }
    final start = position;
    final token = readToken();
    switch (token) {
      case 'true':
        return const PdfBool(true);
      case 'false':
        return const PdfBool(false);
      case 'null':
        return PdfNull.instance;
    }
    throw PdfParseException(
      token.isEmpty
          ? 'Unexpected byte 0x${byte.toRadixString(16)}'
          : 'Unexpected keyword "$token"',
      start,
    );
  }

  /// Parses `num gen obj <object> [stream ... endstream] endobj` at the
  /// current position.
  PdfIndirectObject parseIndirectObject({PdfLengthResolver? resolveLength}) {
    final start = position;
    final number = tryReadInt();
    final generation = tryReadInt();
    if (number == null || generation == null || readToken() != 'obj') {
      throw PdfParseException('Expected "N G obj"', start);
    }
    var object = parseObject();
    skipWhitespace();
    if (object is PdfDict && _matchesKeyword('stream')) {
      position += 6;
      object = PdfStream(object, _readStreamData(object, resolveLength));
    }
    return PdfIndirectObject(number, generation, object);
  }

  Uint8List _readStreamData(PdfDict dict, PdfLengthResolver? resolveLength) {
    // The keyword is followed by CRLF or LF (a lone CR is tolerated).
    if (position < data.length && data[position] == 0x0D) {
      position++;
    }
    if (position < data.length && data[position] == 0x0A) {
      position++;
    }
    final start = position;

    final lengthObject = dict['Length'];
    int? length;
    if (lengthObject is PdfNumber) {
      length = lengthObject.intValue;
    } else if (lengthObject is PdfRef && resolveLength != null) {
      length = resolveLength(lengthObject);
    }
    if (length != null &&
        length >= 0 &&
        start + length <= data.length &&
        _endstreamFollows(start + length)) {
      position = start + length;
      final bytes = Uint8List.sublistView(data, start, start + length);
      _skipEndstream();
      return Uint8List.fromList(bytes);
    }

    // /Length is missing or wrong: find the endstream keyword instead.
    final end = _indexOf(_endstreamBytes, start);
    if (end < 0) {
      throw PdfParseException('Stream has no endstream', start);
    }
    var dataEnd = end;
    if (dataEnd > start && data[dataEnd - 1] == 0x0A) {
      dataEnd--;
    }
    if (dataEnd > start && data[dataEnd - 1] == 0x0D) {
      dataEnd--;
    }
    position = end;
    _skipEndstream();
    return Uint8List.fromList(Uint8List.sublistView(data, start, dataEnd));
  }

  bool _endstreamFollows(int offset) {
    var index = offset;
    while (index < data.length && isWhitespace(data[index])) {
      index++;
    }
    return _matchesAt(_endstreamBytes, index);
  }

  void _skipEndstream() {
    skipWhitespace();
    if (_matchesKeyword('endstream')) {
      position += _endstreamBytes.length;
    }
  }

  static final Uint8List _endstreamBytes = Uint8List.fromList(
    'endstream'.codeUnits,
  );

  bool _matchesKeyword(String keyword) {
    if (!_matchesAt(Uint8List.fromList(keyword.codeUnits), position)) {
      return false;
    }
    final after = position + keyword.length;
    return after >= data.length || !_isRegular(data[after]);
  }

  bool _matchesAt(Uint8List pattern, int offset) {
    if (offset < 0 || offset + pattern.length > data.length) {
      return false;
    }
    for (var i = 0; i < pattern.length; i++) {
      if (data[offset + i] != pattern[i]) {
        return false;
      }
    }
    return true;
  }

  int _indexOf(Uint8List pattern, int from) {
    final last = data.length - pattern.length;
    for (var i = from; i <= last; i++) {
      if (_matchesAt(pattern, i)) {
        return i;
      }
    }
    return -1;
  }

  static bool _isDigit(int byte) => byte >= 0x30 && byte <= 0x39;

  PdfObject _parseNumberOrRef() {
    final start = position;
    final token = readToken();
    final number = _parseNumber(token);
    if (number == null) {
      throw PdfParseException('Invalid number "$token"', start);
    }
    if (number is int && number >= 0) {
      // Look ahead for "gen R".
      final afterFirst = position;
      final generation = tryReadInt();
      if (generation != null && generation >= 0) {
        skipWhitespace();
        if (position < data.length &&
            data[position] == 0x52 && // R
            (position + 1 >= data.length || !_isRegular(data[position + 1]))) {
          position++;
          return PdfRef(number, generation);
        }
      }
      position = afterFirst;
    }
    return PdfNumber(number);
  }

  static num? _parseNumber(String token) {
    if (token.isEmpty) {
      return null;
    }
    final asInt = int.tryParse(token);
    if (asInt != null) {
      return asInt;
    }
    // PDF reals: optional sign, digits with one '.', e.g. "-.5", "4.".
    var text = token;
    // Some producers write "--5" or "+-5"; keep the last sign.
    while (text.length > 1 &&
        (text[0] == '+' || text[0] == '-') &&
        (text[1] == '+' || text[1] == '-')) {
      text = text.substring(1);
    }
    if (text.endsWith('.')) {
      text = '${text}0';
    }
    if (text.startsWith('.') ||
        text.startsWith('-.') ||
        text.startsWith('+.')) {
      text = text.replaceFirst('.', '0.');
    }
    return double.tryParse(text) ?? int.tryParse(text);
  }

  PdfName _parseName() {
    position++; // '/'
    final out = <int>[];
    while (position < data.length && _isRegular(data[position])) {
      final byte = data[position];
      if (byte == 0x23 && position + 2 < data.length) {
        // '#xx' hex escape
        final hex = String.fromCharCodes(data, position + 1, position + 3);
        final value = int.tryParse(hex, radix: 16);
        if (value != null) {
          out.add(value);
          position += 3;
          continue;
        }
      }
      out.add(byte);
      position++;
    }
    return PdfName(String.fromCharCodes(out));
  }

  PdfString _parseLiteralString() {
    position++; // '('
    final out = <int>[];
    var depth = 1;
    while (position < data.length) {
      final byte = data[position++];
      if (byte == 0x5C) {
        // backslash
        if (position >= data.length) {
          break;
        }
        final next = data[position++];
        switch (next) {
          case 0x6E: // n
            out.add(0x0A);
          case 0x72: // r
            out.add(0x0D);
          case 0x74: // t
            out.add(0x09);
          case 0x62: // b
            out.add(0x08);
          case 0x66: // f
            out.add(0x0C);
          case 0x0D: // backslash + EOL: line continuation
            if (position < data.length && data[position] == 0x0A) {
              position++;
            }
          case 0x0A:
            break;
          default:
            if (next >= 0x30 && next <= 0x37) {
              var code = next - 0x30;
              for (var count = 1; count < 3; count++) {
                if (position >= data.length ||
                    data[position] < 0x30 ||
                    data[position] > 0x37) {
                  break;
                }
                code = code * 8 + data[position++] - 0x30;
              }
              out.add(code & 0xFF);
            } else {
              // \( \) \\ and unknown escapes map to the character itself.
              out.add(next);
            }
        }
        continue;
      }
      if (byte == 0x28) {
        depth++;
      } else if (byte == 0x29) {
        depth--;
        if (depth == 0) {
          break;
        }
      }
      out.add(byte);
    }
    return PdfString(Uint8List.fromList(out));
  }

  PdfString _parseHexString() {
    position++; // '<'
    final out = <int>[];
    int? high;
    while (position < data.length) {
      final byte = data[position++];
      if (byte == 0x3E) {
        break;
      }
      final value = _hexValue(byte);
      if (value < 0) {
        continue; // whitespace or junk
      }
      if (high == null) {
        high = value;
      } else {
        out.add((high << 4) | value);
        high = null;
      }
    }
    if (high != null) {
      out.add(high << 4); // odd digit count: last digit is padded with 0
    }
    return PdfString(Uint8List.fromList(out), isHex: true);
  }

  static int _hexValue(int byte) {
    if (byte >= 0x30 && byte <= 0x39) {
      return byte - 0x30;
    }
    if (byte >= 0x41 && byte <= 0x46) {
      return byte - 0x41 + 10;
    }
    if (byte >= 0x61 && byte <= 0x66) {
      return byte - 0x61 + 10;
    }
    return -1;
  }

  PdfArray _parseArray() {
    position++; // '['
    final items = <PdfObject>[];
    while (true) {
      skipWhitespace();
      if (isAtEnd) {
        throw PdfParseException('Unterminated array', position);
      }
      if (data[position] == 0x5D) {
        position++;
        return PdfArray(items);
      }
      items.add(parseObject());
    }
  }

  PdfDict _parseDictionary() {
    position += 2; // '<<'
    final entries = <String, PdfObject>{};
    while (true) {
      skipWhitespace();
      if (isAtEnd) {
        throw PdfParseException('Unterminated dictionary', position);
      }
      if (data[position] == 0x3E &&
          position + 1 < data.length &&
          data[position + 1] == 0x3E) {
        position += 2;
        return PdfDict(entries);
      }
      if (data[position] != 0x2F) {
        // Malformed entry: skip one object and continue.
        parseObject();
        continue;
      }
      final key = _parseName().value;
      skipWhitespace();
      if (position + 1 < data.length &&
          data[position] == 0x3E &&
          data[position + 1] == 0x3E) {
        // Key with no value right before '>>': treat as null.
        entries[key] = PdfNull.instance;
        continue;
      }
      entries[key] = parseObject();
    }
  }
}
