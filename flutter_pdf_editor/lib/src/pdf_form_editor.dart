// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdf_editor_viewer/flutter_pdf_editor_viewer.dart';
// Needed for lower-bound compatibility with flutter_pdf_editor_viewer 0.0.1.
// ignore: unnecessary_import
import 'package:pdf_engine_core/pdf_engine_core.dart';

import 'pdf_acroform_parser.dart';
import 'pdf_form_editor_controller.dart';
import 'pdf_overlay_exporter.dart';
import 'signature_pad_dialog.dart';

const bool _showDebugFieldOverlay = false;

/// Acrobat-style editor for interactive AcroForm PDFs.
class PdfFormEditor extends StatefulWidget {
  /// Creates a form editor bound to a PDF [source] and [controller].
  const PdfFormEditor({
    required this.source,
    required this.controller,
    super.key,
    this.viewerController,
    this.initialZoom = 1,
    this.maxZoom = 3,
  });

  /// Source PDF to display.
  final PdfDocumentSource source;

  /// Controller storing editable field state.
  final PdfFormEditorController controller;

  /// Optional viewer controller.
  final PdfViewerController? viewerController;

  /// Initial zoom level.
  final double initialZoom;

  /// Maximum allowed zoom level.
  final double maxZoom;

  @override
  State<PdfFormEditor> createState() => _PdfFormEditorState();
}

class _PdfFormEditorState extends State<PdfFormEditor> {
  final PdfAcroFormParser _parser = PdfAcroFormParser();
  final PdfOverlayExporter _exporter = PdfOverlayExporter();

  Future<void>? _loadFuture;
  PdfDocumentSource? _previewSource;
  int _previewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadFields();
  }

  @override
  void didUpdateWidget(covariant PdfFormEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) {
      _previewSource = null;
      _previewGeneration++;
      _loadFuture = _loadFields();
    }
  }

  Future<void> _loadFields() async {
    final fields = await _parser.parse(widget.source);
    if (!mounted) {
      return;
    }
    widget.controller.setFields(fields);
  }

  Future<void> _handleFieldTap(PdfFormField field) async {
    widget.controller.selectField(field.id);
    switch (field) {
      case PdfTextFormField textField:
        if (textField.isReadOnly) {
          return;
        }
        await _editTextField(textField);
      case PdfCheckboxFormField checkboxField:
        if (checkboxField.isReadOnly) {
          return;
        }
        widget.controller.toggleCheckbox(checkboxField.id);
        await _refreshPreview();
        widget.controller.selectField(null);
      case PdfRadioFormField radioField:
        if (radioField.isReadOnly) {
          return;
        }
        widget.controller.selectRadio(radioField.id);
        await _refreshPreview();
        widget.controller.selectField(null);
      case PdfComboBoxFormField comboBoxField:
        if (comboBoxField.isReadOnly) {
          return;
        }
        await _editComboBoxField(comboBoxField);
      case PdfListBoxFormField listBoxField:
        if (listBoxField.isReadOnly) {
          return;
        }
        await _editListBoxField(listBoxField);
      case PdfSignatureFormField signatureField:
        if (signatureField.isReadOnly) {
          return;
        }
        await _editSignatureField(signatureField);
      default:
        return;
    }
  }

  Future<void> _editTextField(PdfTextFormField field) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _TextFieldEditorSheet(
          title: field.name,
          initialValue: field.value,
          isMultiline: field.isMultiline,
        );
      },
    );
    if (value != null) {
      widget.controller.updateTextField(field.id, value);
      await _refreshPreview();
    }
    widget.controller.selectField(null);
  }

  Future<void> _editComboBoxField(PdfComboBoxFormField field) async {
    final selectedValue = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  field.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final option in field.options)
                RadioListTile<String>(
                  value: option.value,
                  groupValue: field.selectedValue,
                  title: Text(option.label),
                  onChanged: (value) => Navigator.of(context).pop(value),
                ),
            ],
          ),
        );
      },
    );
    if (selectedValue != null) {
      widget.controller.selectComboBoxValue(field.id, selectedValue);
      await _refreshPreview();
    }
    widget.controller.selectField(null);
  }

  Future<void> _editListBoxField(PdfListBoxFormField field) async {
    final selectedValues = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _ListBoxEditorSheet(field: field);
      },
    );
    if (selectedValues != null) {
      widget.controller.selectListBoxValues(field.id, selectedValues);
      await _refreshPreview();
    }
    widget.controller.selectField(null);
  }

  Future<void> _editSignatureField(PdfSignatureFormField field) async {
    final signatureBytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => SignaturePadDialog(initialBytes: field.pngBytes),
    );
    if (signatureBytes != null) {
      widget.controller.updateSignatureField(field.id, signatureBytes);
      await _refreshPreview();
    }
    widget.controller.selectField(null);
  }

  Future<void> _refreshPreview() async {
    final generation = ++_previewGeneration;
    try {
      final bytes = await _exporter.exportToBytes(
        source: widget.source,
        overlays: const <PdfOverlayItem>[],
        formFields: widget.controller.fields,
      );
      if (!mounted || generation != _previewGeneration) {
        return;
      }
      setState(() {
        _previewSource = PdfDocumentSource.bytes(bytes);
      });
    } catch (_) {
      if (!mounted || generation != _previewGeneration) {
        return;
      }
    }
  }

  Future<void> _handlePageTap(PdfPageTapDetails details) async {
    final point = details.pdfPosition;
    final pageFields = widget.controller.fields
        .where((field) => field.pageIndex == details.pageInfo.pageIndex)
        .where((field) => _fieldContainsPoint(field.bounds, point))
        .toList(growable: false);
    if (pageFields.isEmpty) {
      widget.controller.selectField(null);
      return;
    }

    pageFields.sort((a, b) {
      final areaA = a.bounds.width * a.bounds.height;
      final areaB = b.bounds.width * b.bounds.height;
      return areaA.compareTo(areaB);
    });
    await _handleFieldTap(pageFields.first);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Failed to parse form fields: ${snapshot.error}'),
              );
            }

            final viewerSource = _previewSource ?? widget.source;

            return PdfViewer(
              source: viewerSource,
              controller: widget.viewerController,
              initialZoom: widget.initialZoom,
              maxZoom: widget.maxZoom,
              loading: const SizedBox.shrink(),
              onPageTap: _handlePageTap,
              pageOverlayBuilder: (context, pageInfo, viewport) {
                final pageFields = widget.controller.fields
                    .where((field) => field.pageIndex == pageInfo.pageIndex)
                    .toList(growable: false);
                if (pageFields.isEmpty) {
                  return null;
                }
                return Stack(
                  children: [
                    for (final field in pageFields)
                      _FormFieldOverlay(
                        field: field,
                        viewport: viewport,
                        isSelected:
                            widget.controller.selectedFieldId == field.id,
                        onTap: () => _handleFieldTap(field),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FormFieldOverlay extends StatelessWidget {
  const _FormFieldOverlay({
    required this.field,
    required this.viewport,
    required this.isSelected,
    required this.onTap,
  });

  final PdfFormField field;
  final PdfPageViewport viewport;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showSelectionOutline =
        isSelected &&
        field is! PdfCheckboxFormField &&
        field is! PdfRadioFormField;

    final topLeft = viewport.pdfToScreen(
      PdfPoint(x: field.bounds.left, y: field.bounds.top),
    );
    final bottomRight = viewport.pdfToScreen(
      PdfPoint(x: field.bounds.right, y: field.bounds.bottom),
    );
    final width = (bottomRight.x - topLeft.x)
        .clamp(14, double.infinity)
        .toDouble();
    final height = (bottomRight.y - topLeft.y)
        .clamp(14, double.infinity)
        .toDouble();

    return Positioned(
      left: topLeft.x,
      top: topLeft.y,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _showDebugFieldOverlay
                ? const Color(0x332563EB)
                : Colors.transparent,
            border: showSelectionOutline
                ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
                : _showDebugFieldOverlay
                ? Border.all(color: const Color(0x992563EB), width: 0.8)
                : null,
            borderRadius: field is PdfRadioFormField
                ? null
                : BorderRadius.circular(3),
            shape: field is PdfRadioFormField
                ? BoxShape.circle
                : BoxShape.rectangle,
          ),
          child: _showDebugFieldOverlay
              ? Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    color: const Color(0xCC2563EB),
                    child: Text(
                      field.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _TextFieldEditorSheet extends StatefulWidget {
  const _TextFieldEditorSheet({
    required this.title,
    required this.initialValue,
    required this.isMultiline,
  });

  final String title;
  final String initialValue;
  final bool isMultiline;

  @override
  State<_TextFieldEditorSheet> createState() => _TextFieldEditorSheetState();
}

class _TextFieldEditorSheetState extends State<_TextFieldEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: widget.isMultiline ? 6 : 1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: widget.title,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListBoxEditorSheet extends StatefulWidget {
  const _ListBoxEditorSheet({required this.field});

  final PdfListBoxFormField field;

  @override
  State<_ListBoxEditorSheet> createState() => _ListBoxEditorSheetState();
}

class _ListBoxEditorSheetState extends State<_ListBoxEditorSheet> {
  late List<String> _selectedValues;

  @override
  void initState() {
    super.initState();
    _selectedValues = List<String>.from(widget.field.selectedValues);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                widget.field.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                widget.field.isMultiSelect
                    ? 'Multi-select list box'
                    : 'Single-select list box',
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in widget.field.options)
                    widget.field.isMultiSelect
                        ? CheckboxListTile(
                            value: _selectedValues.contains(option.value),
                            title: Text(option.label),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (isChecked) {
                              setState(() {
                                if (isChecked ?? false) {
                                  if (!_selectedValues.contains(option.value)) {
                                    _selectedValues.add(option.value);
                                  }
                                } else {
                                  _selectedValues.remove(option.value);
                                }
                              });
                            },
                          )
                        : (RadioListTile<String>(
                            value: option.value,
                            groupValue: _selectedValues.isEmpty
                                ? null
                                : _selectedValues.first,
                            title: Text(option.label),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedValues = <String>[value];
                              });
                            },
                          )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.field.isMultiSelect)
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedValues = <String>[];
                      }),
                      child: const Text('Clear'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedValues),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _fieldContainsPoint(PdfRect bounds, PdfPoint point) {
  const tolerance = 6.0;
  return point.x >= bounds.left - tolerance &&
      point.x <= bounds.right + tolerance &&
      point.y >= bounds.top - tolerance &&
      point.y <= bounds.bottom + tolerance;
}
