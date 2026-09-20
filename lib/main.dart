import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/logging/app_logger.dart';

/// Application entry point.
///
/// Phase 0 performs no Firebase initialisation and no game-engine setup, so
/// the application launches fully offline.
void main() {
  const AppLogger('main').log('Launching Wallforge');
  runApp(const WallforgeApp());
}
