## 0.0.5

- Added configurable `helperText` support to `PdfEditorConfig`.
- Added a proper empty state when `createBlankDocumentOnStart` is `false` and no initial PDF is provided.
- Updated package dependencies to the latest published `pdf_engine_core`, `pdf_renderer_bridge`, and `flutter_pdf_editor_viewer` releases.

## 0.0.4

- Added `PdfEditorScreen`, `PdfEditorConfig`, and `PdfEditorAction` for a one-package configurable editor UI.
- Moved file open, create, flatten export, editable export, share, and open-file flows into the high-level screen API.
- Updated package dependencies and docs for the new single-package editor experience.

## 0.0.3

- Fixed lower-bound dependency analysis by restoring direct core type imports where needed.
- Corrected release changelog history for the public package.

## 0.0.2

- Added dartdoc coverage across the public editor API.
- Added a working package example app.
- Fixed package analysis and publish metadata issues for the public release.

## 0.0.1

- Initial public release of PDF editing widgets and exporters.
- Added overlay editing, form editing, flattened export, editable classic AcroForm save, and blank-PDF authoring entry points.
