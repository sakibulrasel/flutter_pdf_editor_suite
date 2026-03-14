import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdf_editor_viewer/flutter_pdf_editor_viewer.dart';
// Needed for lower-bound compatibility with flutter_pdf_editor_viewer 0.0.1.
// ignore: unnecessary_import
import 'package:pdf_engine_core/pdf_engine_core.dart';

import 'pdf_overlay_editor_controller.dart';
import 'signature_pad_dialog.dart';

/// Freeform overlay editor for blank-document authoring and annotations.
class PdfOverlayEditor extends StatefulWidget {
  /// Creates an overlay editor bound to a PDF [source] and [controller].
  const PdfOverlayEditor({
    required this.source,
    required this.controller,
    super.key,
    this.viewerController,
    this.initialZoom = 1,
    this.maxZoom = 3,
    this.initialSignaturePngBytes,
    this.onPickImageBytes,
  });

  /// Source PDF to display.
  final PdfDocumentSource source;

  /// Controller storing overlay state.
  final PdfOverlayEditorController controller;

  /// Optional viewer controller.
  final PdfViewerController? viewerController;

  /// Initial zoom level.
  final double initialZoom;

  /// Maximum allowed zoom level.
  final double maxZoom;

  /// Optional initial signature image.
  final Uint8List? initialSignaturePngBytes;

  /// Optional callback used to pick image bytes for the image tool.
  final Future<Uint8List?> Function()? onPickImageBytes;

  @override
  State<PdfOverlayEditor> createState() => _PdfOverlayEditorState();
}

class _PdfOverlayEditorState extends State<PdfOverlayEditor> {
  late final TextEditingController _textController = TextEditingController();
  late final TextEditingController _serializedStateController =
      TextEditingController();
  Uint8List? _signatureBytes;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _signatureBytes = widget.initialSignaturePngBytes;
    widget.controller.addListener(_syncSelectionText);
    _syncSelectionText();
  }

  @override
  void didUpdateWidget(covariant PdfOverlayEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_syncSelectionText);
      widget.controller.addListener(_syncSelectionText);
      _syncSelectionText();
    }
    if (oldWidget.initialSignaturePngBytes != widget.initialSignaturePngBytes &&
        widget.initialSignaturePngBytes != null) {
      _signatureBytes = widget.initialSignaturePngBytes;
    }
  }

  void _syncSelectionText() {
    final overlay = widget.controller.selectedOverlay;
    final text = overlay is PdfTextOverlay ? overlay.text : '';
    if (_textController.text == text) {
      return;
    }
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _syncSerializedState() {
    _serializedStateController.text = widget.controller.serializeStateJson();
  }

  Future<void> _editSelectedTextOverlay() async {
    final overlay = widget.controller.selectedOverlay;
    if (overlay is! PdfTextOverlay) {
      return;
    }
    final nextText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _OverlayTextEditorSheet(initialText: overlay.text),
    );
    if (!mounted || nextText == null) {
      return;
    }
    widget.controller.updateSelectedText(nextText);
  }

  Future<void> _handleToolChanged(PdfOverlayTool tool) async {
    if (tool == PdfOverlayTool.image) {
      final imageBytes = await _ensureImageBytes();
      if (!mounted || imageBytes == null) {
        return;
      }
      widget.controller.setActiveTool(tool);
      return;
    }
    if (tool != PdfOverlayTool.signature) {
      widget.controller.setActiveTool(tool);
      return;
    }

    final signatureBytes = await _ensureSignatureBytes();
    if (!mounted || signatureBytes == null) {
      return;
    }
    widget.controller.setActiveTool(PdfOverlayTool.signature);
  }

  Future<Uint8List?> _ensureSignatureBytes() async {
    if (_signatureBytes != null) {
      return _signatureBytes;
    }
    return _editSignature();
  }

  Future<Uint8List?> _ensureImageBytes() async {
    if (_imageBytes != null) {
      return _imageBytes;
    }
    return _pickImageBytes();
  }

  Future<Uint8List?> _editSignature() async {
    final signatureBytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => SignaturePadDialog(initialBytes: _signatureBytes),
    );
    if (!mounted || signatureBytes == null) {
      return signatureBytes;
    }
    setState(() {
      _signatureBytes = signatureBytes;
    });
    return signatureBytes;
  }

  Future<Uint8List?> _pickImageBytes() async {
    final picker = widget.onPickImageBytes;
    if (picker == null) {
      return null;
    }
    final imageBytes = await picker();
    if (!mounted || imageBytes == null) {
      return imageBytes;
    }
    setState(() {
      _imageBytes = imageBytes;
    });
    return imageBytes;
  }

  Future<void> _showInspectorSheet(PdfOverlayItem? selectedOverlay) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: _OverlayInspector(
              textController: _textController,
              serializedStateController: _serializedStateController,
              selectedOverlay: selectedOverlay,
              hasSignatureBytes: _signatureBytes != null,
              onEditText: _editSelectedTextOverlay,
              onWidthChanged: (value) =>
                  widget.controller.updateSelectedSize(width: value),
              onHeightChanged: (value) =>
                  widget.controller.updateSelectedSize(height: value),
              onFontSizeChanged: widget.controller.updateSelectedFontSize,
              onColorChanged: widget.controller.updateSelectedColor,
              onDelete: widget.controller.deleteSelected,
              onEditSignature: selectedOverlay is PdfSignatureOverlay
                  ? () async {
                      final signatureBytes = await _editSignature();
                      if (signatureBytes == null) {
                        return;
                      }
                      widget.controller.updateSelectedSignature(signatureBytes);
                    }
                  : null,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSelectionText);
    _textController.dispose();
    _serializedStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final selectedOverlay = widget.controller.selectedOverlay;
        return LayoutBuilder(
          builder: (context, constraints) {
            final compactMode =
                constraints.maxHeight.isFinite &&
                constraints.maxHeight < _compactEditorHeightThreshold;
            return Column(
              children: [
                _OverlayToolBar(
                  activeTool: widget.controller.activeTool,
                  signatureEnabled: _signatureBytes != null,
                  imageEnabled: widget.onPickImageBytes != null,
                  onToolChanged: _handleToolChanged,
                  canUndo: widget.controller.canUndo,
                  canRedo: widget.controller.canRedo,
                  onUndo: widget.controller.undo,
                  onRedo: widget.controller.redo,
                  onExportState: () {
                    _syncSerializedState();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Overlay state exported to the editor panel.',
                        ),
                      ),
                    );
                  },
                  onImportState: () {
                    widget.controller.restoreStateJson(
                      _serializedStateController.text,
                    );
                  },
                  onEditSignature: _editSignature,
                  onPickImage: _pickImageBytes,
                ),
                SizedBox(height: compactMode ? 2 : 8),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: PdfViewer(
                          source: widget.source,
                          controller: widget.viewerController,
                          initialZoom: widget.initialZoom,
                          maxZoom: widget.maxZoom,
                          onPageTap: (details) {
                            final addOverlay = () =>
                                widget.controller.addOverlayForTap(
                                  pageIndex: details.pageInfo.pageIndex,
                                  pdfPosition: details.pdfPosition,
                                  signaturePngBytes: _signatureBytes,
                                  imageBytes: _imageBytes,
                                );
                            if (widget.controller.activeTool ==
                                    PdfOverlayTool.signature &&
                                _signatureBytes == null) {
                              _editSignature().then((signatureBytes) {
                                if (!mounted || signatureBytes == null) {
                                  return;
                                }
                                addOverlay();
                              });
                              return;
                            }
                            if (widget.controller.activeTool ==
                                    PdfOverlayTool.image &&
                                _imageBytes == null) {
                              _pickImageBytes().then((imageBytes) {
                                if (!mounted || imageBytes == null) {
                                  return;
                                }
                                addOverlay();
                              });
                              return;
                            }
                            addOverlay();
                          },
                          pageOverlayBuilder: (context, pageInfo, viewport) {
                            final overlays = widget.controller.overlays
                                .where(
                                  (item) =>
                                      item.pageIndex == pageInfo.pageIndex,
                                )
                                .toList(growable: false);
                            if (overlays.isEmpty) {
                              return null;
                            }
                            return Stack(
                              clipBehavior: Clip.none,
                              children: overlays.map((overlay) {
                                return _OverlayHandle(
                                  overlay: overlay,
                                  viewport: viewport,
                                  isSelected:
                                      widget.controller.selectedOverlayId ==
                                      overlay.id,
                                  onSelect: () => widget.controller
                                      .selectOverlay(overlay.id),
                                  onMove: (deltaPdfX, deltaPdfY) {
                                    widget.controller.beginInteraction();
                                    widget.controller.moveOverlay(
                                      overlayId: overlay.id,
                                      deltaX: deltaPdfX,
                                      deltaY: deltaPdfY,
                                      pageInfo: pageInfo,
                                    );
                                  },
                                  onResize: (deltaPdfWidth, deltaPdfHeight) {
                                    widget.controller.beginInteraction();
                                    widget.controller.resizeOverlay(
                                      overlayId: overlay.id,
                                      deltaWidth: deltaPdfWidth,
                                      deltaHeight: deltaPdfHeight,
                                      pageInfo: pageInfo,
                                    );
                                  },
                                  onGestureCommit:
                                      widget.controller.endInteraction,
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                      if (compactMode)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _showInspectorSheet(selectedOverlay),
                            icon: const Icon(Icons.tune),
                            label: Text(
                              selectedOverlay == null ? 'Tools' : 'Edit',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!compactMode)
                  Flexible(
                    fit: FlexFit.loose,
                    child: _OverlayInspector(
                      textController: _textController,
                      serializedStateController: _serializedStateController,
                      selectedOverlay: selectedOverlay,
                      hasSignatureBytes: _signatureBytes != null,
                      onEditText: _editSelectedTextOverlay,
                      onWidthChanged: (value) =>
                          widget.controller.updateSelectedSize(width: value),
                      onHeightChanged: (value) =>
                          widget.controller.updateSelectedSize(height: value),
                      onFontSizeChanged:
                          widget.controller.updateSelectedFontSize,
                      onColorChanged: widget.controller.updateSelectedColor,
                      onDelete: widget.controller.deleteSelected,
                      onEditSignature: selectedOverlay is PdfSignatureOverlay
                          ? () async {
                              final signatureBytes = await _editSignature();
                              if (signatureBytes == null) {
                                return;
                              }
                              widget.controller.updateSelectedSignature(
                                signatureBytes,
                              );
                            }
                          : null,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _OverlayToolBar extends StatelessWidget {
  const _OverlayToolBar({
    required this.activeTool,
    required this.signatureEnabled,
    required this.imageEnabled,
    required this.onToolChanged,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onExportState,
    required this.onImportState,
    required this.onEditSignature,
    required this.onPickImage,
  });

  final PdfOverlayTool activeTool;
  final bool signatureEnabled;
  final bool imageEnabled;
  final ValueChanged<PdfOverlayTool> onToolChanged;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onExportState;
  final VoidCallback onImportState;
  final Future<void> Function() onEditSignature;
  final Future<Uint8List?> Function() onPickImage;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _ToolChip(
        label: 'Text',
        selected: activeTool == PdfOverlayTool.text,
        onTap: () => onToolChanged(PdfOverlayTool.text),
      ),
      _ToolChip(
        label: 'Check',
        selected: activeTool == PdfOverlayTool.checkmark,
        onTap: () => onToolChanged(PdfOverlayTool.checkmark),
      ),
      _ToolChip(
        label: 'Signature',
        selected: activeTool == PdfOverlayTool.signature,
        enabled: signatureEnabled,
        onTap: signatureEnabled
            ? () => onToolChanged(PdfOverlayTool.signature)
            : null,
      ),
      _ToolChip(
        label: 'Rect',
        selected: activeTool == PdfOverlayTool.rectangle,
        onTap: () => onToolChanged(PdfOverlayTool.rectangle),
      ),
      _ToolChip(
        label: 'Image',
        selected: activeTool == PdfOverlayTool.image,
        enabled: imageEnabled,
        onTap: imageEnabled ? () => onToolChanged(PdfOverlayTool.image) : null,
      ),
      IconButton(
        onPressed: canUndo ? onUndo : null,
        icon: const Icon(Icons.undo),
        tooltip: 'Undo',
      ),
      IconButton(
        onPressed: canRedo ? onRedo : null,
        icon: const Icon(Icons.redo),
        tooltip: 'Redo',
      ),
      IconButton(
        onPressed: onExportState,
        icon: const Icon(Icons.file_upload_outlined),
        tooltip: 'Export state',
      ),
      IconButton(
        onPressed: onImportState,
        icon: const Icon(Icons.file_download_outlined),
        tooltip: 'Import state',
      ),
      IconButton(
        onPressed: onEditSignature,
        icon: const Icon(Icons.draw_outlined),
        tooltip: 'Edit signature',
      ),
      IconButton(
        onPressed: imageEnabled ? onPickImage : null,
        icon: const Icon(Icons.image_outlined),
        tooltip: 'Pick image',
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Center(child: items[index]),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap?.call() : null,
    );
  }
}

class _OverlayHandle extends StatelessWidget {
  const _OverlayHandle({
    required this.overlay,
    required this.viewport,
    required this.isSelected,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
    required this.onGestureCommit,
  });

  final PdfOverlayItem overlay;
  final PdfPageViewport viewport;
  final bool isSelected;
  final VoidCallback onSelect;
  final void Function(double deltaPdfX, double deltaPdfY) onMove;
  final void Function(double deltaPdfWidth, double deltaPdfHeight) onResize;
  final VoidCallback onGestureCommit;

  @override
  Widget build(BuildContext context) {
    final topLeft = viewport.pdfToScreen(
      PdfPoint(x: overlay.bounds.left, y: overlay.bounds.top),
    );
    final bottomRight = viewport.pdfToScreen(
      PdfPoint(x: overlay.bounds.right, y: overlay.bounds.bottom),
    );
    final width = math.max(bottomRight.x - topLeft.x, 20).toDouble();
    final height = math.max(bottomRight.y - topLeft.y, 20).toDouble();

    return Positioned(
      left: topLeft.x,
      top: topLeft.y,
      width: width,
      height: height,
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onSelect,
                onPanStart: (_) => onSelect(),
                onPanUpdate: (details) {
                  final scaleX =
                      viewport.pageInfo.width / viewport.renderedWidth;
                  final scaleY =
                      viewport.pageInfo.height / viewport.renderedHeight;
                  onMove(details.delta.dx * scaleX, details.delta.dy * scaleY);
                },
                onPanEnd: (_) => onGestureCommit(),
                onPanCancel: onGestureCommit,
                child: _OverlayVisual(overlay: overlay, isSelected: isSelected),
              ),
            ),
            if (isSelected)
              Positioned(
                right: -14,
                bottom: -14,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    final scaleX =
                        viewport.pageInfo.width / viewport.renderedWidth;
                    final scaleY =
                        viewport.pageInfo.height / viewport.renderedHeight;
                    onResize(
                      details.delta.dx * scaleX,
                      details.delta.dy * scaleY,
                    );
                  },
                  onPanEnd: (_) => onGestureCommit(),
                  onPanCancel: onGestureCommit,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlayVisual extends StatelessWidget {
  const _OverlayVisual({required this.overlay, required this.isSelected});

  final PdfOverlayItem overlay;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: overlay is PdfSignatureOverlay
          ? Colors.transparent
          : overlay is PdfRectangleOverlay
          ? Color(
              (overlay as PdfRectangleOverlay).color,
            ).withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.88),
      border: Border.all(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0x00000000),
        width: 2,
      ),
      borderRadius: BorderRadius.circular(4),
    );

    return Container(
      alignment: Alignment.centerLeft,
      padding: overlay is PdfSignatureOverlay
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: decoration,
      child: switch (overlay) {
        PdfTextOverlay overlay => Text(
          overlay.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(overlay.color),
            fontSize: overlay.fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        PdfCheckmarkOverlay overlay => FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: Text(
            '✓',
            style: TextStyle(
              color: Color(overlay.color),
              fontSize: math.max(overlay.bounds.width, overlay.bounds.height),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        PdfSignatureOverlay overlay => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            overlay.pngBytes,
            fit: BoxFit.fill,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        PdfRectangleOverlay overlay => Container(
          decoration: BoxDecoration(
            color: Color(overlay.color).withValues(alpha: 0.08),
            border: Border.all(color: Color(overlay.color), width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        PdfImageOverlay overlay => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            overlay.imageBytes,
            fit: BoxFit.fill,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _OverlayInspector extends StatelessWidget {
  const _OverlayInspector({
    required this.textController,
    required this.serializedStateController,
    required this.selectedOverlay,
    required this.hasSignatureBytes,
    required this.onEditText,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onFontSizeChanged,
    required this.onColorChanged,
    required this.onDelete,
    required this.onEditSignature,
  });

  final TextEditingController textController;
  final TextEditingController serializedStateController;
  final PdfOverlayItem? selectedOverlay;
  final bool hasSignatureBytes;
  final Future<void> Function() onEditText;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<int> onColorChanged;
  final VoidCallback onDelete;
  final Future<void> Function()? onEditSignature;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedOverlay != null;
    final selectedText = selectedOverlay is PdfTextOverlay
        ? selectedOverlay as PdfTextOverlay
        : null;
    final selectedWidth = selectedOverlay?.bounds.width;
    final selectedHeight = selectedOverlay?.bounds.height;
    final selectedColor = switch (selectedOverlay) {
      PdfTextOverlay(:final color) => color,
      PdfCheckmarkOverlay(:final color) => color,
      PdfRectangleOverlay(:final color) => color,
      _ => null,
    };

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedText != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        textController.text.isEmpty
                            ? 'Selected text overlay'
                            : textController.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: onEditText,
                      child: const Text('Edit Text'),
                    ),
                  ],
                )
              else if (selectedOverlay is PdfSignatureOverlay)
                Row(
                  children: [
                    const Expanded(child: Text('Selected signature overlay')),
                    TextButton.icon(
                      onPressed: onEditSignature,
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Replace'),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hasSelection
                        ? 'Selected ${selectedOverlay!.type.name} overlay'
                        : 'Tap a page to place the selected overlay type',
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Width'),
                  Expanded(
                    child: Slider(
                      value: ((selectedWidth ?? 80).clamp(24, 320)).toDouble(),
                      min: 24,
                      max: 320,
                      divisions: 74,
                      onChanged: hasSelection ? onWidthChanged : null,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Height'),
                  Expanded(
                    child: Slider(
                      value: ((selectedHeight ?? 40).clamp(20, 220)).toDouble(),
                      min: 20,
                      max: 220,
                      divisions: 50,
                      onChanged: hasSelection ? onHeightChanged : null,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Font'),
                  Expanded(
                    child: Slider(
                      value: selectedText?.fontSize ?? 18,
                      min: 10,
                      max: 32,
                      divisions: 11,
                      onChanged: selectedText != null
                          ? onFontSizeChanged
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: hasSelection ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _overlayColors.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: selectedColor != null
                        ? () => onColorChanged(color)
                        : null,
                    child: Container(
                      width: 28,
                      height: 28,
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
              const SizedBox(height: 12),
              TextField(
                controller: serializedStateController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Overlay state JSON',
                  hintText: 'Use export/import from the toolbar',
                ),
              ),
              if (hasSignatureBytes && selectedOverlay == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Signature is ready for placement.'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayTextEditorSheet extends StatefulWidget {
  const _OverlayTextEditorSheet({required this.initialText});

  final String initialText;

  @override
  State<_OverlayTextEditorSheet> createState() =>
      _OverlayTextEditorSheetState();
}

class _OverlayTextEditorSheetState extends State<_OverlayTextEditorSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Text',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter text',
              ),
              onSubmitted: (value) =>
                  Navigator.of(context).pop(value.trimRight()),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trimRight()),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<int> _overlayColors = <int>[
  0xFF111827,
  0xFF2563EB,
  0xFFDC2626,
  0xFF059669,
];

const double _compactEditorHeightThreshold = 320;
