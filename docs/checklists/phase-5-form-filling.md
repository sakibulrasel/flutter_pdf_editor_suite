# Phase 5 - Basic Form Filling

Goal: add real PDF form support only after the viewer, overlays, and export flow are stable.

## Recommended Order

- [x] Start Phase 5 by getting basic real text fields and checkboxes working
- [x] After that first usable form slice, complete [unicode-text-export.md](./unicode-text-export.md)
- [x] Only then continue deeper Phase 5 items such as radio buttons, combo boxes, and list boxes

Notes:
- Unicode text export should not block the start of Phase 5.
- It also should not be postponed until all of Phase 5 is finished.
- The right checkpoint is: basic form filling first, Unicode-safe export second, deeper field coverage after that.

## Parsing Targets

- [x] Parse `/AcroForm`
- [x] Parse field dictionaries
- [x] Parse widget annotations
- [x] Map fields to pages and widget bounds
- [x] Read default values and current values

## First Field Types

- [x] Text fields
- [x] Checkboxes
- [x] Radio buttons
- [x] Combo boxes
- [x] List boxes
- [x] Multi-select list boxes
- [x] Signature fields

## Editing Behavior

- [x] Display real form widgets in the viewer
- [x] Support selecting and editing field values
- [x] Keep widget appearance aligned with page coordinates
- [x] Handle focus and input for text fields
- [x] Handle checked and unchecked states correctly

## Appearance and Compatibility

- [x] Decide how field appearances will be generated or refreshed
- [ ] Verify filled forms display correctly in multiple PDF viewers
- [ ] Test documents that already include appearance streams
- [ ] Test documents that depend on regenerated appearances

Notes:
- The app now supports both flattened export and a first editable-save path for classic AcroForm PDFs.
- Editable save currently covers text, checkboxes, radios, combo boxes, and list boxes.
- Signature image write-back and broader viewer-appearance compatibility are still limited.
- The current parser/save slice is still intentionally limited to classic non-xref-stream AcroForm PDFs.

## Scope and Risk Control

- [x] Keep form filling separate from generic overlay editing
- [x] Avoid mixing initial form support with deep PDF rewrite work
- [x] Document unsupported field behaviors in the first release

## Exit Criteria

- [x] Basic AcroForm fields can be detected and displayed
- [x] Supported fields can be edited
- [x] Saved output preserves visible field values correctly
- [x] Editable save exists for the core supported field types
