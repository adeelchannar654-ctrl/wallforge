/// Downloads PNG bytes as a file in the browser (Phase 16.5,
/// Part G: the web fallback for the shareable result card).
///
/// Conditional export: the web implementation uses
/// `package:web`; every other platform gets the stub, which
/// reports failure so callers fall back honestly.
library;

export 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download_web.dart';
