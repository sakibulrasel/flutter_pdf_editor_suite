# Phase 2 - Viewer Widget

Goal: build a smooth PDF viewing experience on top of the renderer.

## Viewer Structure

- [x] Create the main viewer widget in `flutter_pdf_viewer`
- [x] Support a vertical page list
- [x] Support page navigation controls
- [x] Support current page tracking
- [x] Add page loading and empty states
- [x] Add error states for failed page rendering

## Interaction

- [x] Add zoom support
- [x] Add pan support
- [x] Decide between page snapping and free scrolling
- [ ] Keep scroll behavior stable during zoom changes
- [x] Keep current page tracking accurate while scrolling

## Rendering Strategy

- [x] Lazily render only visible or near-visible pages
- [x] Add memory caching for rendered pages
- [x] Reuse cached pages when scrolling back
- [x] Evict old cached pages under memory pressure
- [ ] Tune render quality versus memory usage
- [x] Prevent duplicate renders for the same page request
- [x] Define a render scale strategy for zoomed pages

## Overlay Coordinate System

- [x] Store overlay positions in PDF page coordinates
- [x] Convert PDF coordinates to screen coordinates during paint
- [x] Convert screen taps back into PDF coordinates
- [ ] Verify overlay positions stay correct across zoom levels
- [ ] Verify overlay positions stay correct across device sizes

## Exit Criteria

- [x] Multi-page PDFs scroll smoothly
- [x] Zoom and pan work reliably
- [x] Current page state is accurate
- [x] Overlay coordinate mapping is ready for editing
