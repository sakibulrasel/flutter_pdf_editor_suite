import 'dart:typed_data';

import '../pdf_exceptions.dart';
import 'pdf_objects.dart';
import 'zlib/zlib.dart';

/// Resolves indirect references inside stream dictionaries.
typedef PdfResolver = PdfObject? Function(PdfObject? object);

/// Decodes [stream]'s data through every filter in its `/Filter` entry
/// (PDF 32000-1, section 7.4).
///
/// Image-only filters (DCT, JPX, CCITT, JBIG2) are not decoded here; they
/// throw [PdfUnsupportedFeatureException] with
/// [PdfUnsupportedFeature.streamFilter].
Uint8List decodeStreamData(PdfStream stream, {PdfResolver? resolve}) {
  PdfObject? lookup(PdfObject? object) =>
      resolve == null ? object : resolve(object);

  final filterObject = lookup(stream.dict['Filter']);
  final parmsObject = lookup(stream.dict['DecodeParms']);
  final filters = <String>[
    if (filterObject is PdfName) filterObject.value,
    if (filterObject is PdfArray)
      for (final item in filterObject.items)
        if (lookup(item) case final PdfName name) name.value,
  ];
  final parms = <PdfDict?>[
    if (parmsObject is PdfDict) parmsObject,
    if (parmsObject is PdfArray)
      for (final item in parmsObject.items)
        switch (lookup(item)) {
          final PdfDict dict => dict,
          _ => null,
        },
  ];

  var data = stream.rawData;
  for (var i = 0; i < filters.length; i++) {
    final parm = i < parms.length ? parms[i] : null;
    data = applyFilter(filters[i], data, parm, resolve: resolve);
  }
  return data;
}

/// Applies a single decode [filter] with optional [parms].
Uint8List applyFilter(
  String filter,
  Uint8List data,
  PdfDict? parms, {
  PdfResolver? resolve,
}) {
  switch (filter) {
    case 'FlateDecode' || 'Fl':
      return applyPredictor(zlibInflate(data), parms, resolve: resolve);
    case 'LZWDecode' || 'LZW':
      final earlyChange = _intParam(parms, 'EarlyChange', 1, resolve);
      return applyPredictor(
        lzwDecode(data, earlyChange: earlyChange),
        parms,
        resolve: resolve,
      );
    case 'ASCIIHexDecode' || 'AHx':
      return asciiHexDecode(data);
    case 'ASCII85Decode' || 'A85':
      return ascii85Decode(data);
    case 'RunLengthDecode' || 'RL':
      return runLengthDecode(data);
    case 'Crypt':
      // Only the Identity crypt filter can appear in unencrypted files.
      return data;
    default:
      throw PdfUnsupportedFeatureException(
        PdfUnsupportedFeature.streamFilter,
        operation: 'Decoding a /$filter stream',
      );
  }
}

int _intParam(PdfDict? parms, String key, int fallback, PdfResolver? resolve) {
  if (parms == null) {
    return fallback;
  }
  final raw = parms[key];
  final value = resolve == null ? raw : resolve(raw);
  return value is PdfNumber ? value.intValue : fallback;
}

/// Reverses a TIFF (2) or PNG (10-15) predictor described by [parms].
Uint8List applyPredictor(Uint8List data, PdfDict? parms, {PdfResolver? resolve}) {
  final predictor = _intParam(parms, 'Predictor', 1, resolve);
  if (predictor <= 1) {
    return data;
  }
  final colors = _intParam(parms, 'Colors', 1, resolve);
  final bitsPerComponent = _intParam(parms, 'BitsPerComponent', 8, resolve);
  final columns = _intParam(parms, 'Columns', 1, resolve);
  final bitsPerPixel = colors * bitsPerComponent;
  final bytesPerPixel = (bitsPerPixel + 7) ~/ 8;
  final rowLength = (bitsPerPixel * columns + 7) ~/ 8;
  if (rowLength <= 0) {
    return data;
  }

  if (predictor == 2) {
    return _undoTiffPredictor(data, rowLength, bytesPerPixel, bitsPerComponent);
  }

  // PNG predictors: each row starts with a filter-type byte.
  final output = <int>[];
  var previous = Uint8List(rowLength);
  var offset = 0;
  while (offset < data.length) {
    final type = data[offset++];
    final row = Uint8List(rowLength);
    final available = data.length - offset < rowLength
        ? data.length - offset
        : rowLength;
    for (var i = 0; i < available; i++) {
      row[i] = data[offset + i];
    }
    offset += available;
    for (var i = 0; i < rowLength; i++) {
      final left = i >= bytesPerPixel ? row[i - bytesPerPixel] : 0;
      final up = previous[i];
      final upLeft = i >= bytesPerPixel ? previous[i - bytesPerPixel] : 0;
      switch (type) {
        case 1: // Sub
          row[i] = (row[i] + left) & 0xFF;
        case 2: // Up
          row[i] = (row[i] + up) & 0xFF;
        case 3: // Average
          row[i] = (row[i] + ((left + up) >> 1)) & 0xFF;
        case 4: // Paeth
          row[i] = (row[i] + _paeth(left, up, upLeft)) & 0xFF;
        default: // 0 = None, and unknown types are left as they are
          break;
      }
    }
    output.addAll(row.sublist(0, available));
    previous = row;
  }
  return Uint8List.fromList(output);
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) {
    return a;
  }
  return pb <= pc ? b : c;
}

Uint8List _undoTiffPredictor(
  Uint8List data,
  int rowLength,
  int bytesPerPixel,
  int bitsPerComponent,
) {
  if (bitsPerComponent != 8) {
    // Only the common 8-bit case is implemented.
    throw PdfUnsupportedFeatureException(
      PdfUnsupportedFeature.streamFilter,
      operation: 'A TIFF predictor with $bitsPerComponent bits per component',
    );
  }
  final output = Uint8List.fromList(data);
  for (var rowStart = 0; rowStart < output.length; rowStart += rowLength) {
    final rowEnd = rowStart + rowLength < output.length
        ? rowStart + rowLength
        : output.length;
    for (var i = rowStart + bytesPerPixel; i < rowEnd; i++) {
      output[i] = (output[i] + output[i - bytesPerPixel]) & 0xFF;
    }
  }
  return output;
}

/// Decodes LZW data (section 7.4.4).
Uint8List lzwDecode(Uint8List data, {int earlyChange = 1}) {
  const clearTable = 256;
  const endOfData = 257;
  final output = <int>[];
  var table = <List<int>>[];
  void resetTable() {
    table = <List<int>>[
      for (var i = 0; i < 256; i++) <int>[i],
      const <int>[], // 256 clear-table
      const <int>[], // 257 end-of-data
    ];
  }

  resetTable();
  var codeLength = 9;
  List<int>? previous;
  var bitBuffer = 0;
  var bitCount = 0;
  var index = 0;

  while (true) {
    while (bitCount < codeLength && index < data.length) {
      bitBuffer = ((bitBuffer << 8) | data[index++]) & 0xFFFFFF;
      bitCount += 8;
    }
    if (bitCount < codeLength) {
      break;
    }
    final code = (bitBuffer >> (bitCount - codeLength)) & ((1 << codeLength) - 1);
    bitCount -= codeLength;

    if (code == clearTable) {
      resetTable();
      codeLength = 9;
      previous = null;
      continue;
    }
    if (code == endOfData) {
      break;
    }
    List<int> entry;
    if (code < table.length) {
      entry = table[code];
      if (previous != null) {
        table.add(<int>[...previous, entry.first]);
      }
    } else if (code == table.length && previous != null) {
      entry = <int>[...previous, previous.first];
      table.add(entry);
    } else {
      break; // corrupt data
    }
    output.addAll(entry);
    previous = entry;
    if (table.length + earlyChange >= (1 << codeLength) && codeLength < 12) {
      codeLength++;
    }
  }
  return Uint8List.fromList(output);
}

/// Decodes ASCIIHex data (section 7.4.2).
Uint8List asciiHexDecode(Uint8List data) {
  final output = <int>[];
  int? high;
  for (final byte in data) {
    if (byte == 0x3E) {
      break; // '>' end of data
    }
    final value = _hexDigit(byte);
    if (value < 0) {
      continue;
    }
    if (high == null) {
      high = value;
    } else {
      output.add((high << 4) | value);
      high = null;
    }
  }
  if (high != null) {
    output.add(high << 4);
  }
  return Uint8List.fromList(output);
}

int _hexDigit(int byte) {
  if (byte >= 0x30 && byte <= 0x39) {
    return byte - 0x30;
  }
  if (byte >= 0x41 && byte <= 0x46) {
    return byte - 0x37;
  }
  if (byte >= 0x61 && byte <= 0x66) {
    return byte - 0x57;
  }
  return -1;
}

/// Decodes ASCII base-85 data (section 7.4.3).
Uint8List ascii85Decode(Uint8List data) {
  final output = <int>[];
  final group = <int>[];
  var start = 0;
  // Optional "<~" prefix.
  if (data.length >= 2 && data[0] == 0x3C && data[1] == 0x7E) {
    start = 2;
  }
  void flush(List<int> digits, int count) {
    var value = 0;
    for (final digit in digits) {
      value = value * 85 + digit;
    }
    final bytes = <int>[
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
    output.addAll(bytes.take(count));
  }

  for (var i = start; i < data.length; i++) {
    final byte = data[i];
    if (byte == 0x7E) {
      break; // '~>' end of data
    }
    if (byte == 0x7A && group.isEmpty) {
      output.addAll(const <int>[0, 0, 0, 0]); // 'z'
      continue;
    }
    if (byte < 0x21 || byte > 0x75) {
      continue; // whitespace and anything outside '!'..'u'
    }
    group.add(byte - 0x21);
    if (group.length == 5) {
      flush(group, 4);
      group.clear();
    }
  }
  if (group.length > 1) {
    final count = group.length - 1;
    while (group.length < 5) {
      group.add(84); // pad with 'u'
    }
    flush(group, count);
  }
  return Uint8List.fromList(output);
}

/// Decodes RunLength data (section 7.4.5).
Uint8List runLengthDecode(Uint8List data) {
  final output = <int>[];
  var i = 0;
  while (i < data.length) {
    final length = data[i++];
    if (length == 128) {
      break; // end of data
    }
    if (length < 128) {
      final end = i + length + 1 <= data.length ? i + length + 1 : data.length;
      output.addAll(data.sublist(i, end));
      i = end;
    } else if (i < data.length) {
      final count = 257 - length;
      final value = data[i++];
      for (var n = 0; n < count; n++) {
        output.add(value);
      }
    }
  }
  return Uint8List.fromList(output);
}
