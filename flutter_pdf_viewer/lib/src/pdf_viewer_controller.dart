import 'package:flutter/foundation.dart';

class PdfViewerController {
  final ValueNotifier<int> currentPage = ValueNotifier<int>(1);

  PdfViewerControllerBinding? _binding;

  void attach(PdfViewerControllerBinding binding) {
    _binding = binding;
  }

  void detach(PdfViewerControllerBinding binding) {
    if (identical(_binding, binding)) {
      _binding = null;
    }
  }

  Future<void> jumpToPage(int pageNumber) async {
    await _binding?.jumpToPage(pageNumber);
  }

  void dispose() {
    currentPage.dispose();
  }
}

abstract interface class PdfViewerControllerBinding {
  Future<void> jumpToPage(int pageNumber);
}
