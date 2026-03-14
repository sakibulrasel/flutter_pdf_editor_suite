# Phase 4 - Save and Export

Goal: save a new PDF with overlays burned into the output.

## Version 1 Save Strategy

- [x] Use the recreate-new-PDF approach for v1
- [x] Document that v1 is not editing original PDF content streams
- [x] Document tradeoffs: simplicity, reliability, larger files, reduced semantics
- [x] Keep direct in-place PDF editing out of the MVP scope

Notes:
- v1 export rasterizes the original PDF pages, draws overlays on top, and writes a brand-new PDF.
- This keeps the implementation simple and reliable, but the output is flattened and can be larger than the source.
- Editing original content streams, annotations, xref tables, and trailers stays out of scope for this phase.

## Export Pipeline

- [x] Render original PDF pages into export-ready images
- [x] Draw overlays on top of each page in the correct order
- [x] Generate a new PDF from the composited pages
- [x] Support saving to file
- [x] Support returning bytes in memory
- [x] Preserve page size and page order

Example UX:
- [x] Save exported PDF to a user-selected path
- [x] Share the exported PDF
- [x] Open the exported PDF with another app

## Output Quality

- [x] Choose export DPI or scale targets
- [x] Keep text overlays legible in the exported PDF
- [x] Keep signature images sharp enough for real use
- [x] Verify checkmarks export cleanly
- [x] Test export file size on small and large documents

Notes:
- Current v1 export uses a render scale of `2.0` by default.
- The exporter now clamps oversized pages to a page-pixel budget so larger PDFs do not render at unbounded raster sizes.
- Small documents keep the requested render scale, while larger pages automatically scale down for file-size and memory control.

## Reliability

- [x] Handle export cancellation safely
- [x] Handle failed page renders during export
- [x] Avoid unbounded memory usage during export
- [x] Validate output opens in common PDF viewers
- [x] Add tests for export with multi-page overlays

Notes:
- Export validation now reopens the generated PDF through the renderer bridge and verifies the page count before returning success.

## Future-Scope Boundary

- [x] Note that true structural PDF editing is a later phase
- [x] Note that adding content streams, annotations, xref updates, and trailer updates is out of scope for v1

## Exit Criteria

- [x] A user can open a PDF, add overlays, and save a new PDF
- [x] The saved PDF visually matches the edited viewer state
- [x] Export works for multi-page documents
