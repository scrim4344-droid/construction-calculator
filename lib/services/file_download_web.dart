import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadBytesImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final base64 = base64Encode(bytes);
  final href = 'data:$mimeType;base64,$base64';
  final anchor = web.HTMLAnchorElement()
    ..href = href
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
