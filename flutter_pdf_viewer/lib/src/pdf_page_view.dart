import 'package:flutter/material.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge.dart';

class PdfPageView extends StatefulWidget {
  const PdfPageView({
    required this.source,
    super.key,
    this.pageIndex = 0,
    this.scale = 1.0,
    this.fit = BoxFit.contain,
    this.loading,
    this.errorBuilder,
  });

  final PdfDocumentSource source;
  final int pageIndex;
  final double scale;
  final BoxFit fit;
  final Widget? loading;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  final PdfRendererBridge _bridge = PdfRendererBridge();
  Future<_PdfPageViewData>? _pageFuture;
  int? _documentId;

  @override
  void initState() {
    super.initState();
    _pageFuture = _loadPage();
  }

  @override
  void didUpdateWidget(covariant PdfPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.scale != widget.scale) {
      setState(() {
        _pageFuture = _loadPage();
      });
    }
  }

  Future<_PdfPageViewData> _loadPage() async {
    if (_documentId case final currentDocumentId?) {
      await _bridge.closeDocument(currentDocumentId);
      _documentId = null;
    }

    final document = await _bridge.openDocument(widget.source);
    try {
      final page = await _bridge.getPageInfo(
        documentId: document.documentId,
        pageIndex: widget.pageIndex,
      );
      final rendered = await _bridge.renderPage(
        PdfRenderRequest(
          documentId: document.documentId,
          pageIndex: widget.pageIndex,
          scale: widget.scale,
        ),
      );
      _documentId = document.documentId;
      return _PdfPageViewData(pageInfo: page, renderedPage: rendered);
    } catch (_) {
      await _bridge.closeDocument(document.documentId);
      rethrow;
    }
  }

  @override
  void dispose() {
    final documentId = _documentId;
    if (documentId != null) {
      _bridge.closeDocument(documentId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PdfPageViewData>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.errorBuilder?.call(context, snapshot.error!) ??
              Center(
                child: Text('Failed to render PDF page: ${snapshot.error}'),
              );
        }
        if (!snapshot.hasData) {
          return widget.loading ??
              const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        return AspectRatio(
          aspectRatio: data.pageInfo.width / data.pageInfo.height,
          child: Image.memory(
            data.renderedPage.pngBytes,
            fit: widget.fit,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}

final class _PdfPageViewData {
  const _PdfPageViewData({required this.pageInfo, required this.renderedPage});

  final PdfPageInfo pageInfo;
  final PdfRenderedPage renderedPage;
}
