import 'package:flutter/foundation.dart';

/// Controls a [PdfViewer] and exposes lightweight viewer state.
class PdfViewerController {
  /// Notifies listeners with the current 1-based visible page number.
  final ValueNotifier<int> currentPage = ValueNotifier<int>(1);

  PdfViewerControllerBinding? _binding;

  /// Attaches the controller to a live viewer binding.
  void attach(PdfViewerControllerBinding binding) {
    _binding = binding;
  }

  /// Detaches the controller from a viewer binding.
  void detach(PdfViewerControllerBinding binding) {
    if (identical(_binding, binding)) {
      _binding = null;
    }
  }

  /// Scrolls the attached viewer to the given 1-based page number.
  Future<void> jumpToPage(int pageNumber) async {
    await _binding?.jumpToPage(pageNumber);
  }

  /// Releases notifier resources owned by this controller.
  void dispose() {
    currentPage.dispose();
  }
}

/// Binding implemented by [PdfViewer] to service controller commands.
abstract interface class PdfViewerControllerBinding {
  /// Scrolls the viewer to the given 1-based page number.
  Future<void> jumpToPage(int pageNumber);
}
