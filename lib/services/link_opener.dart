import 'link_opener_stub.dart'
    if (dart.library.js_interop) 'link_opener_web.dart';

class LinkOpener {
  LinkOpener._();

  static Future<void> open(String url) => openLinkImpl(url);
}
