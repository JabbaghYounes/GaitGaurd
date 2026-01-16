import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/ui/login_screen.dart';

/// Root widget for the Gait Guard app.
///
/// Keeps global configuration (theme, routing, localization) in one place
/// to make it easy to extend for future features.
class GaitGuardApp extends StatelessWidget {
  const GaitGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gait Guard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const LoginScreen(),
    );
  }
}


