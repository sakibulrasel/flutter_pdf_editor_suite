/// Base class for every error raised by the flutter_pdf_editor_suite packages.
///
/// Catch [PdfException] to handle all suite errors in one place, or catch a
/// subclass to react to a specific problem (for example, ask for a password
/// on [PdfPasswordRequiredException]).
class PdfException implements Exception {
  /// Creates an exception with a human-readable [message].
  const PdfException(this.message, {this.cause});

  /// Human-readable description of the problem, safe to show to users.
  final String message;

  /// Lower-level error that caused this one, if any.
  final Object? cause;

  @override
  String toString() => 'PdfException: $message';
}

/// The bytes are not a PDF, or the PDF is too damaged to read.
class PdfInvalidDocumentException extends PdfException {
  /// Creates an invalid-document exception.
  const PdfInvalidDocumentException(super.message, {super.cause});

  @override
  String toString() => 'PdfInvalidDocumentException: $message';
}

/// A file-based [PdfException] where the file does not exist.
class PdfFileNotFoundException extends PdfException {
  /// Creates a file-not-found exception for [path].
  PdfFileNotFoundException(this.path, {Object? cause})
    : super('PDF file does not exist: $path', cause: cause);

  /// Path that could not be found.
  final String path;

  @override
  String toString() => 'PdfFileNotFoundException: $message';
}

/// The PDF is encrypted and needs a password to open.
///
/// Opening password-protected PDFs is planned for a later release; today
/// this is thrown so apps can show a clear message instead of a crash.
class PdfPasswordRequiredException extends PdfException {
  /// Creates a password-required exception.
  const PdfPasswordRequiredException([
    super.message = 'The PDF document is password protected.',
  ]);

  @override
  String toString() => 'PdfPasswordRequiredException: $message';
}

/// PDF features that the suite detects but cannot handle yet.
enum PdfUnsupportedFeature {
  /// The document is encrypted (`/Encrypt`).
  encryption('encrypted PDFs'),

  /// Objects are stored inside compressed object streams (`/ObjStm`).
  compressedObjectStreams('compressed object streams (PDF 1.5+)'),

  /// The cross-reference table is stored as a stream (`/Type /XRef`).
  crossReferenceStreams('cross-reference streams (PDF 1.5+)'),

  /// The form is an XFA form with no usable AcroForm fields.
  xfaForms('XFA forms'),

  /// A stream uses a filter the suite cannot decode (for example image
  /// filters such as DCTDecode).
  streamFilter('this stream filter');

  const PdfUnsupportedFeature(this.description);

  /// Short human-readable name of the feature.
  final String description;
}

/// The PDF uses a feature that the requested operation does not support yet.
class PdfUnsupportedFeatureException extends PdfException {
  /// Creates an unsupported-feature exception for [feature].
  ///
  /// [operation] names what was being attempted, for example
  /// `'Form parsing'`.
  PdfUnsupportedFeatureException(this.feature, {this.operation})
    : super(
        '${operation ?? 'This operation'} does not support '
        '${feature.description} yet.',
      );

  /// The unsupported feature that was detected.
  final PdfUnsupportedFeature feature;

  /// The operation that was attempted, if known.
  final String? operation;

  @override
  String toString() => 'PdfUnsupportedFeatureException: $message';
}

/// The current platform has no PDF renderer implementation.
class PdfUnsupportedPlatformException extends PdfException {
  /// Creates an unsupported-platform exception for [platform].
  PdfUnsupportedPlatformException(this.platform, {Object? cause})
    : super(
        'PDF rendering is not supported on $platform yet. '
        'Supported platforms: Android and iOS.',
        cause: cause,
      );

  /// Name of the platform, for example `'windows'` or `'web'`.
  final String platform;

  @override
  String toString() => 'PdfUnsupportedPlatformException: $message';
}

/// A native renderer failed for a reason not covered by a more specific
/// exception.
class PdfRenderException extends PdfException {
  /// Creates a render exception, optionally with the native error [code].
  const PdfRenderException(super.message, {this.code, super.cause});

  /// Native error code, when one was reported.
  final String? code;

  @override
  String toString() => 'PdfRenderException: $message';
}
