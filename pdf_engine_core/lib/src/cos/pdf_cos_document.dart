import 'dart:convert';
import 'dart:typed_data';

import '../pdf_exceptions.dart';
import 'pdf_filters.dart';
import 'pdf_objects.dart';
import 'pdf_parser.dart';

/// Kinds of cross-reference entries (PDF 32000-1, section 7.5.4 and 7.5.8).
enum PdfXrefEntryType {
  /// The object number is free.
  free,

  /// The object is stored at a byte offset in the file.
  inUse,

  /// The object is stored inside a compressed object stream.
  compressed,
}

/// One cross-reference entry.
final class PdfXrefEntry {
  /// Creates an entry. For [PdfXrefEntryType.inUse], [offset] is the byte
  /// offset; for [PdfXrefEntryType.compressed] it is the object-stream number
  /// and [generation] holds the index inside that stream.
  const PdfXrefEntry(this.type, this.offset, this.generation);

  /// Entry type.
  final PdfXrefEntryType type;

  /// Byte offset, or object-stream number for compressed objects.
  final int offset;

  /// Generation number, or index inside the object stream.
  final int generation;
}

/// A page found by walking the page tree, with inherited attributes applied.
final class PdfCosPage {
  /// Creates a page record.
  const PdfCosPage({
    required this.index,
    required this.ref,
    required this.dict,
    required this.mediaBox,
    required this.cropBox,
    required this.rotate,
    required this.resources,
  });

  /// Zero-based page index in document order.
  final int index;

  /// Reference to the page object, when the page is an indirect object.
  final PdfRef? ref;

  /// The page dictionary.
  final PdfDict dict;

  /// `[llx lly urx ury]` in PDF points (inherited, defaults to US Letter).
  final List<double> mediaBox;

  /// Visible area; equals [mediaBox] when not set.
  final List<double> cropBox;

  /// Rotation in degrees: 0, 90, 180 or 270.
  final int rotate;

  /// Resource dictionary, possibly inherited from a parent node.
  final PdfDict? resources;

  /// Page width in points (from [mediaBox]).
  double get width => (mediaBox[2] - mediaBox[0]).abs();

  /// Page height in points (from [mediaBox]).
  double get height => (mediaBox[3] - mediaBox[1]).abs();
}

/// A parsed PDF file: cross-reference data, trailer and lazily loaded
/// objects.
///
/// Reads classic xref tables, cross-reference streams, hybrid files,
/// incremental updates and compressed object streams. When the
/// cross-reference data is broken the file is repaired by scanning for
/// objects, and [wasRepaired] is set.
final class PdfCosDocument {
  PdfCosDocument._({
    required this.bytes,
    required Map<int, PdfXrefEntry> entries,
    required this.trailer,
    required this.lastXrefOffset,
    required this.usesXrefStreams,
    required this.wasRepaired,
    required this.version,
  }) : _entries = entries;

  /// Opens a PDF from [bytes].
  ///
  /// Throws [PdfInvalidDocumentException] when the bytes are not a readable
  /// PDF, and [PdfUnsupportedFeatureException] for encrypted documents.
  factory PdfCosDocument.open(Uint8List bytes) {
    final headerIndex = _indexOf(bytes, _headerBytes, 0, 1024);
    if (headerIndex < 0) {
      throw const PdfInvalidDocumentException(
        'The data is not a PDF document (no %PDF- header).',
      );
    }
    final version = String.fromCharCodes(
      bytes,
      headerIndex + 5,
      headerIndex + 8 <= bytes.length ? headerIndex + 8 : bytes.length,
    );

    PdfCosDocument document;
    try {
      document = _openFromXref(bytes, version);
      // A wrong xref offset usually shows up when loading the catalog.
      if (document.resolve(document.trailer['Root']) is! PdfDict) {
        throw const PdfParseException('Root is not a dictionary', 0);
      }
    } on PdfException {
      rethrow;
    } on Object {
      document = _openByRepair(bytes, version);
    }

    if (document.trailer['Encrypt'] != null) {
      throw PdfUnsupportedFeatureException(
        PdfUnsupportedFeature.encryption,
        operation: 'Opening the PDF',
      );
    }
    if (document.resolve(document.trailer['Root']) is! PdfDict) {
      throw const PdfInvalidDocumentException(
        'The PDF has no document catalog.',
      );
    }
    return document;
  }

  /// The complete file bytes.
  final Uint8List bytes;

  final Map<int, PdfXrefEntry> _entries;

  /// The trailer dictionary of the newest revision (for cross-reference
  /// streams, the stream dictionary).
  final PdfDict trailer;

  /// Offset of the newest cross-reference section, used as `/Prev` by an
  /// incremental update. `null` for repaired files.
  final int? lastXrefOffset;

  /// Whether the newest cross-reference section is a stream (PDF 1.5+).
  final bool usesXrefStreams;

  /// Whether the cross-reference data was broken and rebuilt by scanning.
  final bool wasRepaired;

  /// Header version, such as `'1.7'`.
  final String version;

  final Map<int, PdfObject?> _cache = <int, PdfObject?>{};
  final Map<int, _ObjectStream> _objectStreams = <int, _ObjectStream>{};
  Map<int, PdfXrefEntry>? _scanIndex;
  List<PdfCosPage>? _pages;

  /// All object numbers that have an in-use or compressed entry.
  Iterable<int> get objectNumbers => _entries.entries
      .where((entry) => entry.value.type != PdfXrefEntryType.free)
      .map((entry) => entry.key);

  /// The cross-reference entry for [number], if any.
  PdfXrefEntry? entryFor(int number) => _entries[number];

  /// One more than the highest object number in use (the trailer `/Size`).
  int get size {
    final declared = trailer['Size'];
    var highest = 0;
    for (final number in _entries.keys) {
      if (number > highest) {
        highest = number;
      }
    }
    final fromEntries = highest + 1;
    if (declared is PdfNumber && declared.intValue > fromEntries) {
      return declared.intValue;
    }
    return fromEntries;
  }

  /// Generation number of object [number] (0 when unknown).
  int generationOf(int number) {
    final entry = _entries[number];
    return entry != null && entry.type == PdfXrefEntryType.inUse
        ? entry.generation
        : 0;
  }

  /// The document catalog (`/Root`).
  PdfDict get catalog => resolve(trailer['Root'])! as PdfDict;

  /// The document information dictionary (`/Info`), if present.
  PdfDict? get info => switch (resolve(trailer['Info'])) {
    final PdfDict dict => dict,
    _ => null,
  };

  /// Loads object [number], or returns `null` when it is free or missing.
  PdfObject? getObject(int number) {
    if (_cache.containsKey(number)) {
      return _cache[number];
    }
    // Guards against reference cycles while loading.
    _cache[number] = null;
    final object = _load(number);
    _cache[number] = object;
    return object;
  }

  /// Follows references until a direct object is reached.
  PdfObject? resolve(PdfObject? object) {
    var current = object;
    var hops = 0;
    while (current is PdfRef && hops++ < 32) {
      current = getObject(current.number);
    }
    return current is PdfRef ? null : current;
  }

  /// Decodes a stream's data through its filters.
  Uint8List decodeStream(PdfStream stream) =>
      decodeStreamData(stream, resolve: resolve);

  /// Pages in document order, walking the page tree from the catalog.
  List<PdfCosPage> get pages => _pages ??= _walkPages();

  PdfObject? _load(int number) {
    final entry = _entries[number];
    if (entry == null || entry.type == PdfXrefEntryType.free) {
      return null;
    }
    if (entry.type == PdfXrefEntryType.compressed) {
      return _loadCompressed(entry.offset, entry.generation, number);
    }
    final loaded = _loadAt(entry.offset, number);
    if (loaded != null) {
      return loaded;
    }
    // The xref offset is wrong: look the object up by scanning.
    final scanned = _scan()[number];
    if (scanned != null && scanned.type == PdfXrefEntryType.inUse) {
      return _loadAt(scanned.offset, number);
    }
    return null;
  }

  PdfObject? _loadAt(int offset, int number) {
    if (offset < 0 || offset >= bytes.length) {
      return null;
    }
    try {
      final parser = PdfObjectParser(bytes, offset);
      final indirect = parser.parseIndirectObject(
        resolveLength: _resolveLength,
      );
      if (indirect.number != number) {
        return null;
      }
      return indirect.object;
    } on PdfParseException {
      return null;
    }
  }

  int? _resolveLength(PdfRef ref) {
    final value = resolve(ref);
    return value is PdfNumber ? value.intValue : null;
  }

  PdfObject? _loadCompressed(int streamNumber, int index, int number) {
    final objectStream = _objectStreams[streamNumber] ??= _readObjectStream(
      streamNumber,
    );
    if (objectStream == null) {
      return null;
    }
    // Prefer the index from the xref; fall back to searching by number.
    var slot = index;
    if (slot < 0 ||
        slot >= objectStream.numbers.length ||
        objectStream.numbers[slot] != number) {
      slot = objectStream.numbers.indexOf(number);
      if (slot < 0) {
        return null;
      }
    }
    try {
      final parser = PdfObjectParser(
        objectStream.data,
        objectStream.first + objectStream.offsets[slot],
      );
      return parser.parseObject();
    } on PdfParseException {
      return null;
    }
  }

  _ObjectStream? _readObjectStream(int streamNumber) {
    final stream = getObject(streamNumber);
    if (stream is! PdfStream) {
      return null;
    }
    final count = resolve(stream.dict['N']);
    final first = resolve(stream.dict['First']);
    if (count is! PdfNumber || first is! PdfNumber) {
      return null;
    }
    final data = decodeStream(stream);
    final header = PdfObjectParser(data);
    final numbers = <int>[];
    final offsets = <int>[];
    for (var i = 0; i < count.intValue; i++) {
      final objectNumber = header.tryReadInt();
      final offset = header.tryReadInt();
      if (objectNumber == null || offset == null) {
        break;
      }
      numbers.add(objectNumber);
      offsets.add(offset);
    }
    return _ObjectStream(data, first.intValue, numbers, offsets);
  }

  /// Lazily scans the whole file for `N G obj` headers (used for repair).
  Map<int, PdfXrefEntry> _scan() => _scanIndex ??= _scanObjects(bytes);

  List<PdfCosPage> _walkPages() {
    final result = <PdfCosPage>[];
    final root = catalog['Pages'];
    final visited = <PdfDict>{};

    void walk(
      PdfObject? node,
      PdfDict? resources,
      List<double>? mediaBox,
      List<double>? cropBox,
      int? rotate,
    ) {
      final dict = resolve(node);
      if (dict is! PdfDict || !visited.add(dict) || result.length > 100000) {
        return;
      }
      final ownResources = resolve(dict['Resources']);
      final inheritedResources = ownResources is PdfDict
          ? ownResources
          : resources;
      final inheritedMediaBox = _box(dict['MediaBox']) ?? mediaBox;
      final inheritedCropBox = _box(dict['CropBox']) ?? cropBox;
      final ownRotate = resolve(dict['Rotate']);
      final inheritedRotate = ownRotate is PdfNumber
          ? ownRotate.intValue
          : rotate;

      final type = resolve(dict['Type']);
      final kids = resolve(dict['Kids']);
      final isPage =
          (type is PdfName && type.value == 'Page') ||
          (kids is! PdfArray && type is! PdfName);
      if (isPage) {
        final media =
            inheritedMediaBox ?? const <double>[0, 0, 612, 792]; // US Letter
        final normalizedRotate = ((inheritedRotate ?? 0) % 360 + 360) % 360;
        result.add(
          PdfCosPage(
            index: result.length,
            ref: node is PdfRef ? node : null,
            dict: dict,
            mediaBox: media,
            cropBox: inheritedCropBox ?? media,
            rotate: normalizedRotate - normalizedRotate % 90,
            resources: inheritedResources,
          ),
        );
        return;
      }
      if (kids is PdfArray) {
        for (final kid in kids.items) {
          walk(
            kid,
            inheritedResources,
            inheritedMediaBox,
            inheritedCropBox,
            inheritedRotate,
          );
        }
      }
    }

    walk(root, null, null, null, null);
    return result;
  }

  List<double>? _box(PdfObject? object) {
    final array = resolve(object);
    if (array is! PdfArray || array.length != 4) {
      return null;
    }
    final values = <double>[];
    for (final item in array.items) {
      final number = resolve(item);
      if (number is! PdfNumber) {
        return null;
      }
      values.add(number.doubleValue);
    }
    return values;
  }

  // ---------------------------------------------------------------------
  // Cross-reference reading
  // ---------------------------------------------------------------------

  static PdfCosDocument _openFromXref(Uint8List bytes, String version) {
    final startXref = _findStartXref(bytes);
    if (startXref == null) {
      throw const PdfParseException('startxref not found', 0);
    }
    final entries = <int, PdfXrefEntry>{};
    PdfDict? newestTrailer;
    bool? newestIsStream;
    final visited = <int>{};
    int? offset = startXref;

    while (offset != null && visited.add(offset)) {
      final section = _readXrefSection(bytes, offset, entries);
      newestTrailer ??= section.trailer;
      newestIsStream ??= section.isStream;
      final prev = section.trailer['Prev'];
      offset = prev is PdfNumber ? prev.intValue : null;
    }
    if (newestTrailer == null) {
      throw const PdfParseException('No trailer', 0);
    }
    return PdfCosDocument._(
      bytes: bytes,
      entries: entries,
      trailer: newestTrailer,
      lastXrefOffset: startXref,
      usesXrefStreams: newestIsStream ?? false,
      wasRepaired: false,
      version: version,
    );
  }

  /// Reads one xref section at [offset], adding entries that are not yet
  /// known (newer sections are read first, so they win).
  static _XrefSection _readXrefSection(
    Uint8List bytes,
    int offset,
    Map<int, PdfXrefEntry> entries,
  ) {
    final parser = PdfObjectParser(bytes, offset);
    parser.skipWhitespace();
    final saved = parser.position;
    if (parser.readToken() == 'xref') {
      final trailer = _readClassicTable(parser, entries);
      // Hybrid-reference files also point to an xref stream.
      final xrefStm = trailer['XRefStm'];
      if (xrefStm is PdfNumber) {
        try {
          _readXrefStream(bytes, xrefStm.intValue, entries);
        } on PdfParseException {
          // The table alone is still usable.
        }
      }
      return _XrefSection(trailer, isStream: false);
    }
    parser.position = saved;
    return _XrefSection(
      _readXrefStream(bytes, offset, entries),
      isStream: true,
    );
  }

  static PdfDict _readClassicTable(
    PdfObjectParser parser,
    Map<int, PdfXrefEntry> entries,
  ) {
    while (true) {
      final start = parser.tryReadInt();
      if (start == null) {
        break;
      }
      final count = parser.tryReadInt();
      if (count == null) {
        throw PdfParseException('Bad xref subsection', parser.position);
      }
      for (var i = 0; i < count; i++) {
        final offset = parser.tryReadInt();
        final generation = parser.tryReadInt();
        final kind = parser.readToken();
        if (offset == null || generation == null) {
          throw PdfParseException('Bad xref entry', parser.position);
        }
        final number = start + i;
        if (entries.containsKey(number)) {
          continue;
        }
        entries[number] = kind == 'n'
            ? PdfXrefEntry(PdfXrefEntryType.inUse, offset, generation)
            : PdfXrefEntry(PdfXrefEntryType.free, 0, generation);
      }
    }
    if (parser.readToken() != 'trailer') {
      throw PdfParseException('Expected trailer', parser.position);
    }
    final trailer = parser.parseObject();
    if (trailer is! PdfDict) {
      throw PdfParseException('Trailer is not a dictionary', parser.position);
    }
    return trailer;
  }

  static PdfDict _readXrefStream(
    Uint8List bytes,
    int offset,
    Map<int, PdfXrefEntry> entries,
  ) {
    final indirect = PdfObjectParser(bytes, offset).parseIndirectObject();
    final stream = indirect.object;
    if (stream is! PdfStream) {
      throw PdfParseException('Expected an xref stream', offset);
    }
    final dict = stream.dict;
    final type = dict['Type'];
    if (type is! PdfName || type.value != 'XRef') {
      throw PdfParseException('Expected /Type /XRef', offset);
    }
    final widthsObject = dict['W'];
    if (widthsObject is! PdfArray || widthsObject.length < 3) {
      throw PdfParseException('Xref stream has no /W', offset);
    }
    final widths = <int>[
      for (final item in widthsObject.items)
        item is PdfNumber ? item.intValue : 0,
    ];
    final sizeObject = dict['Size'];
    final size = sizeObject is PdfNumber ? sizeObject.intValue : 0;
    final indexObject = dict['Index'];
    final ranges = <int>[];
    if (indexObject is PdfArray) {
      for (final item in indexObject.items) {
        if (item is PdfNumber) {
          ranges.add(item.intValue);
        }
      }
    } else {
      ranges.addAll(<int>[0, size]);
    }

    // Xref streams may not use indirect references in their dictionary.
    final data = decodeStreamData(stream);
    final rowWidth = widths[0] + widths[1] + widths[2];
    var position = 0;
    int field(int width, int fallback) {
      if (width == 0) {
        return fallback;
      }
      var value = 0;
      for (var i = 0; i < width; i++) {
        value = (value << 8) | data[position++];
      }
      return value;
    }

    for (var r = 0; r + 1 < ranges.length; r += 2) {
      final start = ranges[r];
      final count = ranges[r + 1];
      for (var i = 0; i < count; i++) {
        if (position + rowWidth > data.length) {
          break;
        }
        final entryType = field(widths[0], 1);
        final second = field(widths[1], 0);
        final third = field(widths[2], 0);
        final number = start + i;
        if (entries.containsKey(number)) {
          continue;
        }
        entries[number] = switch (entryType) {
          0 => PdfXrefEntry(PdfXrefEntryType.free, 0, third),
          1 => PdfXrefEntry(PdfXrefEntryType.inUse, second, third),
          2 => PdfXrefEntry(PdfXrefEntryType.compressed, second, third),
          // Unknown types are treated as references to the null object.
          _ => PdfXrefEntry(PdfXrefEntryType.free, 0, 0),
        };
      }
    }
    return dict;
  }

  static int? _findStartXref(Uint8List bytes) {
    final from = bytes.length > 2048 ? bytes.length - 2048 : 0;
    final index = _lastIndexOf(bytes, _startxrefBytes, from);
    if (index < 0) {
      return null;
    }
    final parser = PdfObjectParser(bytes, index + _startxrefBytes.length);
    return parser.tryReadInt();
  }

  // ---------------------------------------------------------------------
  // Repair
  // ---------------------------------------------------------------------

  static PdfCosDocument _openByRepair(Uint8List bytes, String version) {
    final entries = Map<int, PdfXrefEntry>.of(_scanObjects(bytes));
    final text = latin1.decode(bytes);

    // Newest trailer dictionary that names a catalog.
    PdfDict? trailer;
    for (final match in RegExp(
      r'trailer\s*<<',
    ).allMatches(text).toList().reversed) {
      try {
        final parser = PdfObjectParser(bytes, match.end - 2);
        final candidate = parser.parseObject();
        if (candidate is PdfDict && candidate['Root'] is PdfRef) {
          trailer = candidate;
          break;
        }
      } on PdfParseException {
        continue;
      }
    }

    final document = PdfCosDocument._(
      bytes: bytes,
      entries: entries,
      trailer: trailer ?? PdfDict(),
      lastXrefOffset: null,
      usesXrefStreams: false,
      wasRepaired: true,
      version: version,
    );

    // Index objects stored in object streams that the scan cannot see.
    for (final number in entries.keys.toList()) {
      final object = document.getObject(number);
      if (object is PdfStream && _isType(object.dict, 'ObjStm')) {
        final objectStream = document._readObjectStream(number);
        if (objectStream == null) {
          continue;
        }
        for (var i = 0; i < objectStream.numbers.length; i++) {
          entries.putIfAbsent(
            objectStream.numbers[i],
            () => PdfXrefEntry(PdfXrefEntryType.compressed, number, i),
          );
        }
      }
    }

    if (trailer == null) {
      // Use an xref stream's dictionary, or find the catalog directly.
      PdfDict? found;
      for (final number in entries.keys) {
        final object = document.getObject(number);
        if (object is PdfStream &&
            _isType(object.dict, 'XRef') &&
            object.dict['Root'] is PdfRef) {
          found = object.dict;
        }
      }
      if (found == null) {
        for (final number in entries.keys) {
          final object = document.getObject(number);
          if (object is PdfDict && _isType(object, 'Catalog')) {
            found = PdfDict(<String, PdfObject>{
              'Root': PdfRef(number, document.generationOf(number)),
            });
            break;
          }
        }
      }
      if (found != null) {
        document.trailer.entries.addAll(found.entries);
      }
    }
    document.trailer['Size'] = PdfNumber(document.size);
    return document;
  }

  static bool _isType(PdfDict dict, String type) {
    final value = dict['Type'];
    return value is PdfName && value.value == type;
  }

  static Map<int, PdfXrefEntry> _scanObjects(Uint8List bytes) {
    final text = latin1.decode(bytes);
    final entries = <int, PdfXrefEntry>{};
    final pattern = RegExp(r'(?<![0-9])(\d{1,10})\s+(\d{1,5})\s+obj\b');
    for (final match in pattern.allMatches(text)) {
      final number = int.parse(match.group(1)!);
      final generation = int.parse(match.group(2)!);
      // Later definitions (incremental updates) replace earlier ones.
      entries[number] = PdfXrefEntry(
        PdfXrefEntryType.inUse,
        match.start,
        generation,
      );
    }
    return entries;
  }

  static final Uint8List _headerBytes = Uint8List.fromList('%PDF-'.codeUnits);
  static final Uint8List _startxrefBytes = Uint8List.fromList(
    'startxref'.codeUnits,
  );

  static int _indexOf(Uint8List data, Uint8List pattern, int from, int limit) {
    final last = data.length - pattern.length;
    final end = limit < last ? limit : last;
    for (var i = from; i <= end; i++) {
      var matched = true;
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i;
      }
    }
    return -1;
  }

  static int _lastIndexOf(Uint8List data, Uint8List pattern, int from) {
    for (var i = data.length - pattern.length; i >= from; i--) {
      var matched = true;
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i;
      }
    }
    return -1;
  }
}

final class _XrefSection {
  const _XrefSection(this.trailer, {required this.isStream});

  final PdfDict trailer;
  final bool isStream;
}

final class _ObjectStream {
  const _ObjectStream(this.data, this.first, this.numbers, this.offsets);

  final Uint8List data;
  final int first;
  final List<int> numbers;
  final List<int> offsets;
}
