import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge.dart';

import 'pdf_viewer_controller.dart';

/// Builds a widget layered on top of a rendered PDF page.
typedef PdfPageOverlayBuilder =
    Widget? Function(
      BuildContext context,
      PdfPageInfo pageInfo,
      PdfPageViewport viewport,
    );

/// Scrollable multi-page PDF viewer with zoom and overlay support.
class PdfViewer extends StatefulWidget {
  /// Creates a PDF viewer for [source].
  const PdfViewer({
    required this.source,
    super.key,
    this.controller,
    this.initialZoom = 1,
    this.minZoom = 1,
    this.maxZoom = 3,
    this.cacheExtent = 3,
    this.maxCachedPages = 12,
    this.onPageChanged,
    this.onPageTap,
    this.pageOverlayBuilder,
    this.loading,
    this.errorBuilder,
  }) : assert(minZoom > 0),
       assert(maxZoom >= minZoom),
       assert(initialZoom >= minZoom && initialZoom <= maxZoom),
       assert(cacheExtent >= 0),
       assert(maxCachedPages > 0);

  /// Source PDF document displayed by the viewer.
  final PdfDocumentSource source;

  /// Optional controller used to observe and manipulate viewer state.
  final PdfViewerController? controller;

  /// Initial zoom level used when the viewer is first shown.
  final double initialZoom;

  /// Minimum allowed zoom level.
  final double minZoom;

  /// Maximum allowed zoom level.
  final double maxZoom;

  /// Number of pages around the viewport to prebuild.
  final int cacheExtent;

  /// Maximum number of rendered page images kept in memory.
  final int maxCachedPages;

  /// Called when the current visible page changes. Page numbers are 1-based.
  final ValueChanged<int>? onPageChanged;

  /// Called when a page is tapped, with both screen and PDF coordinates.
  final ValueChanged<PdfPageTapDetails>? onPageTap;

  /// Optional builder for widgets rendered above each page.
  final PdfPageOverlayBuilder? pageOverlayBuilder;

  /// Optional widget shown while the document is loading.
  final Widget? loading;

  /// Optional error widget builder used when the document fails to load.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer>
    implements PdfViewerControllerBinding {
  final PdfRendererBridge _bridge = PdfRendererBridge();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  late PdfViewerController _controller;
  late bool _ownsController;

  Future<_PdfViewerDocumentData>? _documentFuture;
  _PdfViewerDocumentData? _resolvedDocumentData;
  _RenderedPageCache? _cache;
  int? _documentId;
  List<PdfPageInfo> _pages = const <PdfPageInfo>[];
  double _zoom = 1;
  double _viewportWidth = 0;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PdfViewerController();
    _ownsController = widget.controller == null;
    _controller.attach(this);
    _zoom = widget.initialZoom;
    _documentFuture = _loadDocument();
    _verticalController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant PdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller.detach(this);
      if (_ownsController) {
        _controller.dispose();
      }
      _controller = widget.controller ?? PdfViewerController();
      _ownsController = widget.controller == null;
      _controller.attach(this);
      _scheduleControllerPageSync(_currentPage);
    }

    if (oldWidget.source != widget.source ||
        oldWidget.maxCachedPages != widget.maxCachedPages) {
      setState(() {
        _documentFuture = _loadDocument();
      });
    }
  }

  Future<_PdfViewerDocumentData> _loadDocument() async {
    final previousDocumentId = _documentId;
    final previousCache = _cache;

    final document = await _bridge.openDocument(widget.source);
    try {
      final pages = <PdfPageInfo>[];
      for (var pageIndex = 0; pageIndex < document.pageCount; pageIndex++) {
        pages.add(
          await _bridge.getPageInfo(
            documentId: document.documentId,
            pageIndex: pageIndex,
          ),
        );
      }
      final nextCache = _RenderedPageCache(
        bridge: _bridge,
        documentId: document.documentId,
        maxEntries: widget.maxCachedPages,
      );
      final nextData = _PdfViewerDocumentData(document: document, pages: pages);
      _documentId = document.documentId;
      _cache = nextCache;
      _pages = pages;
      _currentPage = 1;
      _resolvedDocumentData = nextData;

      if (previousDocumentId != null &&
          previousDocumentId != document.documentId) {
        await _bridge.closeDocument(previousDocumentId);
      }
      if (previousCache != null && !identical(previousCache, nextCache)) {
        previousCache.dispose();
      }

      return nextData;
    } catch (_) {
      await _bridge.closeDocument(document.documentId);
      rethrow;
    }
  }

  void _handleScroll() {
    if (_pages.isEmpty) {
      return;
    }
    final page = _computeCurrentPage(_verticalController.offset);
    if (page != _currentPage) {
      _currentPage = page;
      _scheduleControllerPageSync(page);
      widget.onPageChanged?.call(page);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _scheduleControllerPageSync(int page) {
    if (_controller.currentPage.value == page) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.currentPage.value == page) {
        return;
      }
      _controller.currentPage.value = page;
    });
  }

  int _computeCurrentPage(double offset) {
    if (!_verticalController.hasClients) {
      return 1;
    }
    final position = _verticalController.position;
    if (position.maxScrollExtent <= 0) {
      return 1;
    }
    if (offset <= position.minScrollExtent + 1) {
      return 1;
    }
    if (offset >= position.maxScrollExtent - 1) {
      return _pages.length;
    }

    final width = _effectiveViewportWidth;
    final viewportCenter = offset + (position.viewportDimension / 2);
    var pageStart = 0.0;

    for (var index = 0; index < _pages.length; index++) {
      final pageHeight = _pageHeightFor(_pages[index], width);
      final pageEnd = pageStart + pageHeight;
      if (viewportCenter <= pageEnd) {
        return index + 1;
      }
      pageStart = pageEnd + _pageSpacing;
    }
    return _pages.length;
  }

  double get _effectiveViewportWidth =>
      (_viewportWidth > 0 ? _viewportWidth : 360) - 32;

  double _pageHeightFor(PdfPageInfo page, double baseWidth) {
    final scaledWidth = baseWidth * _zoom;
    return scaledWidth * (page.height / page.width);
  }

  @override
  Future<void> jumpToPage(int pageNumber) async {
    if (_pages.isEmpty) {
      return;
    }
    final clampedPage = pageNumber.clamp(1, _pages.length);
    final width = _effectiveViewportWidth;
    var offset = 0.0;
    for (var index = 0; index < clampedPage - 1; index++) {
      offset += _pageHeightFor(_pages[index], width) + _pageSpacing;
    }
    await _verticalController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _verticalController.removeListener(_handleScroll);
    _verticalController.dispose();
    _horizontalController.dispose();
    _cache?.dispose();
    final documentId = _documentId;
    if (documentId != null) {
      unawaited(_bridge.closeDocument(documentId));
    }
    _controller.detach(this);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final showToolbar =
            !hasBoundedHeight ||
            constraints.maxHeight >= _minimumHeightForViewerToolbar;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.toDouble()
            : 360.0;
        if (_viewportWidth != width) {
          _viewportWidth = width;
        }

        return FutureBuilder<_PdfViewerDocumentData>(
          future: _documentFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return widget.errorBuilder?.call(context, snapshot.error!) ??
                  Center(child: Text('Failed to open PDF: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              final resolvedData = _resolvedDocumentData;
              final cache = _cache;
              if (resolvedData != null && cache != null) {
                return _buildViewerContent(
                  data: resolvedData,
                  cache: cache,
                  hasBoundedHeight: hasBoundedHeight,
                  showToolbar: showToolbar,
                );
              }
              return widget.loading ??
                  const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final cache = _cache;
            if (cache == null) {
              return widget.loading ??
                  const Center(child: CircularProgressIndicator());
            }
            return _buildViewerContent(
              data: data,
              cache: cache,
              hasBoundedHeight: hasBoundedHeight,
              showToolbar: showToolbar,
            );
          },
        );
      },
    );
  }

  Widget _buildViewerContent({
    required _PdfViewerDocumentData data,
    required _RenderedPageCache cache,
    required bool hasBoundedHeight,
    required bool showToolbar,
  }) {
    final viewerBody = Container(
      key: _viewportKey,
      color: const Color(0xFFE6E8EC),
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _effectiveViewportWidth * _zoom + 32,
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _verticalController,
                padding: const EdgeInsets.all(16),
                itemCount: data.pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: _pageSpacing),
                    child: _PdfViewerPageTile(
                      pageInfo: data.pages[index],
                      zoom: _zoom,
                      cacheExtent: widget.cacheExtent,
                      currentPage: _currentPage,
                      cache: cache,
                      viewportWidth: _effectiveViewportWidth,
                      onTap: widget.onPageTap,
                      overlayBuilder: widget.pageOverlayBuilder,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (showToolbar)
          _PdfViewerToolbar(
            currentPage: _currentPage,
            pageCount: data.document.pageCount,
            zoom: _zoom,
            minZoom: widget.minZoom,
            maxZoom: widget.maxZoom,
            onPreviousPage: _currentPage > 1
                ? () => jumpToPage(_currentPage - 1)
                : null,
            onNextPage: _currentPage < data.document.pageCount
                ? () => jumpToPage(_currentPage + 1)
                : null,
            onZoomChanged: (value) {
              setState(() {
                _zoom = value;
              });
            },
          ),
        if (showToolbar) const SizedBox(height: 8),
        if (hasBoundedHeight)
          Expanded(child: viewerBody)
        else
          SizedBox(height: _defaultUnboundedViewerHeight, child: viewerBody),
      ],
    );
  }
}

class _PdfViewerToolbar extends StatelessWidget {
  const _PdfViewerToolbar({
    required this.currentPage,
    required this.pageCount,
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onZoomChanged,
  });

  final int currentPage;
  final int pageCount;
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onPreviousPage,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('$currentPage / $pageCount'),
            IconButton(
              onPressed: onNextPage,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 8),
            const Text('Zoom'),
            Expanded(
              child: Slider(
                value: zoom,
                min: minZoom,
                max: maxZoom,
                divisions: ((maxZoom - minZoom) * 4).round().clamp(1, 20),
                label: '${zoom.toStringAsFixed(2)}x',
                onChanged: onZoomChanged,
              ),
            ),
            Text('${zoom.toStringAsFixed(2)}x'),
          ],
        ),
      ),
    );
  }
}

class _PdfViewerPageTile extends StatefulWidget {
  const _PdfViewerPageTile({
    required this.pageInfo,
    required this.zoom,
    required this.cacheExtent,
    required this.currentPage,
    required this.cache,
    required this.viewportWidth,
    required this.onTap,
    required this.overlayBuilder,
  });

  final PdfPageInfo pageInfo;
  final double zoom;
  final int cacheExtent;
  final int currentPage;
  final _RenderedPageCache cache;
  final double viewportWidth;
  final ValueChanged<PdfPageTapDetails>? onTap;
  final PdfPageOverlayBuilder? overlayBuilder;

  @override
  State<_PdfViewerPageTile> createState() => _PdfViewerPageTileState();
}

class _PdfViewerPageTileState extends State<_PdfViewerPageTile> {
  Future<PdfRenderedPage>? _renderFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _PdfViewerPageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pageDistance = (widget.pageInfo.pageIndex + 1 - widget.currentPage)
        .abs();
    final oldDistance =
        (oldWidget.pageInfo.pageIndex + 1 - oldWidget.currentPage).abs();
    if (oldWidget.zoom != widget.zoom ||
        !identical(oldWidget.cache, widget.cache) ||
        oldWidget.pageInfo.documentId != widget.pageInfo.documentId ||
        (pageDistance <= widget.cacheExtent &&
            oldDistance > oldWidget.cacheExtent)) {
      _refresh();
    }
  }

  void _refresh() {
    _renderFuture = widget.cache.getPage(
      pageIndex: widget.pageInfo.pageIndex,
      scale: widget.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.viewportWidth * widget.zoom;
    final height = width * (widget.pageInfo.height / widget.pageInfo.width);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<PdfRenderedPage>(
            future: _renderFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SizedBox(
                  height: height,
                  child: Center(
                    child: Text(
                      'Failed to render page ${widget.pageInfo.pageIndex + 1}',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return SizedBox(
                  height: height,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final viewport = PdfPageViewport(
                pageInfo: widget.pageInfo,
                renderedWidth: width,
                renderedHeight: height,
              );
              final overlay = widget.overlayBuilder?.call(
                context,
                widget.pageInfo,
                viewport,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onTap == null
                    ? null
                    : (details) {
                        final localPosition = PdfPoint(
                          x: details.localPosition.dx,
                          y: details.localPosition.dy,
                        );
                        widget.onTap!(
                          PdfPageTapDetails(
                            pageInfo: widget.pageInfo,
                            viewport: viewport,
                            localPosition: localPosition,
                            pdfPosition: viewport.screenToPdf(localPosition),
                          ),
                        );
                      },
                child: Stack(
                  children: [
                    Image.memory(
                      snapshot.data!.pngBytes,
                      width: width,
                      height: height,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                    if (overlay != null) Positioned.fill(child: overlay),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RenderedPageCache {
  _RenderedPageCache({
    required this.bridge,
    required this.documentId,
    required this.maxEntries,
  });

  final PdfRendererBridge bridge;
  final int documentId;
  final int maxEntries;
  final LinkedHashMap<String, PdfRenderedPage> _pages =
      LinkedHashMap<String, PdfRenderedPage>();
  final Map<String, Future<PdfRenderedPage>> _inFlight =
      <String, Future<PdfRenderedPage>>{};

  Future<PdfRenderedPage> getPage({
    required int pageIndex,
    required double scale,
  }) {
    final cacheKey = '${pageIndex}_${scale.toStringAsFixed(2)}';
    final cached = _pages.remove(cacheKey);
    if (cached != null) {
      _pages[cacheKey] = cached;
      return Future<PdfRenderedPage>.value(cached);
    }

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = bridge
        .renderPage(
          PdfRenderRequest(
            documentId: documentId,
            pageIndex: pageIndex,
            scale: scale,
          ),
        )
        .then((page) {
          _inFlight.remove(cacheKey);
          _pages[cacheKey] = page;
          while (_pages.length > maxEntries) {
            _pages.remove(_pages.keys.first);
          }
          return page;
        });

    _inFlight[cacheKey] = future;
    return future;
  }

  void dispose() {
    _pages.clear();
    _inFlight.clear();
  }
}

final class _PdfViewerDocumentData {
  const _PdfViewerDocumentData({required this.document, required this.pages});

  final PdfDocumentInfo document;
  final List<PdfPageInfo> pages;
}

const double _pageSpacing = 16;
const double _defaultUnboundedViewerHeight = 520;
const double _minimumHeightForViewerToolbar = 96;
