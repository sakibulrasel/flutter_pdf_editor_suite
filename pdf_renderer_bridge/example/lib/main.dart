import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdf_editor/flutter_pdf_editor.dart';
import 'package:flutter_pdf_editor_viewer/flutter_pdf_editor_viewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_renderer_bridge/pdf_renderer_bridge.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const PdfRendererDemoApp());
}

enum _EditorMode { formFill, authoring }

class PdfRendererDemoApp extends StatelessWidget {
  const PdfRendererDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: PdfRendererDemoScreen());
  }
}

class PdfRendererDemoScreen extends StatefulWidget {
  const PdfRendererDemoScreen({super.key});

  @override
  State<PdfRendererDemoScreen> createState() => _PdfRendererDemoScreenState();
}

class _PdfRendererDemoScreenState extends State<PdfRendererDemoScreen> {
  final PdfRendererBridge _bridge = PdfRendererBridge();
  final PdfViewerController _viewerController = PdfViewerController();
  final PdfFormEditorController _formController = PdfFormEditorController();
  final PdfOverlayEditorController _overlayController =
      PdfOverlayEditorController();
  final PdfOverlayExporter _exporter = PdfOverlayExporter();
  final PdfEditableExporter _editableExporter = PdfEditableExporter();
  final PdfDocumentCreator _documentCreator = PdfDocumentCreator();
  static const String _bundledPdfAssetPath =
      'assets/pdf/sample_fillable_fields.pdf';

  PdfDocumentSource? _activePdfSource;
  String _activePdfLabel = 'sample_fillable_fields.pdf';
  _EditorMode _editorMode = _EditorMode.formFill;
  String? _error;
  String? _exportMessage;
  bool _isExporting = false;
  bool _isLoadingDocument = true;
  File? _lastExportedFile;
  File? _lastEditableExportedFile;
  PdfDocumentInfo? _documentInfo;
  PdfPageInfo? _pageInfo;

  @override
  void initState() {
    super.initState();
    _loadBundledPdf();
  }

  Future<void> _loadBundledPdf() async {
    try {
      final bytes = await rootBundle.load(_bundledPdfAssetPath);
      await _setActiveDocument(
        source: PdfDocumentSource.bytes(bytes.buffer.asUint8List()),
        label: 'sample_fillable_fields.pdf',
        mode: _EditorMode.formFill,
      );
    } on FlutterError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingDocument = false;
        _error = 'Failed to load bundled PDF: $error';
      });
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
      _error = null;
      _exportMessage = null;
      _lastExportedFile = null;
      _lastEditableExportedFile = null;
      _documentInfo = null;
      _pageInfo = null;
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
      final document = await _bridge.openDocument(source);
      final pageInfo = await _bridge.getPageInfo(
        documentId: document.documentId,
        pageIndex: 0,
      );
      if (!mounted) {
        await _bridge.closeDocument(document.documentId);
        return;
      }
      setState(() {
        _documentInfo = document;
        _pageInfo = pageInfo;
        _isLoadingDocument = false;
      });
      await _bridge.closeDocument(document.documentId);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingDocument = false;
        _error = '${error.code}: ${error.message}';
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

      final selectedFile = result.files.single;
      final source = selectedFile.path != null
          ? PdfDocumentSource.file(selectedFile.path!)
          : (selectedFile.bytes != null
                ? PdfDocumentSource.bytes(
                    Uint8List.fromList(selectedFile.bytes!),
                  )
                : null);
      if (source == null) {
        setState(() {
          _exportMessage = 'Selected PDF could not be loaded.';
        });
        return;
      }

      await _setActiveDocument(
        source: source,
        label: selectedFile.name.isEmpty ? 'selected.pdf' : selectedFile.name,
        mode: _EditorMode.formFill,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Open failed: $error';
      });
    }
  }

  Future<Uint8List?> _pickImageFile() async {
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
      final selectedFile = result.files.single;
      if (selectedFile.bytes != null) {
        return Uint8List.fromList(selectedFile.bytes!);
      }
      if (selectedFile.path != null) {
        return File(selectedFile.path!).readAsBytes();
      }
      return null;
    } catch (error) {
      if (mounted) {
        setState(() {
          _exportMessage = 'Image pick failed: $error';
        });
      }
      return null;
    }
  }

  Future<void> _createNewPdf() async {
    try {
      final options = await _showCreatePdfDialog();
      if (!mounted || options == null) {
        return;
      }
      final bytes = await _documentCreator.createBlankPdf(options: options);
      if (!mounted) {
        return;
      }
      await _setActiveDocument(
        source: PdfDocumentSource.bytes(bytes),
        label: _blankPdfLabel(options),
        mode: _EditorMode.authoring,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Created ${_blankPdfLabel(options)}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Create PDF failed: $error';
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        pagePreset = value;
                      });
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
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        orientation = value;
                      });
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
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        pageCount = value;
                      });
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
    final sizeLabel = switch (options.pagePreset) {
      PdfCreatePagePreset.a4 => 'a4',
      PdfCreatePagePreset.letter => 'letter',
    };
    final orientationLabel = switch (options.orientation) {
      PdfCreateOrientation.portrait => 'portrait',
      PdfCreateOrientation.landscape => 'landscape',
    };
    return 'blank_${sizeLabel}_${orientationLabel}_${options.pageCount}p.pdf';
  }

  Future<File> _ensureExportedPdf({bool forceRegenerate = false}) async {
    final activePdfSource = _activePdfSource;
    if (activePdfSource == null) {
      throw StateError('No PDF is loaded.');
    }
    if (!forceRegenerate && _lastExportedFile != null) {
      return _lastExportedFile!;
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/filled_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = await _exporter.exportToFile(
      source: activePdfSource,
      overlays: _editorMode == _EditorMode.authoring
          ? _overlayController.overlays
          : const <PdfOverlayItem>[],
      formFields: _editorMode == _EditorMode.formFill
          ? _formController.fields
          : const <PdfFormField>[],
      outputPath: outputPath,
      options: const PdfExportOptions(renderScale: 2.0),
    );
    _lastExportedFile = file;
    return file;
  }

  Future<void> _exportPdf() async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
      _exportMessage = null;
    });

    try {
      final file = await _ensureExportedPdf(forceRegenerate: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage =
            'Exported flattened PDF to ${file.path} (${file.lengthSync()} bytes)';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _exportEditablePdf() {
    if (_editorMode == _EditorMode.authoring) {
      setState(() {
        _exportMessage =
            'Editable export is only available for opened AcroForm PDFs. Blank Phase 7 documents export as flattened PDFs for now.';
      });
      return;
    }
    _saveEditablePdf();
  }

  Future<File> _ensureEditableExportedPdf({
    bool forceRegenerate = false,
  }) async {
    final activePdfSource = _activePdfSource;
    if (activePdfSource == null) {
      throw StateError('No PDF is loaded.');
    }
    if (!forceRegenerate && _lastEditableExportedFile != null) {
      return _lastEditableExportedFile!;
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/editable_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = await _editableExporter.exportToFile(
      source: activePdfSource,
      formFields: _formController.fields,
      outputPath: outputPath,
    );
    _lastEditableExportedFile = file;
    return file;
  }

  Future<void> _saveEditablePdf() async {
    if (_isExporting) {
      return;
    }
    setState(() {
      _isExporting = true;
      _exportMessage = null;
    });

    try {
      final file = await _ensureEditableExportedPdf(forceRegenerate: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage =
            'Exported editable PDF to ${file.path} (${file.lengthSync()} bytes)';
      });
    } on PdfEditableExportException catch (error) {
      try {
        final file = await _ensureExportedPdf(forceRegenerate: true);
        if (!mounted) {
          return;
        }
        setState(() {
          _exportMessage =
              'Editable export unsupported for this PDF state (${error.message}). '
              'Exported flattened PDF instead to ${file.path} (${file.lengthSync()} bytes).';
        });
      } catch (fallbackError) {
        if (!mounted) {
          return;
        }
        setState(() {
          _exportMessage =
              'Editable export failed: ${error.message}. Flattened fallback also failed: $fallbackError';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Editable export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _savePdfToUserPath() async {
    try {
      final exportedFile = await _ensureExportedPdf();
      final exportedBytes = await exportedFile.readAsBytes();
      final suggestedName = exportedFile.uri.pathSegments.isNotEmpty
          ? exportedFile.uri.pathSegments.last
          : 'filled.pdf';
      final destinationPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save filled PDF',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
        bytes: exportedBytes,
      );
      if (!mounted || destinationPath == null) {
        return;
      }
      setState(() {
        _exportMessage =
            'Saved filled PDF to $destinationPath (${exportedBytes.length} bytes)';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Save failed: $error';
      });
    }
  }

  Future<void> _shareExportedPdf() async {
    try {
      final exportedFile = await _ensureExportedPdf();
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(exportedFile.path)],
          text: 'Filled PDF export',
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Shared filled PDF from ${exportedFile.path}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Share failed: $error';
      });
    }
  }

  Future<void> _openExportedPdf() async {
    try {
      final exportedFile = await _ensureExportedPdf();
      final result = await OpenFilex.open(exportedFile.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage =
            'Open result: ${result.type.name}${result.message.isEmpty ? '' : ' (${result.message})'}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportMessage = 'Open failed: $error';
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
    final metadata = _pageInfo;
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
    final isAuthoringMode = _editorMode == _EditorMode.authoring;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Renderer Bridge Example'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: compactButtonStyle,
                  onPressed: _isLoadingDocument || _isExporting
                      ? null
                      : _pickPdfFile,
                  icon: const Icon(Icons.file_open_outlined, size: 18),
                  label: const Text('Open'),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: compactButtonStyle,
                  onPressed: _isLoadingDocument || _isExporting
                      ? null
                      : _createNewPdf,
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('Create'),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  style: compactFilledButtonStyle,
                  onPressed: _isLoadingDocument || _isExporting
                      ? null
                      : _exportPdf,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(_isExporting ? 'Exporting' : 'Flatten'),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: compactButtonStyle,
                  onPressed:
                      _isLoadingDocument || _isExporting || isAuthoringMode
                      ? null
                      : _exportEditablePdf,
                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                  label: const Text('Editable'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAuthoringMode
                  ? 'Phase 7 authoring mode: tap the blank PDF to place text, checkmarks, and signatures, then export the result.'
                  : 'Open an existing PDF or create a new blank PDF, then edit fields and export flattened or editable results.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  style: compactButtonStyle,
                  onPressed: _isLoadingDocument || _isExporting
                      ? null
                      : _savePdfToUserPath,
                  icon: const Icon(Icons.save_alt_outlined, size: 18),
                  label: const Text('Save As'),
                ),
                OutlinedButton.icon(
                  style: compactButtonStyle,
                  onPressed: _isLoadingDocument || _isExporting
                      ? null
                      : _shareExportedPdf,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
                OutlinedButton.icon(
                  style: compactButtonStyle,
                  onPressed: _isLoadingDocument || _isExporting
                      ? null
                      : _openExportedPdf,
                  icon: const Icon(Icons.open_in_new_outlined, size: 18),
                  label: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Current PDF: $_activePdfLabel',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            if (_exportMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _exportMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_documentInfo != null && metadata != null)
              ValueListenableBuilder<int>(
                valueListenable: _viewerController.currentPage,
                builder: (context, currentPage, child) {
                  return Text(
                    'Pages: ${_documentInfo!.pageCount} | '
                    'Page 1 size: ${metadata.width.toStringAsFixed(0)} x ${metadata.height.toStringAsFixed(0)} | '
                    'Current page: $currentPage | '
                    '${isAuthoringMode ? 'Overlays' : 'Detected fields'}: '
                    '${isAuthoringMode ? _overlayController.overlays.length : _formController.fields.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              )
            else
              Text(
                _isLoadingDocument
                    ? 'Loading document metadata...'
                    : 'Document metadata unavailable.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _activePdfSource == null
                      ? const Center(child: CircularProgressIndicator())
                      : (isAuthoringMode
                            ? PdfOverlayEditor(
                                source: _activePdfSource!,
                                controller: _overlayController,
                                viewerController: _viewerController,
                                initialZoom: 1,
                                maxZoom: 6,
                                onPickImageBytes: _pickImageFile,
                              )
                            : PdfFormEditor(
                                source: _activePdfSource!,
                                controller: _formController,
                                viewerController: _viewerController,
                                initialZoom: 1,
                                maxZoom: 6,
                              )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
