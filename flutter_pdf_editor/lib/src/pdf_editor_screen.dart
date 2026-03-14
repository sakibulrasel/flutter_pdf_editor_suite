import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdf_editor_viewer/flutter_pdf_editor_viewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
// Needed for lower-bound compatibility with flutter_pdf_editor_viewer 0.0.1.
// ignore: unnecessary_import
import 'package:pdf_engine_core/pdf_engine_core.dart';
import 'package:share_plus/share_plus.dart';

import 'pdf_document_creator.dart';
import 'pdf_editable_exporter.dart';
import 'pdf_form_editor.dart';
import 'pdf_form_editor_controller.dart';
import 'pdf_overlay_editor.dart';
import 'pdf_overlay_editor_controller.dart';
import 'pdf_overlay_exporter.dart';

/// High-level actions that can be exposed by [PdfEditorScreen].
enum PdfEditorAction {
  /// Pick and open an existing PDF from device storage.
  open,

  /// Create a new blank PDF.
  create,

  /// Export a flattened PDF.
  flatten,

  /// Export an editable AcroForm PDF when supported.
  editable,

  /// Save the flattened export to a user-selected path.
  saveAs,

  /// Share the flattened export file.
  share,

  /// Open the flattened export in another app.
  openExportedFile,
}

/// Configuration for the built-in [PdfEditorScreen].
final class PdfEditorConfig {
  /// Creates editor screen configuration.
  const PdfEditorConfig({
    this.title = 'PDF Editor',
    this.actions = const <PdfEditorAction>{
      PdfEditorAction.open,
      PdfEditorAction.create,
      PdfEditorAction.flatten,
      PdfEditorAction.editable,
      PdfEditorAction.saveAs,
      PdfEditorAction.share,
      PdfEditorAction.openExportedFile,
    },
    this.initialZoom = 1,
    this.maxZoom = 6,
    this.showCurrentFileLabel = true,
    this.showStatusMessage = true,
    this.showDocumentInfo = true,
    this.helperText,
    this.createBlankDocumentOnStart = true,
    this.initialCreateOptions = const PdfCreateOptions(),
  });

  /// App bar title shown by the screen.
  final String title;

  /// Action buttons shown by the screen.
  final Set<PdfEditorAction> actions;

  /// Initial zoom level passed to the viewer/editor widgets.
  final double initialZoom;

  /// Maximum zoom level passed to the viewer/editor widgets.
  final double maxZoom;

  /// Whether to show the active file label.
  final bool showCurrentFileLabel;

  /// Whether to show export/open status messages.
  final bool showStatusMessage;

  /// Whether to show document metadata and current page information.
  final bool showDocumentInfo;

  /// Optional helper text shown above the action buttons.
  ///
  /// If `null`, no helper text is shown.
  final String? helperText;

  /// Whether to automatically create a blank PDF when no [initialSource] is provided.
  final bool createBlankDocumentOnStart;

  /// Options used when creating the initial blank document.
  final PdfCreateOptions initialCreateOptions;
}

enum _EditorMode { formFill, authoring }

/// Ready-made screen that lets apps open, create, edit, and export PDFs with one package.
class PdfEditorScreen extends StatefulWidget {
  /// Creates a high-level PDF editor screen.
  const PdfEditorScreen({
    super.key,
    this.config = const PdfEditorConfig(),
    this.initialSource,
    this.initialLabel,
  });

  /// Screen configuration.
  final PdfEditorConfig config;

  /// Optional initial PDF source.
  final PdfDocumentSource? initialSource;

  /// Optional label for the initial PDF source.
  final String? initialLabel;

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final PdfViewerController _viewerController = PdfViewerController();
  final PdfFormEditorController _formController = PdfFormEditorController();
  final PdfOverlayEditorController _overlayController =
      PdfOverlayEditorController();
  final PdfOverlayExporter _overlayExporter = PdfOverlayExporter();
  final PdfEditableExporter _editableExporter = PdfEditableExporter();
  final PdfDocumentCreator _documentCreator = PdfDocumentCreator();
  final PdfBridgeExportRenderer _exportRenderer = PdfBridgeExportRenderer();

  PdfDocumentSource? _activePdfSource;
  String _activePdfLabel = 'blank.pdf';
  _EditorMode _editorMode = _EditorMode.authoring;
  bool _isLoadingDocument = false;
  bool _isExporting = false;
  String? _statusMessage;
  String? _error;
  File? _lastFlattenedExport;
  PdfDocumentInfo? _documentInfo;
  PdfPageInfo? _firstPageInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    if (widget.initialSource != null) {
      await _setActiveDocument(
        source: widget.initialSource!,
        label: widget.initialLabel ?? 'document.pdf',
        mode: _EditorMode.formFill,
      );
      return;
    }
    if (widget.config.createBlankDocumentOnStart) {
      await _createNewPdf(options: widget.config.initialCreateOptions);
    }
  }

  Future<void> _setActiveDocument({
    required PdfDocumentSource source,
    required String label,
    required _EditorMode mode,
  }) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _activePdfSource = source;
      _activePdfLabel = label;
      _editorMode = mode;
      _isLoadingDocument = true;
      _statusMessage = null;
      _error = null;
      _lastFlattenedExport = null;
      _documentInfo = null;
      _firstPageInfo = null;
    });
    _formController.setFields(const <PdfFormField>[]);
    _overlayController.restoreState(<String, Object?>{
      'activeTool': PdfOverlayTool.text.name,
      'selectedOverlayId': null,
      'nextOverlayId': 1,
      'overlays': <Object?>[],
    });
    await _loadMetadata(source);
  }

  Future<void> _loadMetadata(PdfDocumentSource source) async {
    try {
      final document = await _exportRenderer.openDocument(source);
      final pageInfo = await _exportRenderer.getPageInfo(
        documentId: document.documentId,
        pageIndex: 0,
      );
      await _exportRenderer.closeDocument(document.documentId);
      if (!mounted) {
        return;
      }
      setState(() {
        _documentInfo = document;
        _firstPageInfo = pageInfo;
        _isLoadingDocument = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingDocument = false;
        _error = '$error';
      });
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select a PDF to edit',
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final selected = result.files.single;
      final source = selected.path != null
          ? PdfDocumentSource.file(selected.path!)
          : (selected.bytes != null
                ? PdfDocumentSource.bytes(Uint8List.fromList(selected.bytes!))
                : null);
      if (source == null) {
        setState(() {
          _statusMessage = 'Selected PDF could not be loaded.';
        });
        return;
      }
      await _setActiveDocument(
        source: source,
        label: selected.name.isEmpty ? 'selected.pdf' : selected.name,
        mode: _EditorMode.formFill,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Open failed: $error';
      });
    }
  }

  Future<void> _createNewPdf({PdfCreateOptions? options}) async {
    try {
      final selectedOptions = options ?? await _showCreatePdfDialog();
      if (!mounted || selectedOptions == null) {
        return;
      }
      final bytes = await _documentCreator.createBlankPdf(options: selectedOptions);
      await _setActiveDocument(
        source: PdfDocumentSource.bytes(bytes),
        label: _blankPdfLabel(selectedOptions),
        mode: _EditorMode.authoring,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Created ${_blankPdfLabel(selectedOptions)}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Create PDF failed: $error';
      });
    }
  }

  Future<PdfCreateOptions?> _showCreatePdfDialog() async {
    var pagePreset = PdfCreatePagePreset.a4;
    var orientation = PdfCreateOrientation.portrait;
    var pageCount = 1;

    return showDialog<PdfCreateOptions>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New PDF'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<PdfCreatePagePreset>(
                    initialValue: pagePreset,
                    decoration: const InputDecoration(
                      labelText: 'Page size',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PdfCreatePagePreset.a4,
                        child: Text('A4'),
                      ),
                      DropdownMenuItem(
                        value: PdfCreatePagePreset.letter,
                        child: Text('Letter'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          pagePreset = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PdfCreateOrientation>(
                    initialValue: orientation,
                    decoration: const InputDecoration(
                      labelText: 'Orientation',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PdfCreateOrientation.portrait,
                        child: Text('Portrait'),
                      ),
                      DropdownMenuItem(
                        value: PdfCreateOrientation.landscape,
                        child: Text('Landscape'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          orientation = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: pageCount,
                    decoration: const InputDecoration(
                      labelText: 'Pages',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1')),
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                      DropdownMenuItem(value: 5, child: Text('5')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          pageCount = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      PdfCreateOptions(
                        pagePreset: pagePreset,
                        orientation: orientation,
                        pageCount: pageCount,
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _blankPdfLabel(PdfCreateOptions options) {
    final size = switch (options.pagePreset) {
      PdfCreatePagePreset.a4 => 'a4',
      PdfCreatePagePreset.letter => 'letter',
    };
    final orientation = switch (options.orientation) {
      PdfCreateOrientation.portrait => 'portrait',
      PdfCreateOrientation.landscape => 'landscape',
    };
    return 'blank_${size}_${orientation}_${options.pageCount}p.pdf';
  }

  Future<Uint8List?> _pickImageBytes() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select an image to place',
        type: FileType.custom,
        allowedExtensions: const <String>['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return null;
      }
      final file = result.files.single;
      if (file.bytes != null) {
        return Uint8List.fromList(file.bytes!);
      }
      if (file.path != null) {
        return File(file.path!).readAsBytes();
      }
      return null;
    } catch (error) {
      if (!mounted) {
        return null;
      }
      setState(() {
        _statusMessage = 'Image pick failed: $error';
      });
      return null;
    }
  }

  Future<File> _ensureFlattenedExport({bool forceRegenerate = false}) async {
    final source = _activePdfSource;
    if (source == null) {
      throw StateError('No PDF is loaded.');
    }
    if (!forceRegenerate && _lastFlattenedExport != null) {
      return _lastFlattenedExport!;
    }
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/flutter_pdf_editor_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = await _overlayExporter.exportToFile(
      source: source,
      overlays: _editorMode == _EditorMode.authoring
          ? _overlayController.overlays
          : const <PdfOverlayItem>[],
      formFields: _editorMode == _EditorMode.formFill
          ? _formController.fields
          : const <PdfFormField>[],
      outputPath: outputPath,
    );
    _lastFlattenedExport = file;
    return file;
  }

  Future<void> _exportFlattened() async {
    if (_isExporting) {
      return;
    }
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });
    try {
      final file = await _ensureFlattenedExport(forceRegenerate: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Exported flattened PDF to ${file.path} (${file.lengthSync()} bytes)';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportEditable() async {
    final source = _activePdfSource;
    if (_editorMode == _EditorMode.authoring) {
      setState(() {
        _statusMessage =
            'Editable export is only available for opened AcroForm PDFs.';
      });
      return;
    }
    if (source == null || _isExporting) {
      return;
    }
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/flutter_pdf_editor_editable_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await _editableExporter.exportToFile(
        source: source,
        formFields: _formController.fields,
        outputPath: outputPath,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Exported editable PDF to ${file.path} (${file.lengthSync()} bytes)';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Editable export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _saveAs() async {
    try {
      final file = await _ensureFlattenedExport();
      final bytes = await file.readAsBytes();
      final destination = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'export.pdf',
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
        bytes: bytes,
      );
      if (!mounted || destination == null) {
        return;
      }
      setState(() {
        _statusMessage = 'Saved PDF to $destination';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Save failed: $error';
      });
    }
  }

  Future<void> _share() async {
    try {
      final file = await _ensureFlattenedExport();
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path)], text: 'PDF export'),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Shared PDF from ${file.path}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Share failed: $error';
      });
    }
  }

  Future<void> _openExportedFile() async {
    try {
      final file = await _ensureFlattenedExport();
      final result = await OpenFilex.open(file.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Open result: ${result.type.name}${result.message.isEmpty ? '' : ' (${result.message})'}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Open failed: $error';
      });
    }
  }

  @override
  void dispose() {
    _viewerController.dispose();
    _formController.dispose();
    _overlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _activePdfSource;
    final config = widget.config;
    final metadata = _firstPageInfo;
    final isAuthoringMode = _editorMode == _EditorMode.authoring;
    final compactButtonStyle = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: Theme.of(context).textTheme.labelMedium,
    );
    final compactFilledButtonStyle = FilledButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: Theme.of(context).textTheme.labelMedium,
    );

    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (config.helperText case final helperText?) ...[
              Text(helperText),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (config.actions.contains(PdfEditorAction.open))
                  OutlinedButton(
                    style: compactButtonStyle,
                    onPressed: _isLoadingDocument || _isExporting
                        ? null
                        : _pickPdfFile,
                    child: const Text('Open'),
                  ),
                if (config.actions.contains(PdfEditorAction.create))
                  OutlinedButton(
                    style: compactButtonStyle,
                    onPressed: _isLoadingDocument || _isExporting
                        ? null
                        : _createNewPdf,
                    child: const Text('New'),
                  ),
                if (config.actions.contains(PdfEditorAction.flatten))
                  FilledButton(
                    style: compactFilledButtonStyle,
                    onPressed: source == null || _isExporting
                        ? null
                        : _exportFlattened,
                    child: Text(_isExporting ? 'Exporting' : 'Flatten'),
                  ),
                if (config.actions.contains(PdfEditorAction.editable))
                  OutlinedButton(
                    style: compactButtonStyle,
                    onPressed:
                        source == null || _isExporting || isAuthoringMode
                        ? null
                        : _exportEditable,
                    child: const Text('Editable'),
                  ),
                if (config.actions.contains(PdfEditorAction.saveAs))
                  OutlinedButton(
                    style: compactButtonStyle,
                    onPressed: source == null || _isExporting ? null : _saveAs,
                    child: const Text('Save As'),
                  ),
                if (config.actions.contains(PdfEditorAction.share))
                  OutlinedButton(
                    style: compactButtonStyle,
                    onPressed: source == null || _isExporting ? null : _share,
                    child: const Text('Share'),
                  ),
                if (config.actions.contains(PdfEditorAction.openExportedFile))
                  OutlinedButton(
                    style: compactButtonStyle,
                    onPressed: source == null || _isExporting
                        ? null
                        : _openExportedFile,
                    child: const Text('Open File'),
                  ),
              ],
            ),
            if (config.showCurrentFileLabel) ...[
              const SizedBox(height: 8),
              Text(
                'Current PDF: $_activePdfLabel',
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (config.showStatusMessage && _statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(_statusMessage!),
            ],
            if (config.showDocumentInfo &&
                _documentInfo != null &&
                metadata != null) ...[
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: _viewerController.currentPage,
                builder: (context, currentPage, child) {
                  return Text(
                    'Pages: ${_documentInfo!.pageCount} | '
                    'Page 1 size: ${metadata.width.toStringAsFixed(0)} x ${metadata.height.toStringAsFixed(0)} | '
                    'Current page: $currentPage | '
                    '${isAuthoringMode ? 'Overlays' : 'Detected fields'}: '
                    '${isAuthoringMode ? _overlayController.overlays.length : _formController.fields.length}',
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _isLoadingDocument
                      ? const Center(child: CircularProgressIndicator())
                      : (source == null
                            ? _PdfEditorEmptyState(
                                canOpen: config.actions.contains(
                                  PdfEditorAction.open,
                                ),
                                canCreate: config.actions.contains(
                                  PdfEditorAction.create,
                                ),
                              )
                            : (isAuthoringMode
                                  ? PdfOverlayEditor(
                                      source: source,
                                      controller: _overlayController,
                                      viewerController: _viewerController,
                                      initialZoom: config.initialZoom,
                                      maxZoom: config.maxZoom,
                                      onPickImageBytes: _pickImageBytes,
                                    )
                                  : PdfFormEditor(
                                      source: source,
                                      controller: _formController,
                                      viewerController: _viewerController,
                                      initialZoom: config.initialZoom,
                                      maxZoom: config.maxZoom,
                                    ))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfEditorEmptyState extends StatelessWidget {
  const _PdfEditorEmptyState({required this.canOpen, required this.canCreate});

  final bool canOpen;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final hints = <String>[
      if (canOpen) 'select an existing PDF',
      if (canCreate) 'create a new PDF',
    ];
    final hintText = hints.isEmpty
        ? 'No start action is enabled in this editor configuration.'
        : 'Please ${hints.join(' or ')} to begin.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No PDF selected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hintText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
