import 'dart:typed_data';

Future<void> downloadBytesImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  throw UnsupportedError(
    'Скачивание файлов поддерживается только в веб-версии приложения.',
  );
}
