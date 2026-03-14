# flutter_pdf_editor

Flutter PDF editing toolkit built on top of `flutter_pdf_editor_viewer` and
`pdf_renderer_bridge`.

`flutter_pdf_editor` provides higher-level PDF editing workflows including:

- overlay editing
- AcroForm field editing
- flattened export
- classic editable AcroForm save
- blank-PDF creation and Phase 7 authoring tools

## Features

- add and edit text, checkmark, signature, rectangle, and image overlays
- parse and edit common AcroForm field types
- export flattened PDFs
- save editable classic AcroForm PDFs
- create blank PDFs for new authoring flows

## Getting Started

Add the package:

```yaml
dependencies:
  flutter_pdf_editor: ^0.0.1
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_pdf_editor/flutter_pdf_editor.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

class SampleEditor extends StatefulWidget {
  const SampleEditor({super.key});

  @override
  State<SampleEditor> createState() => _SampleEditorState();
}

class _SampleEditorState extends State<SampleEditor> {
  final controller = PdfOverlayEditorController();

  @override
  Widget build(BuildContext context) {
    return PdfOverlayEditor(
      source: const PdfDocumentSource.file('/tmp/sample.pdf'),
      controller: controller,
    );
  }
}
```

## Package Role

Use this package when you want editing and export workflows, not just viewing.

For lower-level layers, see:

- `pdf_engine_core`
- `pdf_renderer_bridge`
- `flutter_pdf_editor_viewer`
