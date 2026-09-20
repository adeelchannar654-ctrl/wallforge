import 'package:flutter/material.dart';

import '../core/constants/app_info.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget of the Wallforge application.
///
/// Kept deliberately thin: it wires the theme and the centralised router.
/// Game logic and Firebase integration are intentionally absent in Phase 0.
class WallforgeApp extends StatelessWidget {
  const WallforgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
