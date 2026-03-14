# Phase 3 - Overlay Editing

Goal: make the viewer useful by adding editable overlays.

## Overlay Model

- [x] Define shared overlay item models in `pdf_engine_core`
- [x] Support text overlays
- [x] Support checkmark overlays
- [x] Support signature image overlays
- [x] Include page index, bounds, rotation, and style data
- [x] Add serialization support for editor state if needed

## Editing UX

- [x] Tap to add a text overlay
- [x] Tap to add a checkmark overlay
- [x] Tap to add a signature image overlay
- [x] Select an overlay
- [x] Drag overlays to move them
- [x] Resize overlays with handles
- [x] Delete overlays
- [x] Keep interactions correct at different zoom levels

## Rendering and State

- [x] Paint overlays above rendered PDF pages
- [x] Keep overlay redraws efficient during drag and resize
- [x] Separate selection state from persisted overlay data
- [x] Add a controller or state model for editor actions
- [x] Prepare undo and redo hooks for later work

## Basic Editing Tools

- [x] Text style controls for font size and color
- [x] Signature image import path or callback
- [x] Checkmark preset styles
- [x] Overlay bounds validation so items cannot disappear off-page

## Exit Criteria

- [x] Users can add, move, and delete text overlays
- [x] Users can resize text overlays
- [x] Users can add, move, resize, and delete checkmarks
- [x] Users can add, move, resize, and delete signatures
- [x] Overlay placement remains accurate after zooming and scrolling
