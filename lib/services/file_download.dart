import 'dart:convert';
import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';

/// Скачивание файла на устройство пользователя. На Web — через
/// `data:`-URL и эмулированный клик по `<a download>`. На остальных
/// платформах сейчас бросает `UnsupportedError` (приложение целевое
/// для веба; для нативных платформ можно прикрутить file_saver).
class FileDownload {
  FileDownload._();

  static Future<void> downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) =>
      downloadBytesImpl(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );

  static Future<void> downloadText({
    required String content,
    required String filename,
    required String mimeType,
  }) =>
      downloadBytes(
        bytes: Uint8List.fromList(utf8.encode(content)),
        filename: filename,
        mimeType: mimeType,
      );
}
