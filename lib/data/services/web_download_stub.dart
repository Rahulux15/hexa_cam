import 'dart:typed_data';

Future<void> downloadBytesWeb(
  Uint8List bytes,
  String filename, {
  String? mimeType,
}) async {
  throw UnsupportedError('Web downloads are only available on web builds.');
}
