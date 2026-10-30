import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/logging/app_logger.dart';
import 'data/remote/firebase_bootstrap.dart';
import 'data/remote/firebase_options_from_defines.dart';

/// Application entry point.
///
/// Phase 7: Firebase is initialised at startup, but the outcome is deliberately
/// non-fatal. The repository commits no Firebase client configuration — see
/// `.gitignore`, which excludes `google-services.json` / `GoogleService-Info.plist`
/// with "never merge exceptions for these paths" — so a fresh clone cannot
/// initialise Firebase and `Firebase.initializeApp()` throws. Rather than crash
/// or block first paint on a network call, `ensureInitialized` catches every
/// failure and the app launches on local `shared_preferences` storage, which is
/// exactly the Phase 6 behaviour Phase 7 promises not to change.
void main() {
  const logger = AppLogger('main');
  logger.log('Launching Wallforge');
  unawaited(
    FirebaseBootstrap.initialize(
      // Web has no native config file: its options come from
      // --dart-define values when the build supplies them (Phase 15,
      // A.4; see FirebaseOptionsFromDefines). Native platforms read
      // their own git-ignored config files, so they pass null.
      options: kIsWeb ? FirebaseOptionsFromDefines.maybe() : null,
    ).then((result) {
      if (result.isUsable) {
        logger.log('Firebase ready: ${result.detail}');
      } else {
        // Not an error: this is the expected state for an unconfigured build.
        logger.log(
          'Firebase unavailable (${result.detail}); using local storage',
        );
      }
    }),
  );
  runApp(const WallforgeApp());
}
