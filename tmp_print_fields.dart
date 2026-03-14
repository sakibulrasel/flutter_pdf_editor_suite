import 'dart:io';

import 'flutter_pdf_editor/lib/src/pdf_acroform_parser.dart';

Future<void> main() async {
  final bytes = await File(
    'pdf_renderer_bridge/example/assets/pdf/sample_fillable_fields.pdf',
  ).readAsBytes();
  final fields = PdfAcroFormParser().parseBytes(bytes);
  for (final field in fields) {
    print(
      '${field.runtimeType} name=${field.name} page=${field.pageIndex} '
      'bounds=${field.bounds.left},${field.bounds.top},'
      '${field.bounds.width},${field.bounds.height}',
    );
  }
}
