// dart:io's zlib on Android, iOS and desktop; a stub on web for now.
export 'zlib_stub.dart' if (dart.library.io) 'zlib_io.dart';
