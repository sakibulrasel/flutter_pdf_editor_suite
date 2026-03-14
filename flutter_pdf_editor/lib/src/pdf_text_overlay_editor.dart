import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_pdf_editor_viewer/flutter_pdf_editor_viewer.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

import 'pdf_text_overlay_controller.dart';

class PdfTextOverlayEditor extends StatefulWidget {
  const PdfTextOverlayEditor({
    required this.source,
    required this.controller,
    super.key,
    this.viewerController,
    this.initialZoom = 1,
    this.maxZoom = 3,
  });

  final PdfDocumentSource source;
  final PdfTextOverlayController controller;
  final PdfViewerController? viewerController;
  final double initialZoom;
  final double maxZoom;

  @override
  State<PdfTextOverlayEditor> createState() => _PdfTextOverlayEditorState();
}

class _PdfTextOverlayEditorState extends State<PdfTextOverlayEditor> {
  late final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSelectionText);
    _syncSelectionText();
  }

  @override
  void didUpdateWidget(covariant PdfTextOverlayEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_syncSelectionText);
      widget.controller.addListener(_syncSelectionText);
      _syncSelectionText();
    }
  }

  void _syncSelectionText() {
    final text = widget.controller.selectedOverlay?.text ?? '';
    if (_textController.text == text) {
      return;
    }
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSelectionText);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final selectedOverlay = widget.controller.selectedOverlay;
        return Column(
          children: [
            Expanded(
              child: PdfViewer(
                source: widget.source,
                controller: widget.viewerController,
                initialZoom: widget.initialZoom,
                maxZoom: widget.maxZoom,
                onPageTap: (details) {
                  widget.controller.addOverlay(
                    pageIndex: details.pageInfo.pageIndex,
                    pdfPosition: details.pdfPosition,
                  );
                },
                pageOverlayBuilder: (context, pageInfo, viewport) {
                  final overlays = widget.controller.overlays
                      .where((item) => item.pageIndex == pageInfo.pageIndex)
                      .toList(growable: false);
                  if (overlays.isEmpty) {
                    return null;
                  }
                  return Stack(
                    children: overlays.map((overlay) {
                      return _TextOverlayHandle(
                        overlay: overlay,
                        viewport: viewport,
                        isSelected:
                            widget.controller.selectedOverlayId == overlay.id,
                        onSelect: () {
                          widget.controller.selectOverlay(overlay.id);
                        },
                        onMove: (deltaPdfX, deltaPdfY) {
                          widget.controller.moveOverlay(
                            overlayId: overlay.id,
                            deltaX: deltaPdfX,
                            deltaY: deltaPdfY,
                            pageInfo: pageInfo,
                          );
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            _TextOverlayToolbar(
              textController: _textController,
              selectedOverlay: selectedOverlay,
              onTextChanged: widget.controller.updateSelectedText,
              onFontSizeChanged: widget.controller.updateSelectedFontSize,
              onColorChanged: widget.controller.updateSelectedColor,
              onDelete: widget.controller.deleteSelected,
            ),
          ],
        );
      },
    );
  }
}

class _TextOverlayHandle extends StatelessWidget {
  const _TextOverlayHandle({
    required this.overlay,
    required this.viewport,
    required this.isSelected,
    required this.onSelect,
    required this.onMove,
  });

  final PdfTextOverlay overlay;
  final PdfPageViewport viewport;
  final bool isSelected;
  final VoidCallback onSelect;
  final void Function(double deltaPdfX, double deltaPdfY) onMove;

  @override
  Widget build(BuildContext context) {
    final topLeft = viewport.pdfToScreen(
      PdfPoint(x: overlay.bounds.left, y: overlay.bounds.top),
    );
    final bottomRight = viewport.pdfToScreen(
      PdfPoint(x: overlay.bounds.right, y: overlay.bounds.bottom),
    );
    final width = math.max(bottomRight.x - topLeft.x, 32).toDouble();
    final height = math.max(bottomRight.y - topLeft.y, 20).toDouble();

    return Positioned(
      left: topLeft.x,
      top: topLeft.y,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: onSelect,
        onPanStart: (_) => onSelect(),
        onPanUpdate: (details) {
          final scaleX = viewport.pageInfo.width / viewport.renderedWidth;
          final scaleY = viewport.pageInfo.height / viewport.renderedHeight;
          onMove(details.delta.dx * scaleX, details.delta.dy * scaleY);
        },
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0x00000000),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            overlay.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(overlay.color),
              fontSize: overlay.fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextOverlayToolbar extends StatelessWidget {
  const _TextOverlayToolbar({
    required this.textController,
    required this.selectedOverlay,
    required this.onTextChanged,
    required this.onFontSizeChanged,
    required this.onColorChanged,
    required this.onDelete,
  });

  final TextEditingController textController;
  final PdfTextOverlay? selectedOverlay;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<int> onColorChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedOverlay != null;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              enabled: hasSelection,
              decoration: const InputDecoration(
                labelText: 'Selected text overlay',
                hintText: 'Tap a page to add text, then edit it here',
              ),
              onChanged: onTextChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Font size'),
                Expanded(
                  child: Slider(
                    value: selectedOverlay?.fontSize ?? 16,
                    min: 10,
                    max: 32,
                    divisions: 11,
                    onChanged: hasSelection ? onFontSizeChanged : null,
                  ),
                ),
                IconButton(
                  onPressed: hasSelection ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colorChoices.map((color) {
                final isSelected = selectedOverlay?.color == color;
                return GestureDetector(
                  onTap: hasSelection ? () => onColorChanged(color) : null,
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF111827)
                            : const Color(0x00000000),
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

const List<int> _colorChoices = <int>[
  0xFF111827,
  0xFF2563EB,
  0xFFDC2626,
  0xFF059669,
];
