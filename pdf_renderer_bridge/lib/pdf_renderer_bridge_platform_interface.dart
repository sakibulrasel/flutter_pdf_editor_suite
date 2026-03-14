import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

import 'pdf_renderer_bridge_method_channel.dart';

abstract class PdfRendererBridgePlatform extends PlatformInterface {
  /// Constructs a PdfRendererBridgePlatform.
  PdfRendererBridgePlatform() : super(token: _token);

  static final Object _token = Object();

  static PdfRendererBridgePlatform _instance = MethodChannelPdfRendererBridge();

  /// The default instance of [PdfRendererBridgePlatform] to use.
  ///
  /// Defaults to [MethodChannelPdfRendererBridge].
  static PdfRendererBridgePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PdfRendererBridgePlatform] when
  /// they register themselves.
  static set instance(PdfRendererBridgePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<PdfDocumentInfo> openDocument(PdfDocumentSource source) {
    throw UnimplementedError('openDocument() has not been implemented.');
  }

  Future<PdfPageInfo> getPageInfo({
    required int documentId,
    required int pageIndex,
  }) {
    throw UnimplementedError('getPageInfo() has not been implemented.');
  }

  Future<PdfRenderedPage> renderPage(PdfRenderRequest request) {
    throw UnimplementedError('renderPage() has not been implemented.');
  }

  Future<void> closeDocument(int documentId) {
    throw UnimplementedError('closeDocument() has not been implemented.');
  }
}
