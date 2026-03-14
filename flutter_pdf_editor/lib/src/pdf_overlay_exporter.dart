import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge.dart';

typedef PdfExportProgressCallback = void Function(PdfExportProgress progress);

final class PdfExportProgress {
  const PdfExportProgress({
    required this.completedPages,
    required this.totalPages,
  });

  final int completedPages;
  final int totalPages;
}

final class PdfExportCancellationToken {
  bool get isCancelled => _isCancelled;

  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
  }
}

class PdfExportCancelledException implements Exception {
  const PdfExportCancelledException();

  @override
  String toString() => 'PdfExportCancelledException';
}

class PdfExportValidationException implements Exception {
  const PdfExportValidationException(this.message);

  final String message;

  @override
  String toString() => 'PdfExportValidationException: $message';
}

final class PdfExportOptions {
  const PdfExportOptions({
    this.renderScale = 2.0,
    this.maxPagePixelCount = 4 * 1000 * 1000,
    this.validateOutput = false,
    this.unicodeFontBytes,
  }) : assert(renderScale > 0, 'renderScale must be greater than zero'),
       assert(
         maxPagePixelCount > 0,
         'maxPagePixelCount must be greater than zero',
       );

  final double renderScale;
  final int maxPagePixelCount;
  final bool validateOutput;
  final Uint8List? unicodeFontBytes;
}

abstract interface class PdfExportRenderer {
  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source);

  Future<PdfPageInfo> getPageInfo({
    required int documentId,
    required int pageIndex,
  });

  Future<PdfRenderedPage> renderPage(PdfRenderRequest request);

  Future<void> closeDocument(int documentId);
}

final class PdfBridgeExportRenderer implements PdfExportRenderer {
  PdfBridgeExportRenderer([PdfRendererBridge? bridge])
    : _bridge = bridge ?? PdfRendererBridge();

  final PdfRendererBridge _bridge;

  @override
  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source) {
    return _bridge.openDocument(source);
  }

  @override
  Future<PdfPageInfo> getPageInfo({
    required int documentId,
    required int pageIndex,
  }) {
    return _bridge.getPageInfo(documentId: documentId, pageIndex: pageIndex);
  }

  @override
  Future<PdfRenderedPage> renderPage(PdfRenderRequest request) {
    return _bridge.renderPage(request);
  }

  @override
  Future<void> closeDocument(int documentId) {
    return _bridge.closeDocument(documentId);
  }
}

final class PdfOverlayExporter {
  PdfOverlayExporter({PdfExportRenderer? renderer})
    : _renderer = renderer ?? PdfBridgeExportRenderer();

  final PdfExportRenderer _renderer;

  Future<Uint8List> exportToBytes({
    required PdfDocumentSource source,
    required List<PdfOverlayItem> overlays,
    List<PdfFormField> formFields = const <PdfFormField>[],
    PdfExportOptions options = const PdfExportOptions(),
    PdfExportCancellationToken? cancellationToken,
    PdfExportProgressCallback? onProgress,
  }) async {
    _throwIfCancelled(cancellationToken);
    final documentInfo = await _renderer.openDocument(source);
    final outputDocument = pw.Document();
    final unicodeFont = await _resolveUnicodeFont(options);

    try {
      for (var pageIndex = 0; pageIndex < documentInfo.pageCount; pageIndex++) {
        _throwIfCancelled(cancellationToken);

        final pageInfo = await _renderer.getPageInfo(
          documentId: documentInfo.documentId,
          pageIndex: pageIndex,
        );
        final effectiveRenderScale = _effectiveRenderScale(
          pageWidth: pageInfo.width,
          pageHeight: pageInfo.height,
          options: options,
        );
        final renderedPage = await _renderer.renderPage(
          PdfRenderRequest(
            documentId: documentInfo.documentId,
            pageIndex: pageIndex,
            scale: effectiveRenderScale,
          ),
        );
        final pageImage = pw.MemoryImage(renderedPage.pngBytes);
        final pageOverlays = overlays
            .where((overlay) => overlay.pageIndex == pageIndex)
            .toList(growable: false);
        final pageFormFields = formFields
            .where((field) => field.pageIndex == pageIndex)
            .toList(growable: false);

        outputDocument.addPage(
          pw.Page(
            pageFormat: pdf.PdfPageFormat(pageInfo.width, pageInfo.height),
            margin: pw.EdgeInsets.zero,
            build: (context) {
              return pw.Stack(
                children: [
                  pw.Positioned.fill(
                    child: pw.Image(pageImage, fit: pw.BoxFit.fill),
                  ),
                  for (final overlay in pageOverlays)
                    _buildOverlayWidget(overlay, unicodeFont),
                  for (final field in pageFormFields)
                    _buildFormFieldWidget(field, unicodeFont),
                ],
              );
            },
          ),
        );

        onProgress?.call(
          PdfExportProgress(
            completedPages: pageIndex + 1,
            totalPages: documentInfo.pageCount,
          ),
        );
      }

      _throwIfCancelled(cancellationToken);
      final bytes = await outputDocument.save();
      if (options.validateOutput) {
        await _validateExportedBytes(
          bytes: bytes,
          expectedPageCount: documentInfo.pageCount,
          cancellationToken: cancellationToken,
        );
      }
      return bytes;
    } finally {
      await _renderer.closeDocument(documentInfo.documentId);
    }
  }

  Future<File> exportToFile({
    required PdfDocumentSource source,
    required List<PdfOverlayItem> overlays,
    required String outputPath,
    List<PdfFormField> formFields = const <PdfFormField>[],
    PdfExportOptions options = const PdfExportOptions(),
    PdfExportCancellationToken? cancellationToken,
    PdfExportProgressCallback? onProgress,
  }) async {
    final bytes = await exportToBytes(
      source: source,
      overlays: overlays,
      formFields: formFields,
      options: options,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
    );

    _throwIfCancelled(cancellationToken);
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes, flush: true);
  }

  pw.Widget _buildOverlayWidget(PdfOverlayItem overlay, pw.Font? unicodeFont) {
    final content = switch (overlay) {
      PdfTextOverlay overlay => pw.Container(
        alignment: pw.Alignment.topLeft,
        child: _buildFittedUnicodeText(
          text: overlay.text,
          maxLines: 3,
          width: overlay.bounds.width,
          height: overlay.bounds.height,
          style: pw.TextStyle(
            color: pdf.PdfColor.fromInt(overlay.color),
            fontSize: overlay.fontSize,
            font: unicodeFont,
            fontFallback: unicodeFont == null
                ? const <pw.Font>[]
                : <pw.Font>[unicodeFont],
          ),
        ),
      ),
      PdfCheckmarkOverlay overlay => pw.FittedBox(
        fit: pw.BoxFit.fill,
        child: pw.CustomPaint(
          size: pdf.PdfPoint(overlay.bounds.width, overlay.bounds.height),
          painter: (canvas, size) {
            canvas
              ..setStrokeColor(pdf.PdfColor.fromInt(overlay.color))
              ..setLineWidth(math.max(size.x, size.y) * 0.08)
              ..setLineCap(pdf.PdfLineCap.round)
              ..moveTo(size.x * 0.12, size.y * 0.45)
              ..lineTo(size.x * 0.38, size.y * 0.2)
              ..lineTo(size.x * 0.88, size.y * 0.84)
              ..strokePath();
          },
        ),
      ),
      PdfSignatureOverlay overlay => pw.Image(
        pw.MemoryImage(overlay.pngBytes),
        fit: pw.BoxFit.fill,
      ),
      PdfRectangleOverlay overlay => pw.Container(
        decoration: pw.BoxDecoration(
          color: pdf.PdfColor.fromInt(_withAlpha(overlay.color, 0.08)),
          border: pw.Border.all(
            color: pdf.PdfColor.fromInt(overlay.color),
            width: 2,
          ),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
      ),
      PdfImageOverlay overlay => pw.Image(
        pw.MemoryImage(overlay.imageBytes),
        fit: pw.BoxFit.fill,
      ),
      _ => pw.SizedBox(),
    };

    return pw.Positioned(
      left: overlay.bounds.left,
      top: overlay.bounds.top,
      child: pw.SizedBox(
        width: overlay.bounds.width,
        height: overlay.bounds.height,
        child: content,
      ),
    );
  }

  pw.Widget _buildFormFieldWidget(PdfFormField field, pw.Font? unicodeFont) {
    final content = switch (field) {
      PdfTextFormField field => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdf.PdfColors.blueGrey300, width: 0.75),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          color: pdf.PdfColors.white,
        ),
        child: _buildFittedUnicodeText(
          text: field.value,
          maxLines: field.isMultiline ? null : 1,
          width: field.bounds.width - 8,
          height: field.bounds.height - 4,
          style: pw.TextStyle(
            fontSize: 12,
            font: unicodeFont,
            fontFallback: unicodeFont == null
                ? const <pw.Font>[]
                : <pw.Font>[unicodeFont],
          ),
        ),
      ),
      PdfCheckboxFormField field => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdf.PdfColors.blueGrey300, width: 0.75),
          color: pdf.PdfColors.white,
        ),
        child: field.isChecked
            ? pw.Center(
                child: pw.CustomPaint(
                  size: pdf.PdfPoint(field.bounds.width, field.bounds.height),
                  painter: (canvas, size) {
                    _paintCheckboxMark(
                      canvas: canvas,
                      size: size,
                      markStyle: field.markStyle,
                    );
                  },
                ),
              )
            : pw.SizedBox.expand(),
      ),
      PdfRadioFormField field => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdf.PdfColors.blueGrey300, width: 0.75),
          shape: pw.BoxShape.circle,
          color: pdf.PdfColors.white,
        ),
        child: field.isSelected
            ? pw.Center(
                child: pw.Container(
                  width: field.bounds.width * 0.45,
                  height: field.bounds.height * 0.45,
                  decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: pdf.PdfColors.blue700,
                  ),
                ),
              )
            : pw.SizedBox.expand(),
      ),
      PdfComboBoxFormField field => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdf.PdfColors.blueGrey300, width: 0.75),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          color: pdf.PdfColors.white,
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: _buildFittedUnicodeText(
                text: field.selectedLabel,
                maxLines: 1,
                width: field.bounds.width - 18,
                height: field.bounds.height - 4,
                style: pw.TextStyle(
                  fontSize: 12,
                  font: unicodeFont,
                  fontFallback: unicodeFont == null
                      ? const <pw.Font>[]
                      : <pw.Font>[unicodeFont],
                ),
              ),
            ),
            pw.SizedBox(
              width: 8,
              child: pw.CustomPaint(
                size: const pdf.PdfPoint(8, 6),
                painter: (canvas, size) {
                  canvas
                    ..setFillColor(pdf.PdfColors.blueGrey700)
                    ..moveTo(0, 0)
                    ..lineTo(size.x, 0)
                    ..lineTo(size.x / 2, size.y)
                    ..fillPath();
                },
              ),
            ),
          ],
        ),
      ),
      PdfListBoxFormField field => pw.Container(
        padding: const pw.EdgeInsets.all(3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdf.PdfColors.blueGrey300, width: 0.75),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          color: pdf.PdfColors.white,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            for (final option in field.options.take(
              _visibleListBoxItemCount(field),
            ))
              pw.Container(
                color: field.selectedValues.contains(option.value)
                    ? pdf.PdfColor.fromInt(0xFFD9E8FF)
                    : pdf.PdfColors.white,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1.5,
                ),
                child: _buildFittedUnicodeText(
                  text: option.label,
                  maxLines: 1,
                  width: field.bounds.width - 8,
                  height: math.max(12, field.bounds.height / 4),
                  style: pw.TextStyle(
                    fontSize: 10,
                    font: unicodeFont,
                    fontFallback: unicodeFont == null
                        ? const <pw.Font>[]
                        : <pw.Font>[unicodeFont],
                  ),
                ),
              ),
          ],
        ),
      ),
      PdfSignatureFormField field => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdf.PdfColors.blueGrey300, width: 0.75),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          color: pdf.PdfColors.white,
        ),
        child: field.hasSignature
            ? pw.Padding(
                padding: const pw.EdgeInsets.all(2),
                child: pw.Image(
                  pw.MemoryImage(field.pngBytes!),
                  fit: pw.BoxFit.contain,
                ),
              )
            : pw.Center(
                child: _buildFittedUnicodeText(
                  text: 'Sign here',
                  maxLines: 1,
                  width: field.bounds.width - 8,
                  height: field.bounds.height - 4,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: pdf.PdfColors.blueGrey500,
                    font: unicodeFont,
                    fontFallback: unicodeFont == null
                        ? const <pw.Font>[]
                        : <pw.Font>[unicodeFont],
                  ),
                ),
              ),
      ),
      _ => pw.SizedBox(),
    };

    return pw.Positioned(
      left: field.bounds.left,
      top: field.bounds.top,
      child: pw.SizedBox(
        width: field.bounds.width,
        height: field.bounds.height,
        child: content,
      ),
    );
  }

  void _throwIfCancelled(PdfExportCancellationToken? cancellationToken) {
    if (cancellationToken?.isCancelled ?? false) {
      throw const PdfExportCancelledException();
    }
  }

  void _paintCheckboxMark({
    required pdf.PdfGraphics canvas,
    required pdf.PdfPoint size,
    required PdfCheckboxMarkStyle markStyle,
  }) {
    switch (markStyle) {
      case PdfCheckboxMarkStyle.check:
        canvas
          ..setStrokeColor(pdf.PdfColors.green700)
          ..setLineWidth(math.max(size.x, size.y) * 0.08)
          ..setLineCap(pdf.PdfLineCap.round)
          ..moveTo(size.x * 0.12, size.y * 0.45)
          ..lineTo(size.x * 0.38, size.y * 0.2)
          ..lineTo(size.x * 0.88, size.y * 0.84)
          ..strokePath();
      case PdfCheckboxMarkStyle.cross:
        canvas
          ..setStrokeColor(pdf.PdfColors.red700)
          ..setLineWidth(math.max(size.x, size.y) * 0.08)
          ..setLineCap(pdf.PdfLineCap.round)
          ..moveTo(size.x * 0.2, size.y * 0.2)
          ..lineTo(size.x * 0.8, size.y * 0.8)
          ..moveTo(size.x * 0.8, size.y * 0.2)
          ..lineTo(size.x * 0.2, size.y * 0.8)
          ..strokePath();
      case PdfCheckboxMarkStyle.circle:
        canvas
          ..setFillColor(pdf.PdfColors.blue700)
          ..drawEllipse(
            size.x * 0.24,
            size.y * 0.24,
            size.x * 0.52,
            size.y * 0.52,
          )
          ..fillPath();
      case PdfCheckboxMarkStyle.star:
        final cx = size.x * 0.5;
        final cy = size.y * 0.5;
        final outer = math.min(size.x, size.y) * 0.34;
        final inner = outer * 0.46;
        canvas
          ..setFillColor(pdf.PdfColors.amber700)
          ..moveTo(cx, cy - outer);
        for (var i = 1; i < 10; i++) {
          final radius = i.isEven ? outer : inner;
          final angle = (-math.pi / 2) + (i * math.pi / 5);
          canvas.lineTo(
            cx + radius * math.cos(angle),
            cy + radius * math.sin(angle),
          );
        }
        canvas
          ..closePath()
          ..fillPath();
    }
  }

  int _visibleListBoxItemCount(PdfListBoxFormField field) {
    final estimatedCount = (field.bounds.height / 14).floor();
    return estimatedCount.clamp(1, field.options.length);
  }

  Future<pw.Font?> _resolveUnicodeFont(PdfExportOptions options) async {
    if (options.unicodeFontBytes != null) {
      return pw.Font.ttf(options.unicodeFontBytes!.buffer.asByteData());
    }
    try {
      final asset = await rootBundle.load(
        'packages/flutter_pdf_editor/assets/fonts/Arial Unicode.ttf',
      );
      return pw.Font.ttf(asset);
    } catch (_) {
      return null;
    }
  }

  int _withAlpha(int color, double alpha) {
    final clampedAlpha = (alpha.clamp(0, 1) * 255).round();
    return (clampedAlpha << 24) | (color & 0x00FFFFFF);
  }

  pw.Widget _buildUnicodeText({
    required String text,
    required pw.TextStyle style,
    int? maxLines,
  }) {
    final isRtl = _containsRtlScript(text);
    return pw.Directionality(
      textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Text(
        text,
        maxLines: maxLines,
        textAlign: isRtl ? pw.TextAlign.right : pw.TextAlign.left,
        style: style,
      ),
    );
  }

  pw.Widget _buildFittedUnicodeText({
    required String text,
    required pw.TextStyle style,
    required double width,
    required double height,
    int? maxLines,
  }) {
    final baseFontSize = style.fontSize ?? 12;
    final fittedFontSize = _fittedFontSize(
      text: text,
      baseFontSize: baseFontSize,
      width: width,
      height: height,
      maxLines: maxLines,
    );
    return _buildUnicodeText(
      text: text,
      maxLines: maxLines,
      style: style.copyWith(fontSize: fittedFontSize),
    );
  }

  bool _containsRtlScript(String text) {
    for (final codePoint in text.runes) {
      if ((codePoint >= 0x0590 && codePoint <= 0x08FF) ||
          (codePoint >= 0xFB1D && codePoint <= 0xFEFC)) {
        return true;
      }
    }
    return false;
  }

  double _fittedFontSize({
    required String text,
    required double baseFontSize,
    required double width,
    required double height,
    int? maxLines,
  }) {
    final lineCount = maxLines == null
        ? math.max(1, '\n'.allMatches(text).length + 1)
        : maxLines;
    final availableWidth = math.max(width, 1);
    final availableHeight = math.max(height, 1);
    final longestLineLength = text
        .split('\n')
        .map((line) => line.runes.length)
        .fold<int>(0, math.max);

    final widthBased =
        availableWidth /
        math.max(1, longestLineLength) /
        _averageCharacterWidthFactor;
    final heightBased =
        availableHeight / math.max(1, lineCount) / _lineHeightFactor;
    return math.max(
      _minimumExportFontSize,
      math.min(baseFontSize, math.min(widthBased, heightBased)),
    );
  }

  double _effectiveRenderScale({
    required double pageWidth,
    required double pageHeight,
    required PdfExportOptions options,
  }) {
    final baseScale = options.renderScale;
    final scaledPixels = pageWidth * pageHeight * baseScale * baseScale;
    if (scaledPixels <= options.maxPagePixelCount) {
      return baseScale;
    }

    final clampFactor = math.sqrt(
      options.maxPagePixelCount / (pageWidth * pageHeight),
    );
    return math.max(1.0, math.min(baseScale, clampFactor));
  }

  Future<void> _validateExportedBytes({
    required Uint8List bytes,
    required int expectedPageCount,
    PdfExportCancellationToken? cancellationToken,
  }) async {
    _throwIfCancelled(cancellationToken);
    final documentInfo = await _renderer.openDocument(
      PdfDocumentSource.bytes(bytes),
    );
    try {
      if (documentInfo.pageCount != expectedPageCount) {
        throw PdfExportValidationException(
          'Expected $expectedPageCount pages, got ${documentInfo.pageCount}.',
        );
      }
    } finally {
      await _renderer.closeDocument(documentInfo.documentId);
    }
  }
}

const double _averageCharacterWidthFactor = 0.62;
const double _lineHeightFactor = 1.25;
const double _minimumExportFontSize = 8;
