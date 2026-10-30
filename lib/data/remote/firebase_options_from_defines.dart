import 'package:firebase_core/firebase_core.dart';

/// Web Firebase options supplied at build/run time via `--dart-define`
/// (Phase 15, A.4).
///
/// A clean clone carries no Firebase client configuration: Android and
/// iOS read their git-ignored `google-services.json` /
/// `GoogleService-Info.plist`, but web has no file of its own — the
/// FlutterFire flow generates `lib/firebase_options.dart`, which this
/// project deliberately does not commit (see `.gitignore`). Without a
/// supported way to pass the values, a web build from a clean clone
/// could never initialise Firebase without editing tracked files.
///
/// The supported mechanism is build-time defines:
///
/// ```sh
/// flutter run -d chrome \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FIREBASE_PROJECT_ID=wallforge-efdb3 \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///   --dart-define=FIREBASE_AUTH_DOMAIN=...      (optional) \
///   --dart-define=FIREBASE_STORAGE_BUCKET=...   (optional)
/// ```
///
/// [maybe] returns options only when every required value is present,
/// so an ordinary build without the defines behaves exactly as before:
/// Firebase stays unavailable and the app runs on local storage.
class FirebaseOptionsFromDefines {
  const FirebaseOptionsFromDefines._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  /// The options from this build's `--dart-define` values, or null when
  /// they were not (fully) supplied.
  static FirebaseOptions? maybe() => fromValues(
    apiKey: _apiKey,
    appId: _appId,
    projectId: _projectId,
    messagingSenderId: _messagingSenderId,
    // The next two read as redundant only in a build WITHOUT the
    // defines (where they equal the parameter defaults); in a build
    // with the defines they carry the real values.
    // ignore: avoid_redundant_argument_values
    authDomain: _authDomain,
    // ignore: avoid_redundant_argument_values
    storageBucket: _storageBucket,
  );

  /// Pure mapping seam (unit-tested with fake values): options exist
  /// only when all four required values are non-empty; the two optional
  /// values map to null when absent.
  static FirebaseOptions? fromValues({
    required String apiKey,
    required String appId,
    required String projectId,
    required String messagingSenderId,
    String authDomain = '',
    String storageBucket = '',
  }) {
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        projectId.isEmpty ||
        messagingSenderId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      projectId: projectId,
      messagingSenderId: messagingSenderId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
    );
  }
}
