import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lock overlay screen displayed when a protected app is launched.
///
/// This screen is shown by the native LockOverlayActivity and embeds
/// Flutter for a seamless gait authentication experience.
class LockOverlayScreen extends StatefulWidget {
  const LockOverlayScreen({
    super.key,
    required this.packageName,
    required this.displayName,
  });

  final String packageName;
  final String displayName;

  @override
  State<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends State<LockOverlayScreen>
    with SingleTickerProviderStateMixin {
  static const _lockChannel = MethodChannel('com.example.gait_guard_app/lock_overlay');

  late AnimationController _animationController;
  bool _isAuthenticating = false;
  double _confidence = 0.0;
  String _statusMessage = 'Walk to authenticate';
  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Start simulated authentication after a short delay
    Future.delayed(const Duration(milliseconds: 500), _startAuthentication);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startAuthentication() {
    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Analyzing gait pattern...';
    });

    // Simulate gait authentication (in real app, this would use actual sensor data)
    _simulateGaitAuthentication();
  }

  void _simulateGaitAuthentication() {
    // Simulate confidence building over 3 seconds
    int ticks = 0;
    const totalTicks = 30;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      ticks++;

      // Simulate confidence increasing with some randomness
      final targetConfidence = 0.75 + (Random().nextDouble() * 0.2);
      setState(() {
        _confidence = (ticks / totalTicks) * targetConfidence;
        _confidence = _confidence.clamp(0.0, 1.0);
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        _onAuthenticationComplete();
      }
    });
  }

  void _onAuthenticationComplete() {
    final success = _confidence >= 0.7;

    setState(() {
      _isAuthenticating = false;
      _statusMessage = success
          ? 'Authentication successful!'
          : 'Authentication failed. Try again.';
    });

    if (success) {
      // Notify native side of success
      _lockChannel.invokeMethod('onAuthenticationSuccess');
    } else {
      // Show failure for a moment, then allow retry
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _confidence = 0.0;
            _statusMessage = 'Walk to authenticate';
          });
        }
      });
    }
  }

  void _onCancel() {
    _lockChannel.invokeMethod('onCancel');
  }

  void _onRetry() {
    setState(() {
      _confidence = 0.0;
      _isAuthenticating = false;
    });
    _startAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Lock icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: 64,
                  color: colorScheme.error,
                ),
              ),

              const SizedBox(height: 32),

              // App name
              Text(
                widget.displayName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'This app is protected',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const Spacer(),

              // Walking animation
              SizedBox(
                height: 120,
                child: _buildWalkingAnimation(colorScheme),
              ),

              const SizedBox(height: 24),

              // Status message
              Text(
                _statusMessage,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _confidence >= 0.7 ? Colors.green : colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Confidence progress
              if (_isAuthenticating || _confidence > 0) ...[
                _buildConfidenceIndicator(colorScheme),
                const SizedBox(height: 8),
                Text(
                  'Confidence: ${(_confidence * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodyMedium,
                ),
              ],

              const Spacer(),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: !_isAuthenticating ? _onRetry : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalkingAnimation(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 100),
          painter: _WalkingAnimationPainter(
            progress: _animationController.value,
            color: _isAuthenticating ? colorScheme.primary : colorScheme.outline,
            isActive: _isAuthenticating,
          ),
        );
      },
    );
  }

  Widget _buildConfidenceIndicator(ColorScheme colorScheme) {
    final color = _confidence >= 0.7
        ? Colors.green
        : _confidence >= 0.5
            ? Colors.orange
            : colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: _confidence,
        minHeight: 12,
        backgroundColor: colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class _WalkingAnimationPainter extends CustomPainter {
  _WalkingAnimationPainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  final double progress;
  final Color color;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw walking person icon animation
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Body
    final bodyTop = Offset(centerX, centerY - 20);
    final bodyBottom = Offset(centerX, centerY + 10);
    canvas.drawLine(bodyTop, bodyBottom, paint);

    // Head
    canvas.drawCircle(Offset(centerX, centerY - 30), 10, paint);

    // Arms swing
    final armSwing = sin(progress * 2 * pi) * 15;
    canvas.drawLine(
      Offset(centerX, centerY - 15),
      Offset(centerX - 20 + armSwing, centerY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - 15),
      Offset(centerX + 20 - armSwing, centerY),
      paint,
    );

    // Legs swing
    final legSwing = sin(progress * 2 * pi) * 20;
    canvas.drawLine(
      bodyBottom,
      Offset(centerX - 15 + legSwing, centerY + 35),
      paint,
    );
    canvas.drawLine(
      bodyBottom,
      Offset(centerX + 15 - legSwing, centerY + 35),
      paint,
    );

    // Draw footsteps if active
    if (isActive) {
      final footPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 5; i++) {
        final x = (i * 40) + (progress * 40) - 60;
        final opacity = 1.0 - (i * 0.2);
        footPaint.color = color.withValues(alpha: opacity * 0.3);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, centerY + 45),
            width: 8,
            height: 4,
          ),
          footPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WalkingAnimationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive ||
        oldDelegate.color != color;
  }
}

/// Parse route arguments for lock overlay
class LockOverlayArgs {
  const LockOverlayArgs({
    required this.packageName,
    required this.displayName,
  });

  final String packageName;
  final String displayName;

  factory LockOverlayArgs.fromUri(Uri uri) {
    return LockOverlayArgs(
      packageName: uri.queryParameters['package'] ?? '',
      displayName: uri.queryParameters['name'] ?? 'Unknown App',
    );
  }
}
