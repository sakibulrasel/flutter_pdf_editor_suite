# pdf_engine_core

Shared core models for the `flutter_pdf_editor_suite` packages.

This package contains the pure Dart data layer used across the suite:

- PDF document and page metadata
- document sources
- render requests and rendered page results
- page viewport math
- overlay models such as text, signatures, rectangles, and images
- form field models such as text, checkbox, radio, combo box, list box, and signature fields

## Use Cases

Use `pdf_engine_core` if you want:

- a lightweight shared dependency for PDF editor/viewer data types
- to build your own renderer or viewer on top of the same models
- to consume form and overlay state without depending on Flutter widgets

## Getting Started

Add the package:

```yaml
dependencies:
  pdf_engine_core: ^1.0.0
```

## Usage

```dart
import 'package:pdf_engine_core/pdf_engine_core.dart';

const source = PdfDocumentSource.file('/tmp/sample.pdf');

const overlay = PdfTextOverlay(
  id: 'text_1',
  pageIndex: 0,
  bounds: PdfRect(left: 24, top: 48, width: 120, height: 28),
  text: 'Hello PDF',
);
```

## Low-level PDF object model

`package:pdf_engine_core/cos.dart` is a pure-Dart reader and writer for the
objects inside a PDF file:

```dart
import 'package:pdf_engine_core/cos.dart';

final document = PdfCosDocument.open(bytes);
print('${document.pages.length} pages, PDF ${document.version}');

// Change the catalog and save it as an incremental update.
final rootRef = document.trailer['Root']! as PdfRef;
final catalog = document.catalog.copy()
  ..['PageMode'] = const PdfName('UseOutlines');
final saved = (PdfIncrementalUpdate(document)..set(rootRef.number, catalog))
    .build();
```

It reads classic and compressed (PDF 1.5+) files, incremental updates and
damaged files, and saves either as an incremental update or a full rewrite.
Encrypted files are not supported yet.

## Package Scope

This package does not render PDFs or provide editing UI. It provides the shared
types used by:

- `pdf_renderer_bridge`
- `flutter_pdf_viewer`
- `flutter_pdf_editor`
