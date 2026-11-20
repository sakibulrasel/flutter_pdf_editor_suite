## 0.1.0

- Updated to `pdf_engine_core` 1.1.0 and `pdf_renderer_bridge` 0.1.0; viewer errors passed to `errorBuilder` are now typed `PdfException`s.
- Raised the Flutter constraint to `>=3.38.0` to match the Dart `^3.10.4` SDK constraint.

## 0.0.2

- Re-exported `pdf_engine_core` from the main library so apps can use a single import.
- Updated docs for single-package usage.

## 0.0.1

- Initial public release of PDF viewer widgets.
- Added scrollable viewer, page view support, controller, zoom, page overlays, and tap handling.
