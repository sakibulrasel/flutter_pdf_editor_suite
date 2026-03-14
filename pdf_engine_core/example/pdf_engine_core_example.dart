import 'package:pdf_engine_core/pdf_engine_core.dart';

void main() {
  const source = PdfDocumentSource.file('/tmp/sample.pdf');
  const bounds = PdfRect(left: 24, top: 32, width: 180, height: 36);
  const field = PdfTextFormField(
    id: 'name',
    name: 'Name',
    pageIndex: 0,
    bounds: bounds,
    value: 'John Doe',
  );

  print('source type: ${source.type}');
  print('field: ${field.name}=${field.value}');
}
