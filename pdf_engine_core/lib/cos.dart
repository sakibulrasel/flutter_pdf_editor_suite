/// Low-level PDF object model ("COS"): parse any PDF into objects, read
/// pages, decode streams, and save changes as an incremental update or a
/// full rewrite.
///
/// ```dart
/// import 'package:pdf_engine_core/cos.dart';
///
/// final document = PdfCosDocument.open(bytes);
/// print('${document.pages.length} pages, PDF ${document.version}');
///
/// // Open the bookmarks panel by default, saved as an incremental update.
/// final rootRef = document.trailer['Root']! as PdfRef;
/// final catalog = document.catalog.copy()
///   ..['PageMode'] = const PdfName('UseOutlines');
/// final newBytes = (PdfIncrementalUpdate(document)
///       ..set(rootRef.number, catalog))
///     .build();
/// ```
///
/// Supports classic cross-reference tables, cross-reference streams, hybrid
/// files, incremental updates, compressed object streams, and the Flate,
/// LZW, ASCIIHex, ASCII85 and RunLength filters with PNG/TIFF predictors.
/// Broken cross-reference data is repaired by scanning. Encrypted files are
/// rejected with a `PdfUnsupportedFeatureException`.
library;

export 'src/cos/pdf_cos_document.dart';
export 'src/cos/pdf_filters.dart'
    show
        PdfResolver,
        applyFilter,
        applyPredictor,
        ascii85Decode,
        asciiHexDecode,
        decodeStreamData,
        lzwDecode,
        runLengthDecode;
export 'src/cos/pdf_objects.dart';
export 'src/cos/pdf_parser.dart';
export 'src/cos/pdf_writer.dart';
