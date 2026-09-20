import 'package:flutter/foundation.dart';

/// Severity levels for structured application logging (see `rules.md` §8).
enum LogLevel { debug, info, warning, error }

/// Minimal structured logging facade.
///
/// Phase 0 intentionally avoids a logging package. This facade centralises log
/// output so a real sink (e.g. Crashlytics) can be attached in a later phase
/// without touching call sites.
///
/// Rules: never log secrets, tokens or private user data. Debug logs are
/// suppressed in release builds.
class AppLogger {
  const AppLogger(this.scope);

  /// Logical source of the logs, e.g. a screen or service name.
  final String scope;

  /// Logs a message when [level] is at least as severe as the build's
  /// configured threshold.
  void log(String message, {LogLevel level = LogLevel.info}) {
    if (kReleaseMode && level == LogLevel.debug) {
      return;
    }

    // Developer tooling only: this is never shown to end users.
    debugPrint('[${level.name.toUpperCase()}] $scope: $message');
  }

  /// Convenience helper for debug-level events.
  void debug(String message) => log(message, level: LogLevel.debug);

  /// Convenience helper for error-level events.
  void error(String message) => log(message, level: LogLevel.error);
}
