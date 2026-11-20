// Prints every AcroForm field the parser finds in a PDF.
//
// Usage, from the flutter_pdf_editor folder:
//   dart run tool/print_form_fields.dart [path/to/file.pdf]
//
// Defaults to the sample fillable PDF bundled with the bridge example.
import 'dart:io';

import 'package:flutter_pdf_editor/src/pdf_acroform_parser.dart';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args.first
      : '../pdf_renderer_bridge/example/assets/pdf/sample_fillable_fields.pdf';
  final bytes = await File(path).readAsBytes();
  final fields = PdfAcroFormParser().parseBytes(bytes);
  if (fields.isEmpty) {
    stdout.writeln('No AcroForm fields found in $path');
    return;
  }
  for (final field in fields) {
    stdout.writeln(
      '${field.runtimeType} name=${field.name} page=${field.pageIndex} '
      'bounds=${field.bounds.left},${field.bounds.top},'
      '${field.bounds.width},${field.bounds.height}',
    );
  }
}
