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