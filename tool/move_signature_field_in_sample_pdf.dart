import 'dart:convert';
import 'dart:io';

void main() async {
  final path =
      'pdf_renderer_bridge/example/assets/pdf/sample_fillable_fields.pdf';
  final file = File(path);
  final originalBytes = await file.readAsBytes();
  final originalText = latin1.decode(originalBytes);

  if (!originalText.contains('/T (signature_field)')) {
    stderr.writeln('Signature field not found in sample PDF.');
    exitCode = 1;
    return;
  }

  final startXrefMatch = RegExp(
    r'startxref\s+(\d+)\s+%%EOF',
    multiLine: true,
  ).allMatches(originalText).lastOrNull;
  if (startXrefMatch == null) {
    stderr.writeln('Could not find startxref in sample PDF.');
    exitCode = 1;
    return;
  }
  final previousXrefOffset = int.parse(startXrefMatch.group(1)!);

  final movedSignatureObject = '''
89 1 obj
<<
/BS <<
/S /S /W 1
>> /F 4 /FT /Sig /MK <<
/BC [ .392157 .454902 .545098 ] /BG [ 1 1 1 ]
>> /P 82 0 R /Rect [ 311.811 220 552.7559 260 ] /Subtype /Widget
  /T (signature_field) /TU (Signature field) /Type /Annot
>>
endobj
''';

  final append = StringBuffer()..write('\n');
  final offset89 = originalBytes.length + append.length;
  append.write(movedSignatureObject);
  final xrefOffset = originalBytes.length + append.length;
  append.write('xref\n');
  append.write('89 1\n');
  append.write('${offset89.toString().padLeft(10, '0')} 00001 n \n');
  append.write('trailer\n');
  append.write(
    '<< /Size 90 /Root 83 0 R /Info 84 0 R /Prev $previousXrefOffset >>\n',
  );
  append.write('startxref\n');
  append.write('$xrefOffset\n');
  append.write('%%EOF\n');

  await file.writeAsBytes(
    <int>[...originalBytes, ...latin1.encode(append.toString())],
    flush: true,
  );

  stdout.writeln('Moved signature field in $path');
}
