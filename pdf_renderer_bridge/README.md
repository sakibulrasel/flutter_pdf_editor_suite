# pdf_renderer_bridge

Flutter bridge package for PDF document access and page rendering.

`pdf_renderer_bridge` is the low-level rendering layer in the
`flutter_pdf_editor_suite` stack. It opens PDF documents, reads page metadata,
and renders pages to raster image bytes for higher-level packages.

## Features

- open a PDF from bytes or file path
- read document and page metadata
- render PDF pages to PNG bytes
- close documents explicitly

## Getting Started

Add the package:

```yaml
dependencies:
  pdf_renderer_bridge: ^0.0.1
```

## Usage

```dart
import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge.dart';

final bridge = PdfRendererBridge();
final document = await bridge.openDocument(
  PdfDocumentSource.file('/tmp/sample.pdf'),
);

final page = await bridge.renderPage(
  PdfRenderRequest(documentId: document.documentId, pageIndex: 0, scale: 2),
);

await bridge.closeDocument(document.documentId);
```

## Package Role

Use this package directly when you want low-level rendering access.

For higher-level UI layers, see:

- `flutter_pdf_viewer`
- `flutter_pdf_editor`
