import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web implementation: wrap the bytes in a Blob, point an
/// anchor at its object URL, and click it — the standard
/// no-server download. The object URL is revoked immediately
/// after the click is dispatched.
bool downloadPngBytes(List<int> bytes, String fileName) {
  final blob = web.Blob(
    <JSUint8Array>[Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
  return true;
}
