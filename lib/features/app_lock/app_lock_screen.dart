import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/app_lock_service.dart';
import '../../core/services/database_service.dart';
import '../../data/models/protected_app.dart';
import '../../data/repositories/app_lock_repository.dart';
import 'logic/app_lock_cubit.dart';
import 'logic/app_lock_state.dart';

/// Screen for managing app lock settings and viewing lock status.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with WidgetsBindingObserver {
  late AppLockCubit _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Create dependencies
    final repository = AppLockRepositoryImpl(DatabaseService.instance);
    final service = AppLockService(repository: repository);

    // Create cubit
    _cubit = AppLockCubit(service);

    // Initialize with user ID (hardcoded for demo, would come from auth)
    _cubit.initialize(1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh permissions when returning from settings
    if (state == AppLifecycleState.resumed) {
      _cubit.refreshPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('App Lock'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _cubit.refresh(),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: BlocConsumer<AppLockCubit, AppLockState>(
          listener: (context, state) {
            if (state is AppLockError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else if (state is AppLockAllLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${state.lockedCount} apps locked'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else if (state is AppLockUnlockSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${state.displayName} unlocked (${(state.confidence * 100).toStringAsFixed(0)}% confidence)',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is AppLockUnlockFailed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Unlock failed: ${state.reason}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is AppLockInitial || state is AppLockLoading) {
              return _buildLoading(state);
            } else if (state is AppLockReady) {
              return _buildReady(context, state);
            } else if (state is AppLockAuthenticating) {
              return _buildAuthenticating(context, state);
            } else if (state is AppLockUnlockSuccess) {
              return _buildUnlockSuccess(context, state);
            } else if (state is AppLockUnlockFailed) {
              return _buildUnlockFailed(context, state);
            } else if (state is AppLockAllLocked) {
              return _buildAllLocked(context, state);
            } else if (state is AppLockError) {
              return _buildError(context, state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLoading(AppLockState state) {
    final message = state is AppLockLoading ? state.message : 'Loading...';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message ?? 'Loading...'),
        ],
      ),
    );
  }

  Widget _buildReady(BuildContext context, AppLockReady state) {
    return RefreshIndicator(
      onRefresh: () => _cubit.refresh(),
      child: CustomScrollView(
        slivers: [
          // Permission setup card (if needed)
          if (state.needsPermissionSetup)
            SliverToBoxAdapter(
              child: _buildPermissionCard(context, state),
            ),

          // Status card
          SliverToBoxAdapter(
            child: _buildStatusCard(context, state),
          ),

          // Lock all button if there are protected apps
          if (state.hasProtectedApps)
            SliverToBoxAdapter(
              child: _buildLockAllButton(context, state),
            ),

          // Locked apps section
          if (state.hasLockedApps) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'Locked Apps'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildLockedAppTile(
                  context,
                  state.lockedApps[index],
                ),
                childCount: state.lockedApps.length,
              ),
            ),
          ],

          // Available apps section
          const SliverToBoxAdapter(
            child: _SectionHeader(title: 'Available Apps'),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildAppTile(
                context,
                state.availableApps[index],
              ),
              childCount: state.availableApps.length,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(BuildContext context, AppLockReady state) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Setup Required',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'App locking requires special permissions to detect and block protected apps.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 16),

            // Accessibility Service
            _PermissionRow(
              icon: Icons.accessibility_new,
              title: 'Accessibility Service',
              description: 'Detects when protected apps are opened',
              isGranted: state.accessibilityEnabled,
              onTap: () => _cubit.openAccessibilitySettings(),
            ),

            const SizedBox(height: 8),

            // Overlay Permission
            _PermissionRow(
              icon: Icons.layers,
              title: 'Display Over Apps',
              description: 'Shows lock screen over protected apps',
              isGranted: state.overlayPermissionGranted,
              onTap: () => _cubit.requestOverlayPermission(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, AppLockReady state) {
    final theme = Theme.of(context);
    final hasLockedApps = state.hasLockedApps;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasLockedApps ? Icons.lock : Icons.lock_open,
                  size: 32,
                  color: hasLockedApps
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLockedApps ? 'Apps Locked' : 'All Apps Unlocked',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${state.protectedCount} protected, ${state.lockedCount} locked',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (state.stats != null) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Total Locks',
                    value: '${state.stats!['totalLockSessions'] ?? 0}',
                  ),
                  _StatItem(
                    label: 'Unlocks',
                    value: '${state.stats!['successfulUnlocks'] ?? 0}',
                  ),
                  _StatItem(
                    label: 'Avg Confidence',
                    value:
                        '${((state.stats!['averageUnlockConfidence'] ?? 0.0) * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLockAllButton(BuildContext context, AppLockReady state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: state.hasLockedApps ? null : () => _cubit.lockAllApps(),
        icon: const Icon(Icons.lock),
        label: Text(
          state.hasLockedApps
              ? 'All Protected Apps Locked'
              : 'Lock All Protected Apps',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  Widget _buildLockedAppTile(BuildContext context, ProtectedApp app) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: app.buildIcon(
            size: 32,
            color: theme.colorScheme.error,
          ),
        ),
      ),
      title: Text(app.displayName),
      subtitle: const Text('Tap to unlock with gait'),
      trailing: const Icon(Icons.lock, color: Colors.red),
      onTap: () => _cubit.attemptUnlock(app.packageName, app.displayName),
    );
  }

  Widget _buildAppTile(BuildContext context, ProtectedApp app) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: app.isProtected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: app.buildIcon(
            size: 32,
            color: app.isRealApp
                ? null // Use actual icon colors for real apps
                : (app.isProtected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      title: Text(app.displayName),
      subtitle: Text(
        app.isProtected ? 'Protected' : 'Not protected',
        style: TextStyle(
          color: app.isProtected ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: Switch(
        value: app.isProtected,
        onChanged: (value) => _cubit.toggleAppProtection(app.packageName),
      ),
    );
  }

  Widget _buildAuthenticating(
      BuildContext context, AppLockAuthenticating state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_walk,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Authenticating...',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Unlocking ${state.displayName}',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Walk naturally to verify your gait',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => _cubit.cancelUnlock(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockSuccess(BuildContext context, AppLockUnlockSuccess state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              'Unlocked!',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.displayName,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Confidence: ${(state.confidence * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockFailed(BuildContext context, AppLockUnlockFailed state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Unlock Failed',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.displayName,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              state.reason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () =>
                  _cubit.attemptUnlock(state.packageName, state.displayName),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllLocked(BuildContext context, AppLockAllLocked state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Apps Locked',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.lockedCount} apps have been locked',
              style: theme.textTheme.bodyLarge,
            ),
            if (state.reason != null) ...[
              const SizedBox(height: 16),
              Text(
                state.reason!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLockError state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _cubit.refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: isGranted ? Colors.green : theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (isGranted)
              const Icon(Icons.check_circle, color: Colors.green)
            else
              TextButton(
                onPressed: onTap,
                child: const Text('Enable'),
              ),
          ],
        ),
      ),
    );
  }
}
