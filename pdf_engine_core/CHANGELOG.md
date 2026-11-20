## 1.2.0

- Added a pure-Dart PDF object model in `package:pdf_engine_core/cos.dart`:
  - `PdfObject` types (`PdfDict`, `PdfArray`, `PdfName`, `PdfString`, `PdfNumber`, `PdfRef`, `PdfStream`, ...) with PDF text-string encoding (PDFDocEncoding and UTF-16BE).
  - `PdfObjectParser`: a byte-level parser for objects, indirect objects and streams, tolerant of wrong `/Length` values.
  - `PdfCosDocument`: reads classic cross-reference tables, cross-reference streams, hybrid files, incremental updates (`/Prev` chains) and compressed object streams; repairs files with broken cross-reference data by scanning; walks the page tree with inherited `MediaBox`, `CropBox`, `Rotate` and `Resources`; rejects encrypted files with `PdfUnsupportedFeatureException`.
  - Stream filters: Flate, LZW, ASCIIHex, ASCII85 and RunLength, with PNG and TIFF predictors. Image filters report `PdfUnsupportedFeature.streamFilter`.
  - `PdfIncrementalUpdate`: appends changed and new objects, keeping generation numbers and writing a classic table or a cross-reference stream to match the original.
  - `PdfDocumentRewriter`: writes a clean full copy of every reachable object.
- Added `PdfUnsupportedFeature.streamFilter`.
- Flate decoding uses `dart:io` zlib; on web it throws `PdfUnsupportedPlatformException` until web support lands.

## 1.1.0

- Added a typed exception hierarchy: `PdfException` and `PdfInvalidDocumentException`, `PdfFileNotFoundException`, `PdfPasswordRequiredException`, `PdfUnsupportedFeatureException` (with `PdfUnsupportedFeature`), `PdfUnsupportedPlatformException` and `PdfRenderException`.
- Added `PdfPreflight.inspect`, a fast byte scan that reports encryption, compressed object streams, cross-reference streams, XFA and revision count, with `ensureReadable` and `ensureIncrementallyWritable` guards.
- Tests now run every file in the shared `fixtures/pdf` corpus.

## 1.0.2

- Added missing CHANGELOG entry for the latest published version.
- Expanded dartdoc coverage across the public core API.
- Replaced the placeholder package example with a working example.

## 1.0.1

- Added public API documentation improvements.

## 1.0.0

- Initial public release of the core PDF models package.