import 'package:flutter/material.dart';

/// Global navigation service for tab-based navigation.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static void navigateToSettingsTab() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Find the AppShell state and navigate to settings tab
      final appShellState = context.findAncestorStateOfType<_AppShellState>();
      appShellState?.navigateToTab(3); // Settings is index 3
    }
  }
}