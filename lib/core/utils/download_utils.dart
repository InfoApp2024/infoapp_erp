// Cross-platform download/open helpers with conditional imports.
// On web, uses dart:html; on mobile/desktop, uses dart:io + share_plus.

import 'download_utils_io.dart' if (dart.library.html) 'download_utils_web.dart' as impl;

Future<void> saveBytes(String filename, List<int> bytes, {String? mimeType}) {
  return impl.saveBytes(filename, bytes, mimeType: mimeType);
}

Future<void> saveText(String filename, String text, {String? mimeType}) {
  return impl.saveText(filename, text, mimeType: mimeType);
}

Future<void> openExternalUrl(String url) {
  return impl.openExternalUrl(url);
}
