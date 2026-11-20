import 'dart:io' show ZLibDecoder, ZLibEncoder;
import 'dart:typed_data';

/// Inflates zlib (FlateDecode) data.
///
/// Damaged or truncated streams are common in real PDFs, so whatever could be
/// decoded before an error is returned instead of failing outright.
Uint8List zlibInflate(Uint8List data) {
  final output = <int>[];
  try {
    ZLibDecoder().startChunkedConversion(_Collector(output))
      ..add(data)
      ..close();
  } on Object {
    if (output.isEmpty) {
      return _inflateRaw(data);
    }
  }
  return Uint8List.fromList(output);
}

/// Some producers omit the 2-byte zlib header; retry as raw deflate.
Uint8List _inflateRaw(Uint8List data) {
  final output = <int>[];
  try {
    ZLibDecoder(raw: true).startChunkedConversion(_Collector(output))
      ..add(data.length > 2 ? Uint8List.sublistView(data, 2) : data)
      ..close();
  } on Object {
    // Keep whatever was decoded.
  }
  return Uint8List.fromList(output);
}

/// Compresses [data] with zlib (FlateDecode).
Uint8List zlibDeflate(Uint8List data) =>
    Uint8List.fromList(ZLibEncoder().convert(data));

final class _Collector implements Sink<List<int>> {
  _Collector(this._output);

  final List<int> _output;

  @override
  void add(List<int> chunk) => _output.addAll(chunk);

  @override
  void close() {}
}
