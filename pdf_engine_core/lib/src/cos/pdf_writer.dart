import 'dart:typed_data';

import 'pdf_cos_document.dart';
import 'pdf_objects.dart';

/// Serializes PDF objects to bytes (PDF 32000-1, section 7.3).
final class PdfObjectSerializer {
  const PdfObjectSerializer._();

  /// Appends the bytes of [object] to [out].
  ///
  /// Streams are only valid as the top-level value of an indirect object;
  /// use [writeIndirectObject] for those.
  static void write(PdfObject object, List<int> out) {
    switch (object) {
      case PdfNull():
        _ascii(out, 'null');
      case PdfBool(:final value):
        _ascii(out, value ? 'true' : 'false');
      case PdfNumber(:final value):
        _ascii(out, formatNumber(value));
      case PdfName(:final value):
        _writeName(value, out);
      case final PdfString string:
        _writeString(string, out);
      case PdfArray(:final items):
        out.add(0x5B); // [
        for (var i = 0; i < items.length; i++) {
          if (i > 0) {
            out.add(0x20);
          }
          write(items[i], out);
        }
        out.add(0x5D); // ]
      case PdfDict(:final entries):
        _ascii(out, '<<');
        for (final entry in entries.entries) {
          out.add(0x20);
          _writeName(entry.key, out);
          out.add(0x20);
          write(entry.value, out);
        }
        _ascii(out, ' >>');
      case PdfRef(:final number, :final generation):
        _ascii(out, '$number $generation R');
      case PdfStream():
        throw ArgumentError(
          'A stream can only be written as an indirect object',
        );
    }
  }

  /// Appends `number generation obj ... endobj` to [out].
  static void writeIndirectObject(
    int number,
    int generation,
    PdfObject object,
    List<int> out,
  ) {
    _ascii(out, '$number $generation obj\n');
    if (object is PdfStream) {
      final dict = object.dict.copy()
        ..['Length'] = PdfNumber(object.rawData.length);
      write(dict, out);
      _ascii(out, '\nstream\n');
      out.addAll(object.rawData);
      _ascii(out, '\nendstream');
    } else {
      write(object, out);
    }
    _ascii(out, '\nendobj\n');
  }

  /// Formats a number the way PDF expects: no exponent, no trailing zeros.
  static String formatNumber(num value) {
    if (value is int) {
      return '$value';
    }
    final asDouble = value.toDouble();
    if (!asDouble.isFinite) {
      return '0';
    }
    if (asDouble == asDouble.roundToDouble() && asDouble.abs() < 1e15) {
      return '${asDouble.toInt()}';
    }
    var text = asDouble.toStringAsFixed(6);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return text == '-0' ? '0' : text;
  }

  static void _ascii(List<int> out, String text) => out.addAll(text.codeUnits);

  static void _writeName(String name, List<int> out) {
    out.add(0x2F); // /
    for (final unit in name.codeUnits) {
      final byte = unit & 0xFF;
      final needsEscape =
          byte < 0x21 ||
          byte > 0x7E ||
          byte == 0x23 || // #
          byte == 0x28 ||
          byte == 0x29 ||
          byte == 0x3C ||
          byte == 0x3E ||
          byte == 0x5B ||
          byte == 0x5D ||
          byte == 0x7B ||
          byte == 0x7D ||
          byte == 0x2F ||
          byte == 0x25;
      if (needsEscape) {
        out.add(0x23);
        out.addAll(byte.toRadixString(16).padLeft(2, '0').codeUnits);
      } else {
        out.add(byte);
      }
    }
  }

  static void _writeString(PdfString string, List<int> out) {
    if (string.isHex) {
      out.add(0x3C); // <
      for (final byte in string.bytes) {
        out.addAll(byte.toRadixString(16).padLeft(2, '0').codeUnits);
      }
      out.add(0x3E); // >
      return;
    }
    out.add(0x28); // (
    for (final byte in string.bytes) {
      if (byte == 0x28 || byte == 0x29 || byte == 0x5C) {
        out
          ..add(0x5C)
          ..add(byte);
      } else if (byte >= 0x20 && byte <= 0x7E) {
        out.add(byte);
      } else {
        // Octal escape keeps the file ASCII-safe, e.g. \012 for a newline.
        out
          ..add(0x5C)
          ..addAll(byte.toRadixString(8).padLeft(3, '0').codeUnits);
      }
    }
    out.add(0x29); // )
  }
}

/// Collects changed and new objects and appends them to the original file as
/// an incremental update (PDF 32000-1, section 7.5.6).
///
/// The original bytes are kept unchanged, so earlier revisions (and any
/// digital signatures over them) stay intact. When the newest section of the
/// original uses a cross-reference stream, the update does too.
final class PdfIncrementalUpdate {
  /// Starts an update on top of [document].
  PdfIncrementalUpdate(this.document) : _nextNumber = document.size;

  /// The document being updated.
  final PdfCosDocument document;

  final Map<int, PdfObject> _objects = <int, PdfObject>{};
  int _nextNumber;

  /// Whether any object was changed or added.
  bool get hasChanges => _objects.isNotEmpty;

  /// Replaces object [number] with [object]. The generation number is kept.
  void set(int number, PdfObject object) => _objects[number] = object;

  /// Adds a new object and returns a reference to it.
  PdfRef add(PdfObject object) {
    final number = _nextNumber++;
    _objects[number] = object;
    return PdfRef(number);
  }

  /// Builds the updated file. Returns the original bytes when nothing
  /// changed. A repaired document is written as a full rewrite instead,
  /// because its cross-reference data cannot be chained to.
  Uint8List build() {
    if (_objects.isEmpty) {
      return document.bytes;
    }
    final previousXref = document.lastXrefOffset;
    if (previousXref == null || document.wasRepaired) {
      return PdfDocumentRewriter.rewrite(document, overrides: _objects);
    }

    // Only the appended part is built in memory; the original bytes are
    // copied once at the end.
    final original = document.bytes;
    final base = original.length;
    final out = <int>[];
    if (base > 0 && original[base - 1] != 0x0A && original[base - 1] != 0x0D) {
      out.add(0x0A);
    }
    final offsets = <int, int>{};
    final generations = <int, int>{};
    for (final number in _objects.keys.toList()..sort()) {
      final generation = document.generationOf(number);
      offsets[number] = base + out.length;
      generations[number] = generation;
      PdfObjectSerializer.writeIndirectObject(
        number,
        generation,
        _objects[number]!,
        out,
      );
    }

    final trailer = PdfDict(<String, PdfObject>{
      'Size': PdfNumber(_nextNumber),
      if (document.trailer['Root'] case final PdfObject root) 'Root': root,
      if (document.trailer['Info'] case final PdfObject info) 'Info': info,
      if (document.trailer['ID'] case final PdfObject id) 'ID': id,
      'Prev': PdfNumber(previousXref),
    });

    if (document.usesXrefStreams) {
      _writeXrefStream(base, out, offsets, generations, trailer);
    } else {
      _writeClassicXref(base, out, offsets, generations, trailer);
    }
    return Uint8List(base + out.length)
      ..setRange(0, base, original)
      ..setRange(base, base + out.length, out);
  }

  void _writeClassicXref(
    int base,
    List<int> out,
    Map<int, int> offsets,
    Map<int, int> generations,
    PdfDict trailer,
  ) {
    final xrefOffset = base + out.length;
    final buffer = StringBuffer('xref\n');
    for (final range in _ranges(offsets.keys.toList()..sort())) {
      buffer.write('${range.first} ${range.length}\n');
      for (final number in range) {
        buffer.write(
          '${offsets[number]!.toString().padLeft(10, '0')} '
          '${generations[number]!.toString().padLeft(5, '0')} n \n',
        );
      }
    }
    buffer.write('trailer\n');
    out.addAll(buffer.toString().codeUnits);
    PdfObjectSerializer.write(trailer, out);
    out.addAll('\nstartxref\n$xrefOffset\n%%EOF\n'.codeUnits);
  }

  void _writeXrefStream(
    int base,
    List<int> out,
    Map<int, int> offsets,
    Map<int, int> generations,
    PdfDict trailer,
  ) {
    // The xref stream is itself a new object and lists its own offset.
    // A local copy keeps build() repeatable.
    final xrefNumber = _nextNumber;
    final xrefOffset = base + out.length;
    offsets[xrefNumber] = xrefOffset;
    generations[xrefNumber] = 0;

    final numbers = offsets.keys.toList()..sort();
    final ranges = _ranges(numbers);
    final data = <int>[];
    for (final number in numbers) {
      final offset = offsets[number]!;
      final generation = generations[number]!;
      data
        ..add(1) // type 1: in use
        ..add((offset >> 24) & 0xFF)
        ..add((offset >> 16) & 0xFF)
        ..add((offset >> 8) & 0xFF)
        ..add(offset & 0xFF)
        ..add((generation >> 8) & 0xFF)
        ..add(generation & 0xFF);
    }
    final dict = trailer.copy()
      ..['Type'] = const PdfName('XRef')
      ..['Size'] = PdfNumber(xrefNumber + 1)
      ..['W'] = PdfArray(<PdfObject>[
        const PdfNumber(1),
        const PdfNumber(4),
        const PdfNumber(2),
      ])
      ..['Index'] = PdfArray(<PdfObject>[
        for (final range in ranges) ...<PdfObject>[
          PdfNumber(range.first),
          PdfNumber(range.length),
        ],
      ]);
    PdfObjectSerializer.writeIndirectObject(
      xrefNumber,
      0,
      PdfStream(dict, Uint8List.fromList(data)),
      out,
    );
    out.addAll('startxref\n$xrefOffset\n%%EOF\n'.codeUnits);
  }
}

/// Writes a complete new file containing every object reachable from the
/// trailer, with a classic cross-reference table.
///
/// Compressed objects are written uncompressed, unreachable objects and old
/// revisions are dropped, and stream data is copied as stored.
final class PdfDocumentRewriter {
  const PdfDocumentRewriter._();

  /// Rewrites [document], replacing or adding objects from [overrides].
  static Uint8List rewrite(
    PdfCosDocument document, {
    Map<int, PdfObject> overrides = const <int, PdfObject>{},
  }) {
    PdfObject? objectFor(int number) =>
        overrides[number] ?? document.getObject(number);

    final trailer = PdfDict(<String, PdfObject>{
      if (document.trailer['Root'] case final PdfObject root) 'Root': root,
      if (document.trailer['Info'] case final PdfObject info) 'Info': info,
      if (document.trailer['ID'] case final PdfObject id) 'ID': id,
    });

    // Collect every object reachable from the trailer.
    final reachable = <int, PdfObject>{};
    final pending = <PdfObject>[trailer];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      switch (current) {
        case PdfRef(:final number):
          if (reachable.containsKey(number)) {
            continue;
          }
          final object = objectFor(number);
          if (object != null) {
            reachable[number] = object;
            pending.add(object);
          }
        case PdfArray(:final items):
          pending.addAll(items);
        case PdfDict(:final entries):
          pending.addAll(entries.values);
        case PdfStream(:final dict):
          pending.add(dict);
        default:
          break;
      }
    }

    final out = <int>[
      ...'%PDF-${document.version}\n'.codeUnits,
      // Binary comment so transfer tools treat the file as binary.
      0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A,
    ];
    final numbers = reachable.keys.toList()..sort();
    final offsets = <int, int>{};
    final generations = <int, int>{};
    for (final number in numbers) {
      final generation =
          overrides.containsKey(number) && document.entryFor(number) == null
          ? 0
          : document.generationOf(number);
      offsets[number] = out.length;
      generations[number] = generation;
      PdfObjectSerializer.writeIndirectObject(
        number,
        generation,
        reachable[number]!,
        out,
      );
    }

    final size = numbers.isEmpty ? 1 : numbers.last + 1;
    trailer['Size'] = PdfNumber(size);
    final xrefOffset = out.length;
    final buffer = StringBuffer('xref\n0 $size\n');
    // Free entries form a linked list starting at object 0.
    final free = <int>[
      for (var n = 1; n < size; n++)
        if (!offsets.containsKey(n)) n,
    ];
    buffer.write(
      '${(free.isEmpty ? 0 : free.first).toString().padLeft(10, '0')} 65535 f \n',
    );
    var freeIndex = 0;
    for (var n = 1; n < size; n++) {
      final offset = offsets[n];
      if (offset != null) {
        buffer.write(
          '${offset.toString().padLeft(10, '0')} '
          '${generations[n]!.toString().padLeft(5, '0')} n \n',
        );
      } else {
        freeIndex++;
        final next = freeIndex < free.length ? free[freeIndex] : 0;
        buffer.write('${next.toString().padLeft(10, '0')} 00001 f \n');
      }
    }
    buffer.write('trailer\n');
    out.addAll(buffer.toString().codeUnits);
    PdfObjectSerializer.write(trailer, out);
    out.addAll('\nstartxref\n$xrefOffset\n%%EOF\n'.codeUnits);
    return Uint8List.fromList(out);
  }
}

/// Groups sorted object numbers into consecutive runs.
List<List<int>> _ranges(List<int> sorted) {
  final ranges = <List<int>>[];
  for (final number in sorted) {
    if (ranges.isNotEmpty && ranges.last.last + 1 == number) {
      ranges.last.add(number);
    } else {
      ranges.add(<int>[number]);
    }
  }
  return ranges;
}
