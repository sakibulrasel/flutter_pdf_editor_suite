import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

import 'package:flutter_pdf_editor/flutter_pdf_editor.dart';

void main() {
  late Uint8List validPngBytes;
  late Uint8List unicodeFontBytes;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    validPngBytes = await _createValidPngBytes();
    unicodeFontBytes = await File(
      'assets/fonts/Arial Unicode.ttf',
    ).readAsBytes();
  });

  test(
    'overlay editor controller adds, moves, resizes, and deletes overlays',
    () {
      final controller = PdfOverlayEditorController();
      const pageInfo = PdfPageInfo(
        documentId: 1,
        pageIndex: 0,
        width: 300,
        height: 200,
      );
      final signatureBytes = Uint8List.fromList(<int>[1, 2, 3]);

      controller.setActiveTool(PdfOverlayTool.text);
      final textOverlay = controller.addOverlayForTap(
        pageIndex: 0,
        pdfPosition: const PdfPoint(x: 50, y: 60),
      );

      expect(textOverlay, isA<PdfTextOverlay>());
      expect(controller.selectedOverlayId, textOverlay!.id);

      controller.updateSelectedText('Hello');
      controller.updateSelectedFontSize(20);
      expect((controller.selectedOverlay as PdfTextOverlay).text, 'Hello');
      expect((controller.selectedOverlay as PdfTextOverlay).fontSize, 20);

      controller.moveOverlay(
        overlayId: textOverlay.id,
        deltaX: 220,
        deltaY: 160,
        pageInfo: pageInfo,
      );

      expect(
        (controller.selectedOverlay as PdfTextOverlay).bounds.left,
        lessThanOrEqualTo(212),
      );
      expect(
        (controller.selectedOverlay as PdfTextOverlay).bounds.top,
        lessThanOrEqualTo(172),
      );

      controller.resizeOverlay(
        overlayId: textOverlay.id,
        deltaWidth: 100,
        deltaHeight: 100,
        pageInfo: pageInfo,
      );

      expect(
        (controller.selectedOverlay as PdfTextOverlay).bounds.width,
        greaterThanOrEqualTo(48),
      );
      expect(
        (controller.selectedOverlay as PdfTextOverlay).bounds.height,
        greaterThanOrEqualTo(20),
      );

      controller.setActiveTool(PdfOverlayTool.checkmark);
      final checkmarkOverlay = controller.addOverlayForTap(
        pageIndex: 0,
        pdfPosition: const PdfPoint(x: 20, y: 30),
      );
      expect(checkmarkOverlay, isA<PdfCheckmarkOverlay>());

      controller.selectOverlay(checkmarkOverlay!.id);
      controller.updateSelectedColor(0xFFDC2626);
      expect(
        (controller.selectedOverlay as PdfCheckmarkOverlay).color,
        0xFFDC2626,
      );

      controller.setActiveTool(PdfOverlayTool.signature);
      final signatureOverlay = controller.addOverlayForTap(
        pageIndex: 0,
        pdfPosition: const PdfPoint(x: 10, y: 10),
        signaturePngBytes: signatureBytes,
      );
      expect(signatureOverlay, isA<PdfSignatureOverlay>());

      controller.selectOverlay(signatureOverlay!.id);
      controller.resizeOverlay(
        overlayId: signatureOverlay.id,
        deltaWidth: -500,
        deltaHeight: -500,
        pageInfo: pageInfo,
      );
      expect(
        (controller.selectedOverlay as PdfSignatureOverlay).bounds.width,
        greaterThanOrEqualTo(48),
      );
      expect(
        (controller.selectedOverlay as PdfSignatureOverlay).bounds.height,
        greaterThanOrEqualTo(24),
      );

      controller.setActiveTool(PdfOverlayTool.rectangle);
      final rectangleOverlay = controller.addOverlayForTap(
        pageIndex: 0,
        pdfPosition: const PdfPoint(x: 15, y: 15),
      );
      expect(rectangleOverlay, isA<PdfRectangleOverlay>());
      controller.selectOverlay(rectangleOverlay!.id);
      controller.updateSelectedColor(0xFF1D4ED8);
      expect(
        (controller.selectedOverlay as PdfRectangleOverlay).color,
        0xFF1D4ED8,
      );

      controller.setActiveTool(PdfOverlayTool.image);
      final imageOverlay = controller.addOverlayForTap(
        pageIndex: 0,
        pdfPosition: const PdfPoint(x: 25, y: 25),
        imageBytes: validPngBytes,
      );
      expect(imageOverlay, isA<PdfImageOverlay>());

      controller.deleteSelected();
      expect(
        controller.overlays.where((item) => item.id == imageOverlay!.id),
        isEmpty,
      );
    },
  );

  test('overlay editor controller serializes and restores state', () {
    final controller = PdfOverlayEditorController();
    final signatureBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    controller.setActiveTool(PdfOverlayTool.text);
    controller.addTextOverlay(
      pageIndex: 0,
      pdfPosition: const PdfPoint(x: 10, y: 20),
      text: 'Hello',
    );
    controller.setActiveTool(PdfOverlayTool.signature);
    controller.addSignatureOverlay(
      pageIndex: 1,
      pdfPosition: const PdfPoint(x: 30, y: 40),
      pngBytes: signatureBytes,
    );
    controller.setActiveTool(PdfOverlayTool.rectangle);
    controller.addRectangleOverlay(
      pageIndex: 0,
      pdfPosition: const PdfPoint(x: 50, y: 60),
    );
    controller.setActiveTool(PdfOverlayTool.image);
    controller.addImageOverlay(
      pageIndex: 1,
      pdfPosition: const PdfPoint(x: 70, y: 80),
      imageBytes: validPngBytes,
    );

    final json = controller.serializeStateJson();

    final restored = PdfOverlayEditorController();
    restored.restoreStateJson(json);

    expect(restored.overlays, hasLength(4));
    expect(restored.activeTool, PdfOverlayTool.image);
    expect(restored.overlays.first, isA<PdfTextOverlay>());
    expect(restored.overlays[1], isA<PdfSignatureOverlay>());
    expect(restored.overlays[2], isA<PdfRectangleOverlay>());
    expect(restored.overlays.last, isA<PdfImageOverlay>());
    expect(
      (restored.overlays[1] as PdfSignatureOverlay).pngBytes,
      signatureBytes,
    );
  });

  test('overlay editor controller supports undo and redo', () {
    final controller = PdfOverlayEditorController();
    const pageInfo = PdfPageInfo(
      documentId: 1,
      pageIndex: 0,
      width: 300,
      height: 200,
    );

    final overlay = controller.addTextOverlay(
      pageIndex: 0,
      pdfPosition: const PdfPoint(x: 10, y: 10),
    );

    controller.beginInteraction();
    controller.moveOverlay(
      overlayId: overlay.id,
      deltaX: 20,
      deltaY: 30,
      pageInfo: pageInfo,
    );
    controller.endInteraction();

    expect((controller.selectedOverlay as PdfTextOverlay).bounds.left, 30);
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect((controller.selectedOverlay as PdfTextOverlay).bounds.left, 10);
    expect(controller.canRedo, isTrue);

    controller.redo();
    expect((controller.selectedOverlay as PdfTextOverlay).bounds.left, 30);
  });

  test(
    'AcroForm parser detects text fields, checkboxes, radios, combo boxes, list boxes, and signature fields',
    () {
      final parser = PdfAcroFormParser();
      final fields = parser.parseBytes(_buildSampleFormPdf());

      expect(fields, hasLength(8));
      expect(fields.first, isA<PdfTextFormField>());
      expect(fields[1], isA<PdfCheckboxFormField>());
      expect(fields[2], isA<PdfRadioFormField>());
      expect(fields[3], isA<PdfRadioFormField>());
      expect(fields[4], isA<PdfComboBoxFormField>());
      expect(fields[5], isA<PdfListBoxFormField>());
      expect(fields[6], isA<PdfListBoxFormField>());
      expect(fields[7], isA<PdfSignatureFormField>());
      expect((fields.first as PdfTextFormField).name, 'name');
      expect((fields.first as PdfTextFormField).value, 'Sakib');
      expect((fields[1] as PdfCheckboxFormField).name, 'accept_terms');
      expect((fields[1] as PdfCheckboxFormField).isChecked, isFalse);
      expect(
        (fields[1] as PdfCheckboxFormField).markStyle,
        PdfCheckboxMarkStyle.check,
      );
      expect((fields[2] as PdfRadioFormField).groupName, 'contact_method');
      expect((fields[2] as PdfRadioFormField).isSelected, isTrue);
      expect((fields[3] as PdfRadioFormField).isSelected, isFalse);
      expect((fields[4] as PdfComboBoxFormField).name, 'country');
      expect((fields[4] as PdfComboBoxFormField).selectedValue, 'sa');
      expect((fields[4] as PdfComboBoxFormField).selectedLabel, 'Saudi Arabia');
      expect((fields[5] as PdfListBoxFormField).name, 'skills');
      expect((fields[5] as PdfListBoxFormField).selectedValues, <String>[
        'flutter',
      ]);
      expect((fields[5] as PdfListBoxFormField).isMultiSelect, isFalse);
      expect((fields[6] as PdfListBoxFormField).name, 'focus_areas');
      expect((fields[6] as PdfListBoxFormField).selectedValues, <String>[
        'pdf',
        'forms',
      ]);
      expect((fields[6] as PdfListBoxFormField).isMultiSelect, isTrue);
      expect((fields[7] as PdfSignatureFormField).name, 'signature');
    },
  );

  test('AcroForm parser reads checkbox mark styles from MK/CA', () async {
    final parser = PdfAcroFormParser();
    final bytes = await File(
      '/Users/sakibulhaque/Desktop/Project/dart_package/pdf_editor/pdf_renderer_bridge/example/assets/pdf/sample_fillable_fields.pdf',
    ).readAsBytes();
    final fields = parser.parseBytes(bytes);

    PdfCheckboxFormField checkboxByName(String name) => fields
        .whereType<PdfCheckboxFormField>()
        .firstWhere((field) => field.name == name);

    expect(checkboxByName('check_box').markStyle, PdfCheckboxMarkStyle.check);
    expect(checkboxByName('cross_box').markStyle, PdfCheckboxMarkStyle.cross);
    expect(checkboxByName('circle_box').markStyle, PdfCheckboxMarkStyle.circle);
    expect(checkboxByName('star_box').markStyle, PdfCheckboxMarkStyle.star);
  });

  test(
    'form editor controller updates text fields, checkboxes, radios, combo boxes, list boxes, and signature fields',
    () {
      final controller = PdfFormEditorController();
      controller.setFields(<PdfFormField>[
        const PdfTextFormField(
          id: 'field_1',
          name: 'name',
          pageIndex: 0,
          bounds: PdfRect(left: 10, top: 10, width: 100, height: 20),
          value: 'Initial',
        ),
        const PdfCheckboxFormField(
          id: 'field_2',
          name: 'accept_terms',
          pageIndex: 0,
          bounds: PdfRect(left: 10, top: 40, width: 20, height: 20),
          isChecked: false,
          markStyle: PdfCheckboxMarkStyle.cross,
        ),
        const PdfRadioFormField(
          id: 'field_3',
          name: 'contact_method',
          groupName: 'contact_method',
          optionValue: 'email',
          pageIndex: 0,
          bounds: PdfRect(left: 10, top: 70, width: 20, height: 20),
          isSelected: true,
        ),
        const PdfRadioFormField(
          id: 'field_4',
          name: 'contact_method',
          groupName: 'contact_method',
          optionValue: 'phone',
          pageIndex: 0,
          bounds: PdfRect(left: 40, top: 70, width: 20, height: 20),
          isSelected: false,
        ),
        const PdfComboBoxFormField(
          id: 'field_5',
          name: 'country',
          pageIndex: 0,
          bounds: PdfRect(left: 10, top: 100, width: 90, height: 24),
          selectedValue: 'sa',
          options: <PdfChoiceOption>[
            PdfChoiceOption(value: 'sa', label: 'Saudi Arabia'),
            PdfChoiceOption(value: 'bd', label: 'Bangladesh'),
          ],
        ),
        const PdfListBoxFormField(
          id: 'field_6',
          name: 'skills',
          pageIndex: 0,
          bounds: PdfRect(left: 10, top: 130, width: 90, height: 56),
          selectedValues: <String>['flutter'],
          options: <PdfChoiceOption>[
            PdfChoiceOption(value: 'flutter', label: 'Flutter'),
            PdfChoiceOption(value: 'dart', label: 'Dart'),
            PdfChoiceOption(value: 'pdf', label: 'PDF'),
          ],
        ),
        const PdfListBoxFormField(
          id: 'field_7',
          name: 'focus_areas',
          pageIndex: 0,
          bounds: PdfRect(left: 120, top: 130, width: 90, height: 56),
          selectedValues: <String>['pdf'],
          isMultiSelect: true,
          options: <PdfChoiceOption>[
            PdfChoiceOption(value: 'pdf', label: 'PDF'),
            PdfChoiceOption(value: 'forms', label: 'Forms'),
            PdfChoiceOption(value: 'ocr', label: 'OCR'),
          ],
        ),
        const PdfSignatureFormField(
          id: 'field_8',
          name: 'signature',
          pageIndex: 0,
          bounds: PdfRect(left: 10, top: 200, width: 120, height: 40),
        ),
      ]);

      controller.updateTextField('field_1', 'Updated');
      controller.toggleCheckbox('field_2');
      controller.selectRadio('field_4');
      controller.selectComboBoxValue('field_5', 'bd');
      controller.selectListBoxValues('field_6', const <String>['dart']);
      controller.selectListBoxValues('field_7', const <String>['pdf', 'forms']);
      controller.updateSignatureField(
        'field_8',
        Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect((controller.fields.first as PdfTextFormField).value, 'Updated');
      expect((controller.fields[1] as PdfCheckboxFormField).isChecked, isTrue);
      expect((controller.fields[2] as PdfRadioFormField).isSelected, isFalse);
      expect((controller.fields[3] as PdfRadioFormField).isSelected, isTrue);
      expect(
        (controller.fields[4] as PdfComboBoxFormField).selectedValue,
        'bd',
      );
      expect(
        (controller.fields[5] as PdfListBoxFormField).selectedValues,
        <String>['dart'],
      );
      expect(
        (controller.fields[6] as PdfListBoxFormField).selectedValues,
        <String>['pdf', 'forms'],
      );
      expect(
        (controller.fields[7] as PdfSignatureFormField).pngBytes,
        Uint8List.fromList(<int>[1, 2, 3]),
      );
    },
  );

  test('overlay exporter creates a multi-page flattened PDF', () async {
    final renderer = _FakeExportRenderer(
      pageCount: 2,
      renderedPagePngBytes: validPngBytes,
    );
    final exporter = PdfOverlayExporter(renderer: renderer);
    final output = await exporter.exportToBytes(
      source: PdfDocumentSource.bytes(Uint8List(0)),
      overlays: <PdfOverlayItem>[
        PdfTextOverlay(
          id: 'text-1',
          pageIndex: 0,
          bounds: const PdfRect(left: 20, top: 20, width: 80, height: 24),
          text: 'Hello',
        ),
        PdfSignatureOverlay(
          id: 'sig-1',
          pageIndex: 1,
          bounds: const PdfRect(left: 30, top: 30, width: 90, height: 30),
          pngBytes: validPngBytes,
        ),
        PdfRectangleOverlay(
          id: 'rect-1',
          pageIndex: 0,
          bounds: const PdfRect(left: 120, top: 40, width: 60, height: 36),
          color: 0xFF2563EB,
        ),
        PdfImageOverlay(
          id: 'img-1',
          pageIndex: 1,
          bounds: const PdfRect(left: 50, top: 70, width: 80, height: 60),
          imageBytes: validPngBytes,
        ),
      ],
    );

    expect(output, isNotEmpty);
    expect(ascii.decode(output.take(5).toList()), '%PDF-');
    expect(renderer.renderedPages, <int>[0, 1]);
    expect(renderer.closedDocumentIds, <int>[7]);
  });

  test(
    'editable exporter writes updated field values into classic AcroForm PDFs',
    () async {
      final exporter = PdfEditableExporter();
      final output = await exporter.exportToBytes(
        source: PdfDocumentSource.bytes(_buildSampleFormPdf()),
        formFields: <PdfFormField>[
          const PdfTextFormField(
            id: 'form_5',
            name: 'name',
            pageIndex: 0,
            bounds: PdfRect(left: 90, top: 62, width: 150, height: 28),
            value: 'Updated Name',
          ),
          const PdfCheckboxFormField(
            id: 'form_6',
            name: 'accept_terms',
            pageIndex: 0,
            bounds: PdfRect(left: 130, top: 130, width: 20, height: 20),
            isChecked: true,
            onValue: 'Yes',
          ),
          const PdfRadioFormField(
            id: 'form_7',
            name: 'contact_method',
            groupName: 'contact_method',
            optionValue: 'email',
            pageIndex: 0,
            bounds: PdfRect(left: 120, top: 165, width: 20, height: 20),
            isSelected: false,
          ),
          const PdfRadioFormField(
            id: 'form_8',
            name: 'contact_method',
            groupName: 'contact_method',
            optionValue: 'phone',
            pageIndex: 0,
            bounds: PdfRect(left: 180, top: 165, width: 20, height: 20),
            isSelected: true,
          ),
          const PdfComboBoxFormField(
            id: 'form_10',
            name: 'country',
            pageIndex: 0,
            bounds: PdfRect(left: 90, top: 202, width: 150, height: 28),
            selectedValue: 'bd',
            options: <PdfChoiceOption>[
              PdfChoiceOption(value: 'sa', label: 'Saudi Arabia'),
              PdfChoiceOption(value: 'bd', label: 'Bangladesh'),
            ],
          ),
          const PdfListBoxFormField(
            id: 'form_11',
            name: 'skills',
            pageIndex: 0,
            bounds: PdfRect(left: 90, top: 214, width: 150, height: 56),
            selectedValues: <String>['dart'],
            options: <PdfChoiceOption>[
              PdfChoiceOption(value: 'flutter', label: 'Flutter'),
              PdfChoiceOption(value: 'dart', label: 'Dart'),
            ],
          ),
          const PdfListBoxFormField(
            id: 'form_12',
            name: 'focus_areas',
            pageIndex: 0,
            bounds: PdfRect(left: 90, top: 250, width: 150, height: 70),
            selectedValues: <String>['pdf', 'forms'],
            isMultiSelect: true,
            options: <PdfChoiceOption>[
              PdfChoiceOption(value: 'pdf', label: 'PDF'),
              PdfChoiceOption(value: 'forms', label: 'Forms'),
            ],
          ),
        ],
      );

      final reparsed = PdfAcroFormParser().parseBytes(output);
      expect((reparsed.first as PdfTextFormField).value, 'Updated Name');
      expect((reparsed[1] as PdfCheckboxFormField).isChecked, isTrue);
      expect((reparsed[2] as PdfRadioFormField).isSelected, isFalse);
      expect((reparsed[3] as PdfRadioFormField).isSelected, isTrue);
      expect((reparsed[4] as PdfComboBoxFormField).selectedValue, 'bd');
      expect((reparsed[5] as PdfListBoxFormField).selectedValues, <String>[
        'dart',
      ]);
      expect((reparsed[6] as PdfListBoxFormField).selectedValues, <String>[
        'pdf',
        'forms',
      ]);
    },
  );

  test('document creator creates a blank multi-page PDF', () async {
    final creator = PdfDocumentCreator();
    final output = await creator.createBlankPdf(
      options: const PdfCreateOptions(pageCount: 2),
    );
    final pdfText = latin1.decode(output, allowInvalid: true);

    expect(output, isNotEmpty);
    expect(ascii.decode(output.take(5).toList()), '%PDF-');
    expect(RegExp(r'/Count\s+2\b').hasMatch(pdfText), isTrue);
  });

  test(
    'document creator supports page presets and landscape orientation',
    () async {
      final creator = PdfDocumentCreator();
      final portrait = await creator.createBlankPdf(
        options: const PdfCreateOptions(
          pagePreset: PdfCreatePagePreset.a4,
          orientation: PdfCreateOrientation.portrait,
        ),
      );
      final landscape = await creator.createBlankPdf(
        options: const PdfCreateOptions(
          pagePreset: PdfCreatePagePreset.letter,
          orientation: PdfCreateOrientation.landscape,
        ),
      );
      final portraitText = latin1.decode(portrait, allowInvalid: true);
      final landscapeText = latin1.decode(landscape, allowInvalid: true);

      expect(portrait, isNotEmpty);
      expect(landscape, isNotEmpty);
      expect(landscapeText, isNot(equals(portraitText)));
      expect(landscapeText.contains('/MediaBox'), isTrue);
    },
  );

  test('overlay exporter validates the exported PDF by reopening it', () async {
    final renderer = _FakeExportRenderer(
      pageCount: 2,
      renderedPagePngBytes: validPngBytes,
      validatedPageCount: 2,
    );
    final exporter = PdfOverlayExporter(renderer: renderer);

    await exporter.exportToBytes(
      source: PdfDocumentSource.bytes(Uint8List(0)),
      overlays: const <PdfOverlayItem>[],
      options: const PdfExportOptions(validateOutput: true),
    );

    expect(renderer.openedSourceTypes, <PdfDocumentSourceType>[
      PdfDocumentSourceType.bytes,
      PdfDocumentSourceType.bytes,
    ]);
    expect(renderer.closedDocumentIds, <int>[8, 7]);
  });

  test('overlay exporter saves to file', () async {
    final renderer = _FakeExportRenderer(
      pageCount: 1,
      renderedPagePngBytes: validPngBytes,
    );
    final exporter = PdfOverlayExporter(renderer: renderer);
    final tempDir = await Directory.systemTemp.createTemp('pdf_export_test');
    addTearDown(() => tempDir.delete(recursive: true));

    final file = await exporter.exportToFile(
      source: PdfDocumentSource.bytes(Uint8List(0)),
      overlays: const <PdfOverlayItem>[],
      outputPath: '${tempDir.path}/output.pdf',
    );

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });

  test('overlay exporter cancels safely', () async {
    final renderer = _FakeExportRenderer(
      pageCount: 2,
      renderedPagePngBytes: validPngBytes,
    );
    final exporter = PdfOverlayExporter(renderer: renderer);
    final cancellationToken = PdfExportCancellationToken();
    final progress = <PdfExportProgress>[];

    await expectLater(
      () => exporter.exportToBytes(
        source: PdfDocumentSource.bytes(Uint8List(0)),
        overlays: const <PdfOverlayItem>[],
        cancellationToken: cancellationToken,
        onProgress: (value) {
          progress.add(value);
          cancellationToken.cancel();
        },
      ),
      throwsA(isA<PdfExportCancelledException>()),
    );

    expect(progress, hasLength(1));
    expect(progress.single.completedPages, 1);
    expect(renderer.closedDocumentIds, <int>[7]);
  });

  test('overlay exporter clamps render scale for large pages', () async {
    final renderer = _FakeExportRenderer(
      pageCount: 1,
      renderedPagePngBytes: validPngBytes,
      pageWidth: 2000,
      pageHeight: 2000,
    );
    final exporter = PdfOverlayExporter(renderer: renderer);

    await exporter.exportToBytes(
      source: PdfDocumentSource.bytes(Uint8List(0)),
      overlays: const <PdfOverlayItem>[],
      options: const PdfExportOptions(
        renderScale: 3.0,
        maxPagePixelCount: 4 * 1000 * 1000,
      ),
    );

    expect(renderer.renderRequestScales, hasLength(1));
    expect(renderer.renderRequestScales.single, closeTo(1.0, 0.0001));
  });

  test(
    'overlay exporter supports Unicode text with embedded font bytes',
    () async {
      final renderer = _FakeExportRenderer(
        pageCount: 1,
        renderedPagePngBytes: validPngBytes,
      );
      final exporter = PdfOverlayExporter(renderer: renderer);

      final output = await exporter.exportToBytes(
        source: PdfDocumentSource.bytes(Uint8List(0)),
        overlays: <PdfOverlayItem>[
          PdfTextOverlay(
            id: 'unicode-text',
            pageIndex: 0,
            bounds: const PdfRect(left: 20, top: 20, width: 160, height: 36),
            text: 'বাংলা العربية café',
            fontSize: 16,
          ),
        ],
        options: PdfExportOptions(unicodeFontBytes: unicodeFontBytes),
      );

      expect(output, isNotEmpty);
      expect(ascii.decode(output.take(5).toList()), '%PDF-');
    },
  );

  test('overlay exporter supports Arabic RTL text', () async {
    final renderer = _FakeExportRenderer(
      pageCount: 1,
      renderedPagePngBytes: validPngBytes,
    );
    final exporter = PdfOverlayExporter(renderer: renderer);

    final output = await exporter.exportToBytes(
      source: PdfDocumentSource.bytes(Uint8List(0)),
      overlays: <PdfOverlayItem>[
        PdfTextOverlay(
          id: 'arabic-text',
          pageIndex: 0,
          bounds: const PdfRect(left: 20, top: 20, width: 180, height: 36),
          text: 'مرحبا بالعالم 123',
          fontSize: 16,
        ),
      ],
      options: PdfExportOptions(unicodeFontBytes: unicodeFontBytes),
    );

    expect(output, isNotEmpty);
    expect(ascii.decode(output.take(5).toList()), '%PDF-');
  });

  test(
    'overlay exporter supports numbers and punctuation across scripts',
    () async {
      final renderer = _FakeExportRenderer(
        pageCount: 1,
        renderedPagePngBytes: validPngBytes,
      );
      final exporter = PdfOverlayExporter(renderer: renderer);

      final output = await exporter.exportToBytes(
        source: PdfDocumentSource.bytes(Uint8List(0)),
        overlays: <PdfOverlayItem>[
          PdfTextOverlay(
            id: 'punctuation-text',
            pageIndex: 0,
            bounds: const PdfRect(left: 20, top: 20, width: 220, height: 40),
            text: 'Invoice ১২৩ - رقم ٤٥٦, total: 78.90!',
            fontSize: 16,
          ),
        ],
        options: PdfExportOptions(unicodeFontBytes: unicodeFontBytes),
      );

      expect(output, isNotEmpty);
      expect(ascii.decode(output.take(5).toList()), '%PDF-');
    },
  );

  test(
    'overlay exporter supports Bengali multiline text form fields',
    () async {
      final renderer = _FakeExportRenderer(
        pageCount: 1,
        renderedPagePngBytes: validPngBytes,
      );
      final exporter = PdfOverlayExporter(renderer: renderer);

      final output = await exporter.exportToBytes(
        source: PdfDocumentSource.bytes(Uint8List(0)),
        overlays: const <PdfOverlayItem>[],
        formFields: <PdfFormField>[
          const PdfTextFormField(
            id: 'unicode-form',
            name: 'unicode_form',
            pageIndex: 0,
            bounds: PdfRect(left: 20, top: 20, width: 180, height: 48),
            value: 'বাংলা লাইন ১\nবাংলা লাইন ২',
            isMultiline: true,
          ),
        ],
        options: PdfExportOptions(unicodeFontBytes: unicodeFontBytes),
      );

      expect(output, isNotEmpty);
      expect(ascii.decode(output.take(5).toList()), '%PDF-');
    },
  );

  test(
    'overlay exporter fits long Unicode text into constrained boxes',
    () async {
      final renderer = _FakeExportRenderer(
        pageCount: 1,
        renderedPagePngBytes: validPngBytes,
      );
      final exporter = PdfOverlayExporter(renderer: renderer);

      final output = await exporter.exportToBytes(
        source: PdfDocumentSource.bytes(Uint8List(0)),
        overlays: <PdfOverlayItem>[
          PdfTextOverlay(
            id: 'long-text',
            pageIndex: 0,
            bounds: const PdfRect(left: 20, top: 20, width: 110, height: 32),
            text:
                'বাংলা العربية café with a much longer mixed-language sentence',
            fontSize: 18,
          ),
        ],
        formFields: <PdfFormField>[
          const PdfTextFormField(
            id: 'long-form',
            name: 'long_form',
            pageIndex: 0,
            bounds: PdfRect(left: 20, top: 70, width: 110, height: 44),
            value: 'هذا سطر طويل مع বাংলা mixed content 12345',
            isMultiline: true,
          ),
        ],
        options: PdfExportOptions(unicodeFontBytes: unicodeFontBytes),
      );

      expect(output, isNotEmpty);
      expect(ascii.decode(output.take(5).toList()), '%PDF-');
    },
  );
}

final class _FakeExportRenderer implements PdfExportRenderer {
  _FakeExportRenderer({
    required this.pageCount,
    required this.renderedPagePngBytes,
    this.validatedPageCount,
    this.pageWidth = 300,
    this.pageHeight = 240,
  });

  final int pageCount;
  final Uint8List renderedPagePngBytes;
  final int? validatedPageCount;
  final double pageWidth;
  final double pageHeight;
  final List<int> renderedPages = <int>[];
  final List<double> renderRequestScales = <double>[];
  final List<int> closedDocumentIds = <int>[];
  final List<PdfDocumentSourceType> openedSourceTypes =
      <PdfDocumentSourceType>[];

  @override
  Future<void> closeDocument(int documentId) async {
    closedDocumentIds.add(documentId);
  }

  @override
  Future<PdfPageInfo> getPageInfo({
    required int documentId,
    required int pageIndex,
  }) async {
    return PdfPageInfo(
      documentId: documentId,
      pageIndex: pageIndex,
      width: pageWidth,
      height: pageHeight,
    );
  }

  @override
  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source) async {
    openedSourceTypes.add(source.type);
    final isValidationOpen =
        source.type == PdfDocumentSourceType.bytes &&
        (source.bytes?.isNotEmpty ?? false) &&
        openedSourceTypes.length > 1;
    return PdfDocumentInfo(
      documentId: isValidationOpen ? 8 : 7,
      pageCount: isValidationOpen
          ? (validatedPageCount ?? pageCount)
          : pageCount,
    );
  }

  @override
  Future<PdfRenderedPage> renderPage(PdfRenderRequest request) async {
    renderedPages.add(request.pageIndex);
    renderRequestScales.add(request.scale);
    return PdfRenderedPage(
      documentId: request.documentId,
      pageIndex: request.pageIndex,
      width: (pageWidth * request.scale).round(),
      height: (pageHeight * request.scale).round(),
      pngBytes: renderedPagePngBytes,
    );
  }
}

Future<Uint8List> _createValidPngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) {
    throw StateError('Failed to create PNG bytes for tests.');
  }
  return data.buffer.asUint8List();
}

Uint8List _buildSampleFormPdf() {
  final pageStream = [
    'BT',
    '/F1 18 Tf',
    '40 200 Td',
    '(Phase 5 sample PDF - Basic Form Filling) Tj',
    '0 -40 Td',
    '(Name:) Tj',
    '0 -60 Td',
    '(Accept terms:) Tj',
    '0 -40 Td',
    '(Preferred contact:) Tj',
    '60 0 Td',
    '(Email) Tj',
    '60 0 Td',
    '(Phone) Tj',
    '-120 -40 Td',
    '(Country:) Tj',
    '0 -40 Td',
    '(Skills:) Tj',
    '0 -40 Td',
    '(Focus areas:) Tj',
    '0 -40 Td',
    '(Signature:) Tj',
    'ET',
  ].join('\n');

  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R /AcroForm 15 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 240] /Contents 4 0 R /Resources << /Font << /F1 11 0 R >> >> /Annots [5 0 R 6 0 R 7 0 R 8 0 R 10 0 R 11 0 R 12 0 R 13 0 R] >>',
    '<< /Length ${pageStream.length} >>\nstream\n$pageStream\nendstream',
    '<< /Type /Annot /Subtype /Widget /FT /Tx /T (name) /Rect [90 150 240 178] /V (Sakib) /DA (/F1 12 Tf 0 g) /P 3 0 R >>',
    '<< /Type /Annot /Subtype /Widget /FT /Btn /T (accept_terms) /Rect [130 90 150 110] /V /Off /AS /Off /P 3 0 R >>',
    '<< /Type /Annot /Subtype /Widget /Parent 9 0 R /Rect [120 55 140 75] /AP << /N << /email 16 0 R /Off 17 0 R >> >> /AS /email /P 3 0 R >>',
    '<< /Type /Annot /Subtype /Widget /Parent 9 0 R /Rect [180 55 200 75] /AP << /N << /phone 16 0 R /Off 17 0 R >> >> /AS /Off /P 3 0 R >>',
    '<< /FT /Btn /T (contact_method) /Ff 32768 /V /email /Kids [7 0 R 8 0 R] >>',
    '<< /Type /Annot /Subtype /Widget /FT /Ch /Ff 131072 /T (country) /Rect [90 10 240 38] /V (sa) /Opt [[(sa) (Saudi Arabia)] [(bd) (Bangladesh)] [(in) (India)]] /DA (/F1 12 Tf 0 g) /P 3 0 R >>',
    '<< /Type /Annot /Subtype /Widget /FT /Ch /T (skills) /Rect [90 -30 240 26] /V (flutter) /Opt [(flutter) (dart) (pdf)] /DA (/F1 12 Tf 0 g) /P 3 0 R >>',
    '<< /Type /Annot /Subtype /Widget /FT /Ch /Ff 2097152 /T (focus_areas) /Rect [90 -80 240 -10] /V [(pdf) (forms)] /Opt [[(pdf) (PDF)] [(forms) (Forms)] [(ocr) (OCR)]] /DA (/F1 12 Tf 0 g) /P 3 0 R >>',
    '<< /Type /Annot /Subtype /Widget /FT /Sig /T (signature) /Rect [90 -130 240 -88] /P 3 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Fields [5 0 R 6 0 R 9 0 R 10 0 R 11 0 R 12 0 R 13 0 R] /DA (/F1 12 Tf 0 g) >>',
    '<< >>',
    '<< >>',
  ];

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];

  for (var index = 0; index < objects.length; index++) {
    offsets.add(buffer.toString().length);
    buffer.write('${index + 1} 0 obj\n');
    buffer.write(objects[index]);
    buffer.write('\nendobj\n');
  }

  final xrefOffset = buffer.toString().length;
  buffer.write('xref\n');
  buffer.write('0 ${objects.length + 1}\n');
  buffer.write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer\n');
  buffer.write('<< /Root 1 0 R /Size ${objects.length + 1} >>\n');
  buffer.write('startxref\n');
  buffer.write('$xrefOffset\n');
  buffer.write('%%EOF\n');

  return Uint8List.fromList(ascii.encode(buffer.toString()));
}
