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
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      'openDocument',
      <String, Object?>{
        'sourceType': source.type.name,
        'path': source.path,
        'bytes': source.bytes,
      },
    );

    if (result == null) {
      throw PlatformException(
        code: 'null_result',
        message: 'openDocument returned null.',
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
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      'getPageInfo',
      <String, Object?>{'documentId': documentId, 'pageIndex': pageIndex},
    );

    if (result == null) {
      throw PlatformException(
        code: 'null_result',
        message: 'getPageInfo returned null.',
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
    final result = await methodChannel
        .invokeMapMethod<Object?, Object?>('renderPage', <String, Object?>{
          'documentId': request.documentId,
          'pageIndex': request.pageIndex,
          'scale': request.scale,
          'backgroundColor': request.backgroundColor,
        });

    if (result == null) {
      throw PlatformException(
        code: 'null_result',
        message: 'renderPage returned null.',
      );
    }

    final pngBytes = result['pngBytes'];
    if (pngBytes is! Uint8List) {
      throw PlatformException(
        code: 'invalid_result',
        message: 'renderPage did not return pngBytes.',
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
    return methodChannel.invokeMethod<void>('closeDocument', <String, Object?>{
      'documentId': documentId,
    });
  }
}

int _readInt(Map<Object?, Object?> values, String key) {
  final value = values[key];
  if (value is int) {
    return value;
  }
  throw PlatformException(
    code: 'invalid_result',
    message: 'Expected int for "$key", got ${value.runtimeType}.',
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
  throw PlatformException(
    code: 'invalid_result',
    message: 'Expected double for "$key", got ${value.runtimeType}.',
  );
}
