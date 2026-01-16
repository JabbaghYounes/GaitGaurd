import 'package:flutter/material.dart';

/// Represents an app that can be protected by gait-based locking.
///
/// Since platform APIs for listing installed apps are limited (iOS prohibits it,
/// Android requires special permissions), this model supports both real apps
/// (if available) and simulated/mock apps for demonstration.
@immutable
class ProtectedApp {
  const ProtectedApp({
    this.id,
    required this.packageName,
    required this.displayName,
    this.iconData = Icons.apps,
    this.isProtected = false,
    this.isLocked = false,
    this.lastUnlockTime,
    this.lockCount = 0,
  });

  /// Database ID (null for mock apps not yet persisted)
  final int? id;

  /// Unique package identifier (e.g., 'com.bank.app')
  final String packageName;

  /// User-friendly display name
  final String displayName;

  /// Icon to display (using IconData for simplicity)
  final IconData iconData;

  /// Whether user has enabled protection for this app
  final bool isProtected;

  /// Whether app is currently locked
  final bool isLocked;

  /// Last time app was successfully unlocked
  final DateTime? lastUnlockTime;

  /// Number of times app has been locked
  final int lockCount;

  /// Create a copy with updated fields
  ProtectedApp copyWith({
    int? id,
    String? packageName,
    String? displayName,
    IconData? iconData,
    bool? isProtected,
    bool? isLocked,
    DateTime? lastUnlockTime,
    int? lockCount,
  }) {
    return ProtectedApp(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      displayName: displayName ?? this.displayName,
      iconData: iconData ?? this.iconData,
      isProtected: isProtected ?? this.isProtected,
      isLocked: isLocked ?? this.isLocked,
      lastUnlockTime: lastUnlockTime ?? this.lastUnlockTime,
      lockCount: lockCount ?? this.lockCount,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'package_name': packageName,
      'display_name': displayName,
      'icon_code_point': iconData.codePoint,
      'is_protected': isProtected ? 1 : 0,
      'is_locked': isLocked ? 1 : 0,
      'last_unlock_time': lastUnlockTime?.toIso8601String(),
      'lock_count': lockCount,
    };
  }

  /// Create from database map
  factory ProtectedApp.fromMap(Map<String, dynamic> map) {
    return ProtectedApp(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      displayName: map['display_name'] as String,
      iconData: IconData(
        map['icon_code_point'] as int? ?? Icons.apps.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      isProtected: (map['is_protected'] as int?) == 1,
      isLocked: (map['is_locked'] as int?) == 1,
      lastUnlockTime: map['last_unlock_time'] != null
          ? DateTime.parse(map['last_unlock_time'] as String)
          : null,
      lockCount: map['lock_count'] as int? ?? 0,
    );
  }

  /// Mock apps for simulation (since we can't list real installed apps)
  static List<ProtectedApp> get mockApps => const [
        ProtectedApp(
          packageName: 'com.bank.app',
          displayName: 'Banking App',
          iconData: Icons.account_balance,
        ),
        ProtectedApp(
          packageName: 'com.email.app',
          displayName: 'Email',
          iconData: Icons.email,
        ),
        ProtectedApp(
          packageName: 'com.photos.app',
          displayName: 'Photos',
          iconData: Icons.photo_library,
        ),
        ProtectedApp(
          packageName: 'com.notes.app',
          displayName: 'Notes',
          iconData: Icons.note,
        ),
        ProtectedApp(
          packageName: 'com.social.app',
          displayName: 'Social Media',
          iconData: Icons.people,
        ),
        ProtectedApp(
          packageName: 'com.wallet.app',
          displayName: 'Wallet',
          iconData: Icons.wallet,
        ),
        ProtectedApp(
          packageName: 'com.health.app',
          displayName: 'Health',
          iconData: Icons.favorite,
        ),
        ProtectedApp(
          packageName: 'com.messages.app',
          displayName: 'Messages',
          iconData: Icons.message,
        ),
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProtectedApp &&
        other.packageName == packageName &&
        other.isProtected == isProtected &&
        other.isLocked == isLocked;
  }

  @override
  int get hashCode => Object.hash(packageName, isProtected, isLocked);

  @override
  String toString() {
    return 'ProtectedApp(packageName: $packageName, displayName: $displayName, '
        'isProtected: $isProtected, isLocked: $isLocked)';
  }
}
