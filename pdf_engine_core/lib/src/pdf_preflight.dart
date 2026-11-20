import 'dart:convert';
import 'dart:typed_data';

import 'pdf_exceptions.dart';

/// Quick structural checks run on raw PDF bytes before parsing or saving.
///
/// The preflight does not parse the document. It scans the bytes for
/// structural markers (encryption, object streams, cross-reference streams,
/// XFA) so callers can decide early what a file needs.
///
/// The object model in `package:pdf_engine_core/cos.dart` reads all of these
/// layouts except encryption, so the suite's own parser and exporter no
/// longer depend on [PdfPreflightReport.ensureReadable]. The guards remain
/// for code that only handles classic, uncompressed files.
final class PdfPreflight {
  const PdfPreflight._();

  /// Inspects [bytes] and returns what was found.
  static PdfPreflightReport inspect(Uint8List bytes) {
    final text = latin1.decode(bytes);

    final headerIndex = text.indexOf('%PDF-');
    // The PDF spec allows junk before the header; readers accept up to 1 KB.
    final isPdf = headerIndex >= 0 && headerIndex < 1024;
    final version = isPdf
        ? RegExp(r'%PDF-(\d\.\d)').matchAsPrefix(text, headerIndex)?.group(1)
        : null;

    return PdfPreflightReport(
      isPdf: isPdf,
      version: version,
      isEncrypted: _encryptPattern.hasMatch(text),
      usesObjectStreams: _objectStreamPattern.hasMatch(text),
      usesCrossReferenceStreams: _xrefStreamPattern.hasMatch(text),
      hasClassicTrailer: _trailerPattern.hasMatch(text),
      hasAcroForm: _acroFormPattern.hasMatch(text),
      hasXfa: _xfaPattern.hasMatch(text),
      revisionCount: '%%EOF'.allMatches(text).length,
    );
  }

  // `/Encrypt` followed by a reference or an inline dictionary, so that the
  // word appearing in page text does not count.
  static final _encryptPattern = RegExp(r'/Encrypt\s*(\d+\s+\d+\s+R|<<)');
  static final _objectStreamPattern = RegExp(r'/Type\s*/ObjStm\b');
  // `\b` keeps `/XRefStm` (hybrid-reference trailers) from matching.
  static final _xrefStreamPattern = RegExp(r'/Type\s*/XRef\b');
  static final _trailerPattern = RegExp(r'trailer\s*<<');
  static final _acroFormPattern = RegExp(r'/AcroForm\b');
  static final _xfaPattern = RegExp(r'/XFA\b');
}

/// Result of [PdfPreflight.inspect].
final class PdfPreflightReport {
  /// Creates a preflight report.
  const PdfPreflightReport({
    required this.isPdf,
    required this.version,
    required this.isEncrypted,
    required this.usesObjectStreams,
    required this.usesCrossReferenceStreams,
    required this.hasClassicTrailer,
    required this.hasAcroForm,
    required this.hasXfa,
    required this.revisionCount,
  });

  /// Whether a `%PDF-` header was found in the first 1024 bytes.
  final bool isPdf;

  /// Header version such as `'1.7'`, or `null` when unreadable.
  final String? version;

  /// Whether the document is encrypted.
  final bool isEncrypted;

  /// Whether objects are stored in compressed object streams (`/ObjStm`).
  final bool usesObjectStreams;

  /// Whether a cross-reference stream (`/Type /XRef`) is present.
  final bool usesCrossReferenceStreams;

  /// Whether a classic `trailer << ... >>` dictionary is present.
  final bool hasClassicTrailer;

  /// Whether an `/AcroForm` key is visible in uncompressed bytes.
  ///
  /// May be `false` for forms whose catalog sits in an object stream.
  final bool hasAcroForm;

  /// Whether an `/XFA` key is visible in uncompressed bytes.
  final bool hasXfa;

  /// Number of `%%EOF` markers, roughly one per saved revision.
  final int revisionCount;

  /// Whether a reader limited to classic, uncompressed PDFs can read the
  /// file. `PdfCosDocument` also reads object streams.
  bool get isReadable => isPdf && !isEncrypted && !usesObjectStreams;

  /// Whether the file can be saved with a classic incremental update.
  bool get isIncrementallyWritable =>
      isReadable && hasClassicTrailer && !usesCrossReferenceStreams;

  /// Throws if a classic-only reader cannot read this file.
  ///
  /// [operation] names what is being attempted and appears in the message.
  void ensureReadable({required String operation}) {
    if (!isPdf) {
      throw const PdfInvalidDocumentException(
        'The data is not a PDF document (no %PDF- header).',
      );
    }
    if (isEncrypted) {
      throw PdfUnsupportedFeatureException(
        PdfUnsupportedFeature.encryption,
        operation: operation,
      );
    }
    if (usesObjectStreams) {
      throw PdfUnsupportedFeatureException(
        PdfUnsupportedFeature.compressedObjectStreams,
        operation: operation,
      );
    }
  }

  /// Throws if the file cannot be saved with a classic incremental update.
  void ensureIncrementallyWritable({required String operation}) {
    ensureReadable(operation: operation);
    if (usesCrossReferenceStreams) {
      throw PdfUnsupportedFeatureException(
        PdfUnsupportedFeature.crossReferenceStreams,
        operation: operation,
      );
    }
    if (!hasClassicTrailer) {
      throw const PdfInvalidDocumentException(
        'The PDF has no trailer dictionary.',
      );
    }
  }
}
