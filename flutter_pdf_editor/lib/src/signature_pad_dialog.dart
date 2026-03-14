import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Modal signature pad that captures a handwritten signature as PNG bytes.
class SignaturePadDialog extends StatefulWidget {
  /// Creates a signature pad dialog.
  const SignaturePadDialog({super.key, this.initialBytes});

  /// Optional existing signature image used as the initial preview.
  final Uint8List? initialBytes;

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _previewBytes = widget.initialBytes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Signature'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _previewBytes = null;
                      _strokes.add(<Offset>[details.localPosition]);
                    });
                  },
                  onPanUpdate: (details) {
                    if (_strokes.isEmpty) {
                      return;
                    }
                    setState(() {
                      _strokes.last.add(details.localPosition);
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_previewBytes != null)
                        Image.memory(_previewBytes!, fit: BoxFit.contain),
                      CustomPaint(
                        painter: _SignaturePainter(
                          strokes: _strokes
                              .map((stroke) => List<Offset>.of(stroke))
                              .toList(growable: false),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _strokes.clear();
                      _previewBytes = null;
                    });
                  },
                  child: const Text('Clear'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _strokes.isEmpty && _previewBytes == null
                      ? null
                      : () async {
                          if (_strokes.isEmpty && _previewBytes != null) {
                            Navigator.of(context).pop(_previewBytes);
                            return;
                          }
                          final bytes = await renderSignaturePng(
                            strokes: _strokes,
                            size: const Size(400, 180),
                          );
                          if (!mounted) {
                            return;
                          }
                          Navigator.of(context).pop(bytes);
                        },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.isEmpty) {
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var index = 1; index < stroke.length; index++) {
        path.lineTo(stroke[index].dx, stroke[index].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

Future<Uint8List> renderSignaturePng({
  required List<List<Offset>> strokes,
  required Size size,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..color = const Color(0xFF111827)
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  for (final stroke in strokes) {
    if (stroke.isEmpty) {
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var index = 1; index < stroke.length; index++) {
      path.lineTo(stroke[index].dx, stroke[index].dy);
    }
    canvas.drawPath(path, paint);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Failed to create signature image.');
  }
  return bytes.buffer.asUint8List();
}
