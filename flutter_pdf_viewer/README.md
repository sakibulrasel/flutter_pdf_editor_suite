# flutter_pdf_editor_viewer

Flutter PDF viewer widgets for the `flutter_pdf_editor_suite`.

`flutter_pdf_editor_viewer` builds on `pdf_renderer_bridge` and provides a reusable
viewer layer with zooming, paging, page overlays, and PDF coordinate tap
handling.

## Features

- render and scroll PDF pages
- zoom in and out
- track current page
- build custom per-page overlay widgets
- handle taps in PDF coordinates

## Getting Started

Add the package:

```yaml
dependencies:
  flutter_pdf_editor_viewer: ^0.0.1
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_pdf_editor_viewer/flutter_pdf_editor_viewer.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

class SampleViewer extends StatelessWidget {
  const SampleViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return const PdfViewer(
      source: PdfDocumentSource.file('/tmp/sample.pdf'),
    );
  }
}
```

## Package Role

Use this package when you need PDF viewing without the higher-level editing
tooling in `flutter_pdf_editor`.
