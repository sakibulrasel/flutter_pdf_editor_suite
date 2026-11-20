import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

import 'pdf_renderer_bridge_platform_interface.dart';

/// An implementation of [PdfRendererBridgePlatform] that uses method channels.
class MethodChannelPdfRendererBridge extends PdfRendererBridgePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pdf_renderer_bridge');

  @override
  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source) async {
    final result = await _invokeMap(
      'openDocument',
      <String, Object?>{
        'sourceType': source.type.name,
        'path': source.path,
        'bytes': source.bytes,
      },
    );

    if (result == null) {
      throw const PdfRenderException(
        'openDocument returned null.',
        code: 'null_result',
      );
    }

    return PdfDocumentInfo(
      documentId: _readInt(result, 'documentId'),
      pageCount: _readInt(result, 'pageCount'),
    );
  }

  @override
  Future<PdfPageInfo> getPageInfo({
    required int documentId,
    required int pageIndex,
  }) async {
    final result = await _invokeMap(
      'getPageInfo',
      <String, Object?>{'documentId': documentId, 'pageIndex': pageIndex},
    );

    if (result == null) {
      throw const PdfRenderException(
        'getPageInfo returned null.',
        code: 'null_result',
      );
    }

    return PdfPageInfo(
      documentId: _readInt(result, 'documentId'),
      pageIndex: _readInt(result, 'pageIndex'),
      width: _readDouble(result, 'width'),
      height: _readDouble(result, 'height'),
    );
  }

  @override
  Future<PdfRenderedPage> renderPage(PdfRenderRequest request) async {
    final result = await _invokeMap('renderPage', <String, Object?>{
      'documentId': request.documentId,
      'pageIndex': request.pageIndex,
      'scale': request.scale,
      'backgroundColor': request.backgroundColor,
    });

    if (result == null) {
      throw const PdfRenderException(
        'renderPage returned null.',
        code: 'null_result',
      );
    }

    final pngBytes = result['pngBytes'];
    if (pngBytes is! Uint8List) {
      throw const PdfRenderException(
        'renderPage did not return pngBytes.',
        code: 'invalid_result',
      );
    }

    return PdfRenderedPage(
      documentId: _readInt(result, 'documentId'),
      pageIndex: _readInt(result, 'pageIndex'),
      width: _readInt(result, 'width'),
      height: _readInt(result, 'height'),
      pngBytes: pngBytes,
    );
  }

  @override
  Future<void> closeDocument(int documentId) {
    return _guard(
      () => methodChannel.invokeMethod<void>('closeDocument', <String, Object?>{
        'documentId': documentId,
      }),
      path: null,
    );
  }

  Future<Map<Object?, Object?>?> _invokeMap(
    String method,
    Map<String, Object?> arguments,
  ) {
    return _guard(
      () => methodChannel.invokeMapMethod<Object?, Object?>(method, arguments),
      path: arguments['path'] as String?,
    );
  }

  /// Runs a channel call and turns platform errors into typed
  /// [PdfException]s.
  Future<T> _guard<T>(Future<T> Function() call, {required String? path}) async {
    try {
      return await call();
    } on MissingPluginException catch (error) {
      throw PdfUnsupportedPlatformException(_platformName(), cause: error);
    } on PlatformException catch (error) {
      throw mapPlatformException(error, path: path);
    }
  }
}

/// Maps a native [PlatformException] to the matching typed [PdfException].
///
/// Native code reports stable error codes: `password_required`,
/// `file_not_found`, `invalid_pdf`, and `pdf_renderer_error` for anything
/// else.
@visibleForTesting
PdfException mapPlatformException(PlatformException error, {String? path}) {
  final message = error.message ?? 'The PDF renderer failed.';
  switch (error.code) {
    case 'password_required':
      return const PdfPasswordRequiredException();
    case 'file_not_found':
      return PdfFileNotFoundException(path ?? message, cause: error);
    case 'invalid_pdf':
      return PdfInvalidDocumentException(message, cause: error);
    default:
      return PdfRenderException(message, code: error.code, cause: error);
  }
}

String _platformName() {
  if (kIsWeb) {
    return 'web';
  }
  return defaultTargetPlatform.name;
}

int _readInt(Map<Object?, Object?> values, String key) {
  final value = values[key];
  if (value is int) {
    return value;
  }
  throw PdfRenderException(
    'Expected int for "$key", got ${value.runtimeType}.',
    code: 'invalid_result',
  );
}

double _readDouble(Map<Object?, Object?> values, String key) {
  final value = values[key];
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  throw PdfRenderException(
    'Expected double for "$key", got ${value.runtimeType}.',
    code: 'invalid_result',
  );
}
