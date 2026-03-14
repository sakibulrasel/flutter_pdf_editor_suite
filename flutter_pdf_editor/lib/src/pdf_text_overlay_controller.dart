import 'package:flutter/foundation.dart';
import 'package:pdf_engine_core/pdf_engine_core.dart';

class PdfTextOverlayController extends ChangeNotifier {
  final List<PdfTextOverlay> _overlays = <PdfTextOverlay>[];
  int _nextOverlayId = 1;
  String? _selectedOverlayId;

  List<PdfTextOverlay> get overlays =>
      List<PdfTextOverlay>.unmodifiable(_overlays);

  String? get selectedOverlayId => _selectedOverlayId;

  PdfTextOverlay addOverlay({
    required int pageIndex,
    required PdfPoint pdfPosition,
    String text = 'Text',
    double width = 72,
    double height = 24,
    double fontSize = 16,
    int color = 0xFF111827,
  }) {
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

  void selectOverlay(String? overlayId) {
    if (_selectedOverlayId == overlayId) {
      return;
    }
    _selectedOverlayId = overlayId;
    notifyListeners();
  }

  void updateOverlay(PdfTextOverlay overlay) {
    final index = _overlays.indexWhere((item) => item.id == overlay.id);
    if (index == -1) {
      return;
    }
    _overlays[index] = overlay;
    notifyListeners();
  }

  void moveOverlay({
    required String overlayId,
    required double deltaX,
    required double deltaY,
    required PdfPageInfo pageInfo,
  }) {
    final overlay = _findOverlayById(overlayId);
    if (overlay == null) {
      return;
    }
    updateOverlay(
      overlay.copyWith(
        bounds: overlay.bounds
            .translate(deltaX, deltaY)
            .clampWithin(maxWidth: pageInfo.width, maxHeight: pageInfo.height),
      ),
    );
  }

  void updateSelectedText(String text) {
    final overlay = selectedOverlay;
    if (overlay == null) {
      return;
    }
    updateOverlay(overlay.copyWith(text: text));
  }

  void updateSelectedFontSize(double fontSize) {
    final overlay = selectedOverlay;
    if (overlay == null) {
      return;
    }
    updateOverlay(overlay.copyWith(fontSize: fontSize));
  }

  void updateSelectedColor(int color) {
    final overlay = selectedOverlay;
    if (overlay == null) {
      return;
    }
    updateOverlay(overlay.copyWith(color: color));
  }

  void deleteSelected() {
    final overlayId = _selectedOverlayId;
    if (overlayId == null) {
      return;
    }
    _overlays.removeWhere((item) => item.id == overlayId);
    _selectedOverlayId = null;
    notifyListeners();
  }

  PdfTextOverlay? get selectedOverlay =>
      _selectedOverlayId == null ? null : _findOverlayById(_selectedOverlayId!);

  PdfTextOverlay? _findOverlayById(String overlayId) {
    for (final overlay in _overlays) {
      if (overlay.id == overlayId) {
        return overlay;
      }
    }
    return null;
  }
}
