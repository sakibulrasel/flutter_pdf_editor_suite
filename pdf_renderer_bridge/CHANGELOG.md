## 0.1.0

- **Breaking:** errors are now typed `PdfException`s instead of `PlatformException`: `PdfPasswordRequiredException`, `PdfFileNotFoundException`, `PdfInvalidDocumentException`, `PdfRenderException`.
- **Breaking:** removed the Linux, macOS and Windows plugin declarations. They were unimplemented templates; calls on those platforms now throw `PdfUnsupportedPlatformException` with a clear message. Supported platforms: Android and iOS.
- iOS now reports password-protected documents instead of failing later.
- Android package renamed from `com.example.pdf_renderer_bridge` to `io.github.sakibulrasel.pdf_renderer_bridge`.
- Raised the Flutter constraint to `>=3.38.0` to match the Dart `^3.10.4` SDK constraint.

## 0.0.2

- Added dartdoc coverage for the public bridge API and platform interface.
- Cleaned the bundled example app so the package analyzes cleanly.

## 0.0.1

- Initial public release of the Flutter PDF rendering bridge.
- Added document open, page metadata, page render, and close APIs.
