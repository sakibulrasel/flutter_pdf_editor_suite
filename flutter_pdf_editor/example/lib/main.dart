import 'package:flutter/material.dart';
import 'package:flutter_pdf_editor/flutter_pdf_editor.dart';

void main() {
  runApp(const _ExampleApp());
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: PdfEditorScreen(
        config: PdfEditorConfig(
          title: 'flutter_pdf_editor example',
          initialZoom: 1,
          maxZoom: 6,
        ),
      ),
    );
  }
}
