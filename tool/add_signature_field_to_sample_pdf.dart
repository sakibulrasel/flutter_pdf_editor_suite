import 'dart:convert';
import 'dart:io';

void main() async {
  final path =
      'pdf_renderer_bridge/example/assets/pdf/sample_fillable_fields.pdf';
  final file = File(path);
  final originalBytes = await file.readAsBytes();
  final originalText = latin1.decode(originalBytes);

  if (originalText.contains('/FT /Sig') ||
      originalText.contains('/T (signature_field)')) {
    stdout.writeln('Signature field already present. No changes made.');
    return;
  }

  final startXrefMatch = RegExp(
    r'startxref\s+(\d+)\s+%%EOF',
    multiLine: true,
  ).firstMatch(originalText);
  if (startXrefMatch == null) {
    stderr.writeln('Could not find startxref in sample PDF.');
    exitCode = 1;
    return;
  }
  final previousXrefOffset = int.parse(startXrefMatch.group(1)!);

  final page2Object = '''
82 1 obj
<<
/Annots [ 70 0 R 73 0 R 76 0 R 77 0 R 81 0 R 89 0 R ] /Contents 87 0 R /MediaBox [ 0 0 595.2756 841.8898 ] /Parent 85 0 R /Resources <<
/Font 1 0 R /ProcSet [ /PDF /Text /ImageB /ImageC /ImageI ]
>> /Rotate 0 
  /Trans <<
>> /Type /Page
>>
endobj
''';

  final acroFormObject = '''
88 1 obj
<<
/DA (/Helv 0 Tf 0 g) /DR << /Encoding
/RLAFencoding
4 0 R
/Font << /Helv 5 0 R >>
>> /Fields [ 7 0 R 10 0 R 13 0 R 16 0 R 19 0 R 22 0 R 25 0 R 32 0 R 36 0 R 40 0 R 
  44 0 R 45 0 R 57 0 R 60 0 R 63 0 R 66 0 R 70 0 R 73 0 R 76 0 R 77 0 R 
  81 0 R 89 0 R ]
>>
endobj
''';

  final signatureObject = '''
89 0 obj
<<
/BS <<
/S /S /W 1
>> /F 4 /FT /Sig /MK <<
/BC [ .392157 .454902 .545098 ] /BG [ 1 1 1 ]
>> /P 82 0 R /Rect [ 311.811 300 552.7559 340 ] /Subtype /Widget
  /T (signature_field) /TU (Signature field) /Type /Annot
>>
endobj
''';

  final append = StringBuffer();
  append.write('\n');

  final offset82 = originalBytes.length + append.length;
  append.write(page2Object);

  final offset88 = originalBytes.length + append.length;
  append.write(acroFormObject);

  final offset89 = originalBytes.length + append.length;
  append.write(signatureObject);

  final xrefOffset = originalBytes.length + append.length;
  append.write('xref\n');
  append.write('82 1\n');
  append.write('${offset82.toString().padLeft(10, '0')} 00001 n \n');
  append.write('88 2\n');
  append.write('${offset88.toString().padLeft(10, '0')} 00001 n \n');
  append.write('${offset89.toString().padLeft(10, '0')} 00000 n \n');
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

  stdout.writeln('Added signature field to $path');
}
