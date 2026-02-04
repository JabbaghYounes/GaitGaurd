import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'features/app_lock/lock_overlay_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GaitGuardApp());
}

class GaitGuardApp extends StatelessWidget {
  const GaitGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GaitGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      onGenerateRoute: _generateRoute,
      home: const HomeScreen(),
    );
  }

  /// Generate routes for deep linking and native navigation.
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');

    // Handle lock overlay route (used by native LockOverlayActivity)
    if (uri.path == '/lock_overlay') {
      final args = LockOverlayArgs.fromUri(uri);
      return MaterialPageRoute(
        builder: (_) => LockOverlayScreen(
          packageName: args.packageName,
          displayName: args.displayName,
        ),
        settings: settings,
      );
    }

    // Default: return null to let MaterialApp handle it
    return null;
  }
}
