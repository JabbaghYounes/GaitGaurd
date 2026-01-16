import 'package:flutter/material.dart';

import '../features/app_lock/app_lock_screen.dart';
import '../features/gait/gait_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';

/// High-level navigation scaffold with bottom navigation.
///
/// This matches a typical security/productivity app layout:
/// - Lock status / home
/// - Gait recognition
/// - Profile
/// - Settings
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  static final _pages = <Widget>[
    const AppLockScreen(),
    const GaitScreen(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outline),
            activeIcon: Icon(Icons.lock),
            label: 'Lock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk_outlined),
            activeIcon: Icon(Icons.directions_walk),
            label: 'Gait',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}


