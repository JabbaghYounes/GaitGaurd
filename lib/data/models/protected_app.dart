import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/services/native_app_service.dart';

/// Represents an app that can be protected by gait-based locking.
///
/// Supports both:
/// - Real apps detected from Android with base64 encoded icons
/// - Mock apps with Material Icons for fallback/demo
@immutable
class ProtectedApp {
  const ProtectedApp({
    this.id,
    required this.packageName,
    required this.displayName,
    this.iconData = Icons.apps,
    this.iconBase64,
    this.isProtected = false,
    this.isLocked = false,
    this.lastUnlockTime,
    this.lockCount = 0,
    this.isRealApp = false,
  });

  /// Database ID (null for apps not yet persisted)
  final int? id;

  /// Unique package identifier (e.g., 'com.bank.app')
  final String packageName;

  /// User-friendly display name
  final String displayName;

  /// Fallback icon to display (using IconData)
  final IconData iconData;

  /// Base64 encoded app icon from native Android (for real apps)
  final String? iconBase64;

  /// Whether user has enabled protection for this app
  final bool isProtected;

  /// Whether app is currently locked
  final bool isLocked;

  /// Last time app was successfully unlocked
  final DateTime? lastUnlockTime;

  /// Number of times app has been locked
  final int lockCount;

  /// Whether this is a real installed app (vs mock)
  final bool isRealApp;

  /// Check if app has a real icon (base64 encoded)
  bool get hasRealIcon => iconBase64 != null && iconBase64!.isNotEmpty;

  /// Get decoded icon bytes (for Image.memory)
  Uint8List? get iconBytes {
    if (!hasRealIcon) return null;
    try {
      return base64Decode(iconBase64!);
    } catch (_) {
      return null;
    }
  }

  /// Build icon widget (uses real icon if available, fallback to IconData)
  Widget buildIcon({double size = 40, Color? color}) {
    final bytes = iconBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(iconData, size: size, color: color),
        ),
      );
    }
    return Icon(iconData, size: size, color: color);
  }

  /// Create a copy with updated fields
  ProtectedApp copyWith({
    int? id,
    String? packageName,
    String? displayName,
    IconData? iconData,
    String? iconBase64,
    bool? isProtected,
    bool? isLocked,
    DateTime? lastUnlockTime,
    int? lockCount,
    bool? isRealApp,
  }) {
    return ProtectedApp(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      displayName: displayName ?? this.displayName,
      iconData: iconData ?? this.iconData,
      iconBase64: iconBase64 ?? this.iconBase64,
      isProtected: isProtected ?? this.isProtected,
      isLocked: isLocked ?? this.isLocked,
      lastUnlockTime: lastUnlockTime ?? this.lastUnlockTime,
      lockCount: lockCount ?? this.lockCount,
      isRealApp: isRealApp ?? this.isRealApp,
    );
  }

  /// Create from native InstalledApp
  factory ProtectedApp.fromInstalledApp(InstalledApp app, {
    bool isProtected = false,
    bool isLocked = false,
  }) {
    return ProtectedApp(
      packageName: app.packageName,
      displayName: app.displayName,
      iconBase64: app.iconBase64,
      isProtected: isProtected,
      isLocked: isLocked,
      isRealApp: true,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'package_name': packageName,
      'display_name': displayName,
      'icon_code_point': iconData.codePoint,
      'icon_base64': iconBase64,
      'is_protected': isProtected ? 1 : 0,
      'is_locked': isLocked ? 1 : 0,
      'last_unlock_time': lastUnlockTime?.toIso8601String(),
      'lock_count': lockCount,
      'is_real_app': isRealApp ? 1 : 0,
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
      iconBase64: map['icon_base64'] as String?,
      isProtected: (map['is_protected'] as int?) == 1,
      isLocked: (map['is_locked'] as int?) == 1,
      lastUnlockTime: map['last_unlock_time'] != null
          ? DateTime.parse(map['last_unlock_time'] as String)
          : null,
      lockCount: map['lock_count'] as int? ?? 0,
      isRealApp: (map['is_real_app'] as int?) == 1,
    );
  }

  /// Mock apps for fallback when native app detection unavailable
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
        'isProtected: $isProtected, isLocked: $isLocked, isRealApp: $isRealApp)';
  }
}
