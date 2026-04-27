import 'package:web/web.dart' as web;

Future<void> openLinkImpl(String url) async {
  web.window.open(url, '_blank');
}
