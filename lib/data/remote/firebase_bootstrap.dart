import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// Outcome of attempting to initialise Firebase at startup.
enum FirebaseStatus {
  /// Firebase initialised and the platform is connected to a project.
  ready,

  /// Firebase initialised against the emulator / a local instance.
  emulator,

  /// No configuration is present, or initialisation failed. The app must keep
  /// working on local storage in this state.
  unavailable,
}

/// The result of the startup attempt, including the reason when unavailable.
class FirebaseBootstrapResult {
  const FirebaseBootstrapResult(this.status, {this.detail});

  final FirebaseStatus status;

  /// Human-readable reason, safe to log. Never contains credentials.
  final String? detail;

  /// Whether the remote repositories can be used.
  bool get isUsable =>
      status == FirebaseStatus.ready || status == FirebaseStatus.emulator;

  @override
  String toString() =>
      'FirebaseBootstrapResult(${status.name}${detail == null ? '' : ': $detail'})';
}

/// Initialises Firebase if — and only if — the project is configured.
///
/// ## Why this is defensive
///
/// `phase.md` Phase 7's goal is "Connect Firebase **without changing local game
/// behavior**". The repository deliberately commits **no** Firebase client
/// config: `.gitignore` excludes `google-services.json` and
/// `GoogleService-Info.plist` with the note "Never merge exceptions for these
/// paths", and `rules.md` §14 says no credential material is committed. So a
/// fresh clone has no configuration, and `Firebase.initializeApp()` will throw.
///
/// The correct behaviour in that case is to carry on with local storage, not to
/// crash — so initialisation is attempted, every failure is caught, and the
/// status is reported for the caller to branch on.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  /// Attempts initialisation, optionally with explicit [options].
  ///
  /// [options] is normally null: Android and iOS read their own
  /// `google-services.json` / `GoogleService-Info.plist`, which are
  /// git-ignored. Web has no such file, so `flutterfire configure` generates
  /// `firebase_options.dart` locally and the caller passes the values in.
  static Future<FirebaseBootstrapResult> initialize({
    FirebaseOptions? options,
  }) async {
    try {
      final app = await Firebase.initializeApp(options: options);
      return FirebaseBootstrapResult(
        _usesEmulator(app.options.projectId)
            ? FirebaseStatus.emulator
            : FirebaseStatus.ready,
        detail: 'project ${app.options.projectId}',
      );
    } on FirebaseException catch (e) {
      return FirebaseBootstrapResult(
        FirebaseStatus.unavailable,
        detail: 'FirebaseException(${e.code})',
      );
    } on Object catch (e) {
      return FirebaseBootstrapResult(
        FirebaseStatus.unavailable,
        detail: e.runtimeType.toString(),
      );
    }
  }

  /// Whether the project id is one of the documented local-emulator ids.
  static bool _usesEmulator(String? projectId) =>
      projectId == 'demo-wallforge' || projectId == 'demo-test';
}
