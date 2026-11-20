# Phase 8 - Stabilise and Clean Up

Goal: make the published packages honest about what they support and build the
safety net the later phases need.

## Repo Hygiene

- [x] Remove `tmp_print_fields.dart` from the repo root (now `flutter_pdf_editor/tool/print_form_fields.dart`)
- [x] Make links in `docs/checklists/README.md` relative
- [x] Remove the absolute `/Users/...` fixture path from `flutter_pdf_editor` tests
- [x] Rename the Android package to `io.github.sakibulrasel.pdf_renderer_bridge`
- [x] Remove the template-only Linux, macOS and Windows plugin code and declarations
- [x] Align `flutter: ">=3.38.0"` with `sdk: ^3.10.4` in every Flutter package

## Typed Errors

- [x] `PdfException` base class in `pdf_engine_core`
- [x] `PdfInvalidDocumentException`, `PdfFileNotFoundException`, `PdfPasswordRequiredException`
- [x] `PdfUnsupportedFeatureException` with `PdfUnsupportedFeature` (encryption, object streams, xref streams, XFA)
- [x] `PdfUnsupportedPlatformException`, `PdfRenderException`
- [x] Native code reports stable error codes (`password_required`, `file_not_found`, `invalid_pdf`); the bridge maps them to typed exceptions
- [x] iOS detects locked (password-protected) documents
- [x] Editor exceptions extend `PdfException`; `PdfEditableExportException` keeps its type and carries the reason in `cause`

## Up-Front Detection

- [x] `PdfPreflight.inspect` scans for encryption, object streams, xref streams, XFA, classic trailer and revision count
- [x] `PdfAcroFormParser` rejects unreadable files with typed exceptions instead of `StateError` / null-check crashes
- [x] `PdfEditableExporter` rejects files it cannot save incrementally before writing

## Test Corpus

- [x] 27 generated fixtures in `fixtures/pdf/` with `manifest.json` (`tool/generate_fixtures.py`)
- [x] Preflight checked against every fixture
- [x] Parser and editable exporter tested against form, encrypted, compressed, XFA and broken fixtures
- [ ] Add real-world PDFs from Acrobat, Word, Google Docs, Chrome, scanners to `fixtures/real_world/` (needs redistributable files)

## CI

- [x] Pub workspace: root `pubspec.yaml` links all packages and examples; `pubspec_overrides.yaml` files removed
- [x] Examples moved to `share_plus: ^12.0.1` so the whole workspace resolves together
- [x] `tool/ci.sh` runs one root pub get, then format check, analyze and test for all four packages
- [x] GitHub Actions: analyze and test, Android example build, iOS simulator example build
- [x] `dart format --set-exit-if-changed` check in CI; `tool/format.sh` formats everything
- [ ] Run `tool/format.sh` once and commit the result (needs a machine with Flutter)
- [ ] Commit the root `pubspec.lock` after the first `flutter pub get`

## Bug Found by the Corpus

- [x] PDF string escapes were not decoded: `\137` became `137` and `\n` became `n`, so pypdf-written field names and multi-line values saved by the editor read back wrong

## Exit Criteria

- [ ] CI is green on GitHub (first run happens when this branch is pushed)
- [x] Opening any fixture either works or throws a named, documented exception
