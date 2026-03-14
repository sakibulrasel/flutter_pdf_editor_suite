# Unicode Text Export Follow-Up

Goal: make flattened PDF export handle real-world Unicode text reliably instead of depending on the default built-in PDF font path.

## Font Strategy

- [x] Stop relying on Helvetica for exported text overlays
- [x] Choose a Unicode-capable font strategy for export
- [x] Support embedding at least one bundled fallback TTF font
- [ ] Decide whether to allow app-provided custom fonts later

## Rendering Coverage

- [x] Verify Latin text with accents exports correctly
- [x] Verify Arabic text exports correctly
- [x] Verify Bengali text exports correctly
- [x] Verify mixed-language text in the same overlay
- [x] Verify numbers and punctuation stay correct across scripts
- [x] Verify multi-line Unicode text overlays

## Text Behavior

- [x] Keep exported text size visually close to the editor preview
- [x] Check alignment and clipping for longer Unicode strings
- [x] Handle text direction for RTL languages
- [x] Handle line wrapping with Unicode text

## Reliability

- [x] Add tests for Unicode export with embedded fonts
- [x] Add regression tests for non-Latin scripts
- [ ] Confirm exported PDFs open correctly in common viewers
- [x] Remove the current Helvetica Unicode warning during export tests

## Scope Notes

- [ ] Keep this as an export-layer improvement, not Phase 5 form filling
- [ ] Reuse the same overlay model; do not redesign text overlays for this task

Notes:
- v1 now bundles `Arial Unicode.ttf` in `flutter_pdf_editor` and uses it by default for exported text overlays and text form fields.
- `PdfExportOptions` also accepts custom `unicodeFontBytes` so another font can be supplied later without redesigning the export pipeline.
- Export now applies a simple fit-to-box font-size reduction for long text in overlays and text form fields.
