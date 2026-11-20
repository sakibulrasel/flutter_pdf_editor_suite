# Phase 9 - PDF Object Model

Goal: a pure-Dart reader and writer that can open any normal PDF, including
compressed ones, and save changes safely.

Code: `pdf_engine_core/lib/src/cos/`, public entry point
`package:pdf_engine_core/cos.dart`.

## Reading

- [x] Byte-level parser on `Uint8List`: numbers, names (`#xx`), literal and hex strings, arrays, dictionaries, references, comments
- [x] Object types: `PdfNull`, `PdfBool`, `PdfNumber`, `PdfName`, `PdfString`, `PdfArray`, `PdfDict`, `PdfRef`, `PdfStream`
- [x] PDF text strings: PDFDocEncoding, UTF-16BE and UTF-8 byte order marks
- [x] Streams with direct or indirect `/Length`, and recovery when `/Length` is wrong
- [x] Classic xref tables, xref streams (`/Type /XRef`), hybrid files (`/XRefStm`), `/Prev` chains
- [x] Compressed object streams (`/ObjStm`)
- [x] Filters: Flate (with PNG and TIFF predictors), LZW, ASCIIHex, ASCII85, RunLength
- [x] Lazy object loading with a cache
- [x] Repair: rebuild the xref by scanning for `N G obj` when it is broken; per-object fallback for wrong offsets
- [x] Page tree walker with inherited `MediaBox`, `CropBox`, `Rotate`, `Resources`
- [x] Encrypted files rejected with `PdfUnsupportedFeatureException` (decryption is Phase 15)

## Writing

- [x] Object serializer (escaped names and strings, numbers without exponents)
- [x] Incremental update: keeps generation numbers, chains `/Prev`, writes a classic table or an xref stream to match the original
- [x] Full rewrite of reachable objects with a classic xref and a linked free list
- [x] Repaired files are saved as a full rewrite

## Integration

- [x] `PdfAcroFormParser` runs on the object model
- [x] `PdfEditableExporter` runs on the incremental writer
- [x] Fixed the generation-number bug in editable save
- [x] Removed the regex-based object index from both

## Verification

- [x] Every fixture: open, check page count against qpdf, incremental update, full rewrite, reopen
- [x] Xref-stream decoding cross-checked against `qpdf --show-xref` (Python port of the same algorithm)
- [x] LZW checked against the worked example in PDF 32000-1, 7.4.4.2; ASCII85 and RunLength against reference encoders
- [ ] `tool/ci.sh` green on a machine with Flutter (this phase was written without a local Dart SDK)
- [ ] Open saved files in Acrobat, Chrome and Preview
- [ ] Real-world PDFs from `fixtures/real_world/`

## Not in This Phase

- Decrypting encrypted files (Phase 15)
- Writing compressed object streams (full rewrite writes uncompressed objects)
- Flate on web (Phase 14)
