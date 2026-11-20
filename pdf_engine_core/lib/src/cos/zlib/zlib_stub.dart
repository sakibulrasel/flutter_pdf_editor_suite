import 'dart:typed_data';

import '../../pdf_exceptions.dart';

/// Inflates zlib data. Not available on web yet (planned for Phase 14).
Uint8List zlibInflate(Uint8List data) =>
    throw PdfUnsupportedPlatformException('web');

/// Compresses data with zlib. Not available on web yet (planned for Phase 14).
Uint8List zlibDeflate(Uint8List data) =>
    throw PdfUnsupportedPlatformException('web');
