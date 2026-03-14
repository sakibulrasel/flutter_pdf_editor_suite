# Phase 1 - Render a PDF Page

Goal: display a PDF page on screen in Flutter.

## Architecture Decisions

- [x] Use a native rendering bridge instead of attempting a pure Dart renderer
- [x] Confirm `pdf_renderer_bridge` is the rendering integration layer
- [x] Confirm `pdf_engine_core` owns shared document and page abstractions
- [x] Choose the first rendering backend strategy for the bridge
- [x] Document why rendering and editing are being split

## Rendering MVP

- [x] Load a PDF from file
- [x] Load a PDF from bytes in memory
- [x] Open a document handle safely
- [x] Read page count
- [x] Read page size for each page
- [x] Render page `N` to an image or bitmap
- [ ] Handle invalid or encrypted PDFs gracefully
- [x] Dispose native and Dart resources correctly

## Flutter Integration

- [x] Expose rendered page data in a Flutter-friendly format
- [x] Add a minimal example that shows a rendered page
- [x] Render one page end to end in the example app
- [x] Verify rendering works more than once without leaks or crashes

## Performance and Reliability

- [ ] Add a basic render cache
- [ ] Define a render scale strategy for zoomed pages
- [ ] Prevent duplicate renders for the same page request
- [ ] Measure first-page render time
- [ ] Test on large PDFs with multiple pages

Moved to Phase 2:

- basic render cache
- render scale strategy for zoomed pages
- duplicate render prevention for repeated page requests

## Exit Criteria

- [x] A PDF can be opened from file or bytes
- [x] Page count and page sizes are available
- [x] Any requested page can be rasterized
- [x] A Flutter screen can display a rendered page image
