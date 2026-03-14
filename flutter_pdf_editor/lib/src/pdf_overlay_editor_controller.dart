import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

/// Tool modes available in the overlay authoring editor.
enum PdfOverlayTool { text, checkmark, signature, rectangle, image }

/// Controller for freeform PDF overlay authoring.
class PdfOverlayEditorController extends ChangeNotifier {
  final List<PdfOverlayItem> _overlays = <PdfOverlayItem>[];
  final List<_OverlayEditorSnapshot> _undoStack = <_OverlayEditorSnapshot>[];
  final List<_OverlayEditorSnapshot> _redoStack = <_OverlayEditorSnapshot>[];
  int _nextOverlayId = 1;
  String? _selectedOverlayId;
  PdfOverlayTool _activeTool = PdfOverlayTool.text;
  _OverlayEditorSnapshot? _interactionStartSnapshot;
  bool _isRestoringState = false;

  /// All current overlay items.
  List<PdfOverlayItem> get overlays =>
      List<PdfOverlayItem>.unmodifiable(_overlays);

  /// Currently selected overlay identifier, if any.
  String? get selectedOverlayId => _selectedOverlayId;

  /// Currently active authoring tool.
  PdfOverlayTool get activeTool => _activeTool;

  /// Whether undo is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Currently selected overlay item, if any.
  PdfOverlayItem? get selectedOverlay =>
      _selectedOverlayId == null ? null : _findOverlayById(_selectedOverlayId!);

  /// Sets the active authoring tool.
  void setActiveTool(PdfOverlayTool tool) {
    if (_activeTool == tool) {
      return;
    }
    _pushUndoSnapshot();
    _activeTool = tool;
    notifyListeners();
  }

  /// Serializes current overlay state to a JSON-compatible map.
  Map<String, Object?> serializeState() {
    return <String, Object?>{
      'activeTool': _activeTool.name,
      'selectedOverlayId': _selectedOverlayId,
      'nextOverlayId': _nextOverlayId,
      'overlays': _overlays.map(_serializeOverlay).toList(growable: false),
    };
  }

  /// Serializes current overlay state to JSON text.
  String serializeStateJson() {
    return jsonEncode(serializeState());
  }

  /// Restores overlay state from a serialized map.
  void restoreState(Map<String, Object?> state) {
    _pushUndoSnapshot();
    _applySerializedState(state);
    _redoStack.clear();
    notifyListeners();
  }

  /// Restores overlay state from JSON text.
  void restoreStateJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('Overlay state JSON must decode to a map.');
    }
    restoreState(Map<String, Object?>.from(decoded.cast<Object?, Object?>()));
  }

  /// Undoes the last change.
  void undo() {
    if (_undoStack.isEmpty) {
      return;
    }
    final currentSnapshot = _createSnapshot();
    final snapshot = _undoStack.removeLast();
    _redoStack.add(currentSnapshot);
    _restoreSnapshot(snapshot);
  }

  /// Redoes the last undone change.
  void redo() {
    if (_redoStack.isEmpty) {
      return;
    }
    final currentSnapshot = _createSnapshot();
    final snapshot = _redoStack.removeLast();
    _undoStack.add(currentSnapshot);
    _restoreSnapshot(snapshot);
  }

  void beginInteraction() {
    _interactionStartSnapshot ??= _createSnapshot();
  }

  void endInteraction() {
    final snapshot = _interactionStartSnapshot;
    _interactionStartSnapshot = null;
    if (snapshot == null) {
      return;
    }
    if (_snapshotEquals(snapshot, _createSnapshot())) {
      return;
    }
    _undoStack.add(snapshot);
    _redoStack.clear();
    notifyListeners();
  }

  PdfOverlayItem? addOverlayForTap({
    required int pageIndex,
    required PdfPoint pdfPosition,
    Uint8List? signaturePngBytes,
    Uint8List? imageBytes,
  }) {
    switch (_activeTool) {
      case PdfOverlayTool.text:
        return addTextOverlay(pageIndex: pageIndex, pdfPosition: pdfPosition);
      case PdfOverlayTool.checkmark:
        return addCheckmarkOverlay(
          pageIndex: pageIndex,
          pdfPosition: pdfPosition,
        );
      case PdfOverlayTool.signature:
        if (signaturePngBytes == null) {
          return null;
        }
        return addSignatureOverlay(
          pageIndex: pageIndex,
          pdfPosition: pdfPosition,
          pngBytes: signaturePngBytes,
        );
      case PdfOverlayTool.rectangle:
        return addRectangleOverlay(
          pageIndex: pageIndex,
          pdfPosition: pdfPosition,
        );
      case PdfOverlayTool.image:
        if (imageBytes == null) {
          return null;
        }
        return addImageOverlay(
          pageIndex: pageIndex,
          pdfPosition: pdfPosition,
          imageBytes: imageBytes,
        );
    }
  }

  PdfTextOverlay addTextOverlay({
    required int pageIndex,
    required PdfPoint pdfPosition,
    String text = 'Text',
    double width = 88,
    double height = 28,
    double fontSize = 16,
    int color = 0xFF111827,
  }) {
    _pushUndoSnapshot();
    final overlay = PdfTextOverlay(
      id: 'text_${_nextOverlayId++}',
      pageIndex: pageIndex,
      bounds: PdfRect(
        left: pdfPosition.x,
        top: pdfPosition.y,
        width: width,
        height: height,
      ),
      text: text,
      fontSize: fontSize,
      color: color,
    );
    _overlays.add(overlay);
    _selectedOverlayId = overlay.id;
    notifyListeners();
    return overlay;
  }

  PdfCheckmarkOverlay addCheckmarkOverlay({
    required int pageIndex,
    required PdfPoint pdfPosition,
    double size = 28,
    int color = 0xFF059669,
  }) {
    _pushUndoSnapshot();
    final overlay = PdfCheckmarkOverlay(
      id: 'check_${_nextOverlayId++}',
      pageIndex: pageIndex,
      bounds: PdfRect(
        left: pdfPosition.x,
        top: pdfPosition.y,
        width: size,
        height: size,
      ),
      color: color,
    );
    _overlays.add(overlay);
    _selectedOverlayId = overlay.id;
    notifyListeners();
    return overlay;
  }

  PdfSignatureOverlay addSignatureOverlay({
    required int pageIndex,
    required PdfPoint pdfPosition,
    required Uint8List pngBytes,
    double width = 120,
    double height = 44,
  }) {
    _pushUndoSnapshot();
    final overlay = PdfSignatureOverlay(
      id: 'sig_${_nextOverlayId++}',
      pageIndex: pageIndex,
      bounds: PdfRect(
        left: pdfPosition.x,
        top: pdfPosition.y,
        width: width,
        height: height,
      ),
      pngBytes: pngBytes,
    );
    _overlays.add(overlay);
    _selectedOverlayId = overlay.id;
    notifyListeners();
    return overlay;
  }

  PdfRectangleOverlay addRectangleOverlay({
    required int pageIndex,
    required PdfPoint pdfPosition,
    double width = 120,
    double height = 60,
    int color = 0xFF2563EB,
  }) {
    _pushUndoSnapshot();
    final overlay = PdfRectangleOverlay(
      id: 'rect_${_nextOverlayId++}',
      pageIndex: pageIndex,
      bounds: PdfRect(
        left: pdfPosition.x,
        top: pdfPosition.y,
        width: width,
        height: height,
      ),
      color: color,
    );
    _overlays.add(overlay);
    _selectedOverlayId = overlay.id;
    notifyListeners();
    return overlay;
  }

  PdfImageOverlay addImageOverlay({
    required int pageIndex,
    required PdfPoint pdfPosition,
    required Uint8List imageBytes,
    double width = 140,
    double height = 100,
  }) {
    _pushUndoSnapshot();
    final overlay = PdfImageOverlay(
      id: 'img_${_nextOverlayId++}',
      pageIndex: pageIndex,
      bounds: PdfRect(
        left: pdfPosition.x,
        top: pdfPosition.y,
        width: width,
        height: height,
      ),
      imageBytes: imageBytes,
    );
    _overlays.add(overlay);
    _selectedOverlayId = overlay.id;
    notifyListeners();
    return overlay;
  }

  void selectOverlay(String? overlayId) {
    if (_selectedOverlayId == overlayId) {
      return;
    }
    _selectedOverlayId = overlayId;
    notifyListeners();
  }

  void moveOverlay({
    required String overlayId,
    required double deltaX,
    required double deltaY,
    required PdfPageInfo pageInfo,
    bool notify = true,
  }) {
    final overlay = _findOverlayById(overlayId);
    if (overlay == null) {
      return;
    }
    _replaceOverlay(
      _copyOverlayWithBounds(
        overlay,
        overlay.bounds
            .translate(deltaX, deltaY)
            .clampWithin(maxWidth: pageInfo.width, maxHeight: pageInfo.height),
      ),
      notify: notify,
    );
  }

  void resizeOverlay({
    required String overlayId,
    required double deltaWidth,
    required double deltaHeight,
    required PdfPageInfo pageInfo,
    bool notify = true,
  }) {
    final overlay = _findOverlayById(overlayId);
    if (overlay == null) {
      return;
    }
    final nextBounds = overlay.bounds
        .resize(
          overlay.bounds.width + deltaWidth,
          overlay.bounds.height + deltaHeight,
        )
        .clampSize(
          minWidth: _minWidthFor(overlay),
          minHeight: _minHeightFor(overlay),
          maxWidth: pageInfo.width,
          maxHeight: pageInfo.height,
        )
        .clampWithin(maxWidth: pageInfo.width, maxHeight: pageInfo.height);
    _replaceOverlay(
      _copyOverlayWithBounds(overlay, nextBounds),
      notify: notify,
    );
  }

  void updateSelectedText(String text) {
    final overlay = selectedOverlay;
    if (overlay is! PdfTextOverlay) {
      return;
    }
    _pushUndoSnapshot();
    _replaceOverlay(overlay.copyWith(text: text));
  }

  void updateSelectedFontSize(double fontSize) {
    final overlay = selectedOverlay;
    if (overlay is! PdfTextOverlay) {
      return;
    }
    _pushUndoSnapshot();
    _replaceOverlay(overlay.copyWith(fontSize: fontSize));
  }

  void updateSelectedColor(int color) {
    final overlay = selectedOverlay;
    _pushUndoSnapshot();
    switch (overlay) {
      case PdfTextOverlay overlay:
        _replaceOverlay(overlay.copyWith(color: color));
      case PdfCheckmarkOverlay overlay:
        _replaceOverlay(overlay.copyWith(color: color));
      case PdfRectangleOverlay overlay:
        _replaceOverlay(overlay.copyWith(color: color));
      default:
        break;
    }
  }

  void updateSelectedSignature(Uint8List pngBytes) {
    final overlay = selectedOverlay;
    if (overlay is! PdfSignatureOverlay) {
      return;
    }
    _pushUndoSnapshot();
    _replaceOverlay(overlay.copyWith(pngBytes: Uint8List.fromList(pngBytes)));
  }

  void updateSelectedSize({double? width, double? height}) {
    final overlay = selectedOverlay;
    if (overlay == null) {
      return;
    }
    final nextBounds = overlay.bounds
        .resize(width ?? overlay.bounds.width, height ?? overlay.bounds.height)
        .clampSize(
          minWidth: _minWidthFor(overlay),
          minHeight: _minHeightFor(overlay),
          maxWidth: 100000,
          maxHeight: 100000,
        );
    _pushUndoSnapshot();
    _replaceOverlay(_copyOverlayWithBounds(overlay, nextBounds));
  }

  void deleteSelected() {
    final overlayId = _selectedOverlayId;
    if (overlayId == null) {
      return;
    }
    _pushUndoSnapshot();
    _overlays.removeWhere((item) => item.id == overlayId);
    _selectedOverlayId = null;
    notifyListeners();
  }

  PdfOverlayItem? _findOverlayById(String overlayId) {
    for (final overlay in _overlays) {
      if (overlay.id == overlayId) {
        return overlay;
      }
    }
    return null;
  }

  void _replaceOverlay(PdfOverlayItem overlay, {bool notify = true}) {
    final index = _overlays.indexWhere((item) => item.id == overlay.id);
    if (index == -1) {
      return;
    }
    _overlays[index] = overlay;
    if (notify) {
      notifyListeners();
    }
  }

  PdfOverlayItem _copyOverlayWithBounds(
    PdfOverlayItem overlay,
    PdfRect bounds,
  ) {
    switch (overlay) {
      case PdfTextOverlay overlay:
        return overlay.copyWith(bounds: bounds);
      case PdfCheckmarkOverlay overlay:
        return overlay.copyWith(bounds: bounds);
      case PdfSignatureOverlay overlay:
        return overlay.copyWith(bounds: bounds);
      case PdfRectangleOverlay overlay:
        return overlay.copyWith(bounds: bounds);
      case PdfImageOverlay overlay:
        return overlay.copyWith(bounds: bounds);
      default:
        throw UnsupportedError(
          'Unsupported overlay type: ${overlay.runtimeType}',
        );
    }
  }

  double _minWidthFor(PdfOverlayItem overlay) {
    return switch (overlay) {
      PdfTextOverlay() => 48,
      PdfCheckmarkOverlay() => 18,
      PdfSignatureOverlay() => 48,
      PdfRectangleOverlay() => 32,
      PdfImageOverlay() => 48,
      _ => 24,
    };
  }

  double _minHeightFor(PdfOverlayItem overlay) {
    return switch (overlay) {
      PdfTextOverlay() => 20,
      PdfCheckmarkOverlay() => 18,
      PdfSignatureOverlay() => 24,
      PdfRectangleOverlay() => 24,
      PdfImageOverlay() => 36,
      _ => 24,
    };
  }

  void _pushUndoSnapshot() {
    if (_isRestoringState || _interactionStartSnapshot != null) {
      return;
    }
    _undoStack.add(_createSnapshot());
    _redoStack.clear();
  }

  _OverlayEditorSnapshot _createSnapshot() {
    return _OverlayEditorSnapshot(
      activeTool: _activeTool,
      selectedOverlayId: _selectedOverlayId,
      nextOverlayId: _nextOverlayId,
      overlays: _overlays.map(_cloneOverlay).toList(growable: false),
    );
  }

  void _restoreSnapshot(_OverlayEditorSnapshot snapshot) {
    _isRestoringState = true;
    _activeTool = snapshot.activeTool;
    _selectedOverlayId = snapshot.selectedOverlayId;
    _nextOverlayId = snapshot.nextOverlayId;
    _overlays
      ..clear()
      ..addAll(snapshot.overlays.map(_cloneOverlay));
    _isRestoringState = false;
    notifyListeners();
  }

  void _applySerializedState(Map<String, Object?> state) {
    _isRestoringState = true;
    try {
      final overlaysData = state['overlays'];
      if (overlaysData is! List) {
        throw const FormatException(
          'Serialized overlay state is missing overlays.',
        );
      }
      final activeToolName =
          state['activeTool'] as String? ?? PdfOverlayTool.text.name;
      _activeTool = PdfOverlayTool.values.firstWhere(
        (tool) => tool.name == activeToolName,
        orElse: () => PdfOverlayTool.text,
      );
      _selectedOverlayId = state['selectedOverlayId'] as String?;
      _nextOverlayId = (state['nextOverlayId'] as num?)?.toInt() ?? 1;
      _overlays
        ..clear()
        ..addAll(
          overlaysData.map((item) {
            if (item is! Map) {
              throw const FormatException(
                'Serialized overlay entry must be a map.',
              );
            }
            return _deserializeOverlay(
              Map<String, Object?>.from(item.cast<Object?, Object?>()),
            );
          }),
        );
    } finally {
      _isRestoringState = false;
    }
  }

  PdfOverlayItem _cloneOverlay(PdfOverlayItem overlay) {
    return switch (overlay) {
      PdfTextOverlay overlay => overlay.copyWith(),
      PdfCheckmarkOverlay overlay => overlay.copyWith(),
      PdfSignatureOverlay overlay => overlay.copyWith(
        pngBytes: Uint8List.fromList(overlay.pngBytes),
      ),
      PdfRectangleOverlay overlay => overlay.copyWith(),
      PdfImageOverlay overlay => overlay.copyWith(
        imageBytes: Uint8List.fromList(overlay.imageBytes),
      ),
      _ => throw UnsupportedError(
        'Unsupported overlay type: ${overlay.runtimeType}',
      ),
    };
  }

  Map<String, Object?> _serializeOverlay(PdfOverlayItem overlay) {
    final base = <String, Object?>{
      'id': overlay.id,
      'type': overlay.type.name,
      'pageIndex': overlay.pageIndex,
      'bounds': <String, Object?>{
        'left': overlay.bounds.left,
        'top': overlay.bounds.top,
        'width': overlay.bounds.width,
        'height': overlay.bounds.height,
      },
      'rotation': overlay.rotation,
    };
    switch (overlay) {
      case PdfTextOverlay overlay:
        base['text'] = overlay.text;
        base['fontSize'] = overlay.fontSize;
        base['color'] = overlay.color;
      case PdfCheckmarkOverlay overlay:
        base['color'] = overlay.color;
      case PdfSignatureOverlay overlay:
        base['pngBase64'] = base64Encode(overlay.pngBytes);
      case PdfRectangleOverlay overlay:
        base['color'] = overlay.color;
      case PdfImageOverlay overlay:
        base['imageBase64'] = base64Encode(overlay.imageBytes);
      default:
        throw UnsupportedError(
          'Unsupported overlay type: ${overlay.runtimeType}',
        );
    }
    return base;
  }

  PdfOverlayItem _deserializeOverlay(Map<String, Object?> map) {
    final boundsMap = map['bounds'];
    if (boundsMap is! Map) {
      throw const FormatException('Serialized overlay is missing bounds.');
    }
    final bounds = PdfRect(
      left: (boundsMap['left'] as num?)?.toDouble() ?? 0,
      top: (boundsMap['top'] as num?)?.toDouble() ?? 0,
      width: (boundsMap['width'] as num?)?.toDouble() ?? 0,
      height: (boundsMap['height'] as num?)?.toDouble() ?? 0,
    );
    final id = map['id'] as String? ?? '';
    final pageIndex = (map['pageIndex'] as num?)?.toInt() ?? 0;
    final rotation = (map['rotation'] as num?)?.toDouble() ?? 0;
    switch (map['type']) {
      case 'text':
        return PdfTextOverlay(
          id: id,
          pageIndex: pageIndex,
          bounds: bounds,
          text: map['text'] as String? ?? 'Text',
          fontSize: (map['fontSize'] as num?)?.toDouble() ?? 16,
          color: (map['color'] as num?)?.toInt() ?? 0xFF111827,
          rotation: rotation,
        );
      case 'checkmark':
        return PdfCheckmarkOverlay(
          id: id,
          pageIndex: pageIndex,
          bounds: bounds,
          color: (map['color'] as num?)?.toInt() ?? 0xFF059669,
          rotation: rotation,
        );
      case 'signature':
        return PdfSignatureOverlay(
          id: id,
          pageIndex: pageIndex,
          bounds: bounds,
          pngBytes: Uint8List.fromList(
            base64Decode(map['pngBase64'] as String? ?? ''),
          ),
          rotation: rotation,
        );
      case 'rectangle':
        return PdfRectangleOverlay(
          id: id,
          pageIndex: pageIndex,
          bounds: bounds,
          color: (map['color'] as num?)?.toInt() ?? 0xFF2563EB,
          rotation: rotation,
        );
      case 'image':
        return PdfImageOverlay(
          id: id,
          pageIndex: pageIndex,
          bounds: bounds,
          imageBytes: Uint8List.fromList(
            base64Decode(map['imageBase64'] as String? ?? ''),
          ),
          rotation: rotation,
        );
      default:
        throw FormatException('Unknown overlay type: ${map['type']}');
    }
  }

  bool _snapshotEquals(
    _OverlayEditorSnapshot left,
    _OverlayEditorSnapshot right,
  ) {
    return left.activeTool == right.activeTool &&
        left.selectedOverlayId == right.selectedOverlayId &&
        left.nextOverlayId == right.nextOverlayId &&
        jsonEncode(
              left.overlays.map(_serializeOverlay).toList(growable: false),
            ) ==
            jsonEncode(
              right.overlays.map(_serializeOverlay).toList(growable: false),
            );
  }
}

final class _OverlayEditorSnapshot {
  const _OverlayEditorSnapshot({
    required this.activeTool,
    required this.selectedOverlayId,
    required this.nextOverlayId,
    required this.overlays,
  });

  final PdfOverlayTool activeTool;
  final String? selectedOverlayId;
  final int nextOverlayId;
  final List<PdfOverlayItem> overlays;
}
