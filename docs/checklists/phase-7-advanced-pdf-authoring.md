# Phase 7 - Advanced PDF Authoring

Goal: move beyond viewing, filling, and exporting existing PDFs into full PDF creation, rich document authoring, security, compliance, and platform coverage.

Current gap summary:

- The package can render, edit overlays, fill supported AcroForm fields, export flattened PDFs, and save classic editable AcroForm updates.
- The package does not yet provide a true "create new PDF" workflow.
- The package does not yet provide rich authoring primitives like tables, structured text blocks, headers/footers, bookmarks, attachments, encryption, PDF/A, or digital signatures.

## New PDF Creation

- [x] Add `Create New PDF` action in the app
- [x] Create a blank PDF document from scratch
- [x] Support multiple page sizes and orientations
- [ ] Add page insertion, duplication, deletion, and reordering
- [x] Save and reopen newly created PDFs

## Existing PDF Authoring

When a user opens an existing PDF file, these capabilities should also be available there, not only in blank/new PDFs.

- [ ] Insert PNG images into opened existing PDFs
- [ ] Insert JPEG images into opened existing PDFs
- [ ] Generate and place tables in opened existing PDFs
- [ ] Add headers and footers to opened existing PDFs
- [ ] Add shapes to opened existing PDFs
- [ ] Add paragraphs, bullets, and lists to opened existing PDFs
- [ ] Open, modify, and save existing PDF files without forcing a flattened-only workflow
- [ ] Add, modify, and remove bookmarks in existing PDFs
- [ ] Add, modify, and remove annotations in existing PDFs
- [ ] Add, modify, and remove hyperlinks in existing PDFs
- [ ] Add and remove file attachments in existing PDFs
- [ ] Encrypt and decrypt existing PDF files with modern standards
- [ ] Save existing PDFs as PDF/A-1B, PDF/A-2B, and PDF/A-3B where supported
- [ ] Digitally sign existing PDF documents
- [ ] Keep these flows working on mobile and web platforms

## Authoring Canvas

- [x] Add a blank-page editing mode for new PDFs
- [ ] Let users add and position form fields on blank pages
- [ ] Let users add all supported field types to new PDFs
- [ ] Text fields
- [ ] Checkboxes
- [ ] Radio buttons
- [ ] Combo boxes
- [ ] List boxes
- [ ] Multi-select list boxes
- [ ] Signature fields

## Structured Content

- [ ] Add paragraphs with alignment and spacing controls
- [ ] Add bullets and numbered lists
- [ ] Add styled text blocks with fonts, color, and size
- [ ] Add headers and footers
- [ ] Add page numbers
- [ ] Add reusable text styles/templates

## Images and Graphics

- [x] Insert PNG images into PDFs
- [x] Insert JPEG images into PDFs
- [ ] Resize, crop, and position images
- [x] Add rectangles
- [ ] Add circles and ellipses
- [ ] Add lines and arrows
- [ ] Add filled and stroked shapes

## Tables

- [ ] Create tables from scratch
- [ ] Support different table border styles
- [ ] Support row and column sizing
- [ ] Support cell padding and alignment
- [ ] Support header rows
- [ ] Support alternating row styles
- [ ] Support merged cells where practical

## Existing PDF Modification

- [ ] Open existing PDFs and modify page content intentionally, not only overlays/forms
- [ ] Add images to existing PDFs
- [ ] Add shapes to existing PDFs
- [ ] Add structured text blocks to existing PDFs
- [ ] Add headers and footers to existing PDFs
- [ ] Save modified existing PDFs without flattening everything
- [ ] Add tables to existing PDFs
- [ ] Add list and bullet content to existing PDFs

## Interactive PDF Features

- [ ] Add bookmarks/outlines
- [ ] Modify bookmarks/outlines
- [ ] Remove bookmarks/outlines
- [ ] Add annotations
- [ ] Modify annotations
- [ ] Remove annotations
- [ ] Add hyperlinks
- [ ] Modify hyperlinks
- [ ] Remove hyperlinks
- [ ] Add file attachments
- [ ] Remove file attachments

## Security

- [ ] Encrypt PDF files
- [ ] Decrypt password-protected PDF files
- [ ] Support stronger modern encryption profiles
- [ ] Support owner/user permissions
- [ ] Control printing/copying/edit permissions

## Standards and Compliance

- [ ] Create PDF/A-1B files
- [ ] Create PDF/A-2B files
- [ ] Create PDF/A-3B files
- [ ] Validate required metadata and resource constraints for PDF/A output

## Digital Signatures

- [ ] Add cryptographic digital signatures
- [ ] Support certificate-based signing
- [ ] Support visible signature appearance plus cryptographic signing
- [ ] Validate signed documents after save

## Platform Coverage

- [ ] Keep feature support working on Android
- [ ] Keep feature support working on iOS
- [ ] Add web-compatible rendering and editing path
- [ ] Ensure export/save flows work on mobile and web

## UX

- [ ] Separate `Create New PDF` from `Open Existing PDF`
- [ ] Add a toolbox for content blocks, form fields, images, tables, and shapes
- [ ] Add undo/redo for document authoring actions
- [ ] Add template/starter documents for common forms

## Exit Criteria

- [ ] A user can create a blank PDF and build a document from scratch
- [ ] A user can add rich content like text, lists, tables, images, and shapes
- [ ] A user can place supported form fields into a newly created PDF
- [ ] A user can save both editable and final-output versions
- [ ] Advanced document features work consistently across supported platforms
