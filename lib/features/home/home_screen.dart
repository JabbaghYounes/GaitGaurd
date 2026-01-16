import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/database_service.dart';
import '../../data/datasources/local/calibration_local_data_source.dart';
import '../../data/repositories/app_lock_repository.dart';
import '../../data/models/protected_app.dart';
import '../gait/calibration_screen.dart';
import '../app_lock/app_lock_screen.dart';
import '../settings/settings_screen.dart';
import 'logic/home_cubit.dart';
import 'logic/home_state.dart';

/// Main home screen showing gait status and protected apps.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeCubit _cubit;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // Create dependencies
    final databaseService = DatabaseService.instance;
    final calibrationRepository = CalibrationRepositoryImpl(databaseService);
    final appLockRepository = AppLockRepositoryImpl(databaseService);

    // Create cubit
    _cubit = HomeCubit(
      calibrationRepository: calibrationRepository,
      appLockRepository: appLockRepository,
    );

    // Initialize with user ID (hardcoded for demo)
    _cubit.initialize(1);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _cubit,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            const AppLockScreen(),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_outlined),
              selectedIcon: Icon(Icons.lock),
              label: 'App Lock',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GaitGuard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _cubit.refresh(1),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocConsumer<HomeCubit, HomeState>(
        listener: (context, state) {
          if (state is HomeError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is HomeInitial || state is HomeLoading) {
            return _buildLoading(state);
          } else if (state is HomeLoaded) {
            return _buildLoaded(context, state);
          } else if (state is HomeError) {
            return _buildError(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoading(HomeState state) {
    final message = state is HomeLoading ? state.message : 'Loading...';
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

  Widget _buildLoaded(BuildContext context, HomeLoaded state) {
    return RefreshIndicator(
      onRefresh: () => _cubit.refresh(state.userId),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Gait Status Card
          _buildGaitStatusCard(context, state),

          const SizedBox(height: 16),

          // Quick Actions
          _buildQuickActions(context, state),

          const SizedBox(height: 24),

          // Protected Apps Section
          _buildSectionHeader(context, 'Protected Apps'),
          const SizedBox(height: 8),

          if (state.hasProtectedApps)
            _buildProtectedAppsList(context, state)
          else
            _buildNoProtectedApps(context),

          // Locked Apps Section (if any)
          if (state.hasLockedApps) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Locked Apps'),
            const SizedBox(height: 8),
            _buildLockedAppsList(context, state),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGaitStatusCard(BuildContext context, HomeLoaded state) {
    final theme = Theme.of(context);
    final gaitStatus = state.gaitStatus;

    Color statusColor;
    IconData statusIcon;

    if (!gaitStatus.hasCalibration) {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.warning_amber_rounded;
    } else if (gaitStatus.isAuthenticated) {
      statusColor = Colors.green;
      statusIcon = Icons.verified_user;
    } else {
      statusColor = theme.colorScheme.tertiary;
      statusIcon = Icons.shield_outlined;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status icon and text
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    size: 40,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gait Status',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gaitStatus.statusText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (gaitStatus.lastAuthTime != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Last check: ${gaitStatus.timeSinceAuth}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Stats row
            if (gaitStatus.hasCalibration) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Confidence',
                    value: gaitStatus.confidencePercentage,
                    icon: Icons.speed,
                  ),
                  _StatItem(
                    label: 'Success Rate',
                    value: gaitStatus.successRatePercentage,
                    icon: Icons.trending_up,
                  ),
                  _StatItem(
                    label: 'Quality',
                    value:
                        '${(gaitStatus.calibrationQuality * 100).toStringAsFixed(0)}%',
                    icon: Icons.star,
                  ),
                ],
              ),
            ],

            // Calibration prompt
            if (!gaitStatus.hasCalibration) ...[
              const Divider(height: 32),
              Text(
                'Complete calibration to enable gait-based authentication',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _navigateToCalibration(context),
                icon: const Icon(Icons.tune),
                label: const Text('Start Calibration'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, HomeLoaded state) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.directions_walk,
            label: 'Test Gait',
            color: theme.colorScheme.primary,
            onTap: () => _cubit.simulateAuthentication(state.userId),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.tune,
            label: 'Calibrate',
            color: theme.colorScheme.secondary,
            onTap: () => _navigateToCalibration(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.lock,
            label: 'Lock All',
            color: theme.colorScheme.error,
            onTap: state.hasProtectedApps
                ? () => _showLockAllDialog(context, state.userId)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildProtectedAppsList(BuildContext context, HomeLoaded state) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.protectedApps.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final app = state.protectedApps[index];
          return _buildAppTile(context, app, state);
        },
      ),
    );
  }

  Widget _buildAppTile(
      BuildContext context, ProtectedApp app, HomeLoaded state) {
    final theme = Theme.of(context);
    final isLocked =
        state.lockedApps.any((a) => a.packageName == app.packageName);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isLocked
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.primaryContainer,
        child: Icon(
          app.iconData,
          color: isLocked
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
      ),
      title: Text(app.displayName),
      subtitle: Text(
        isLocked ? 'Locked - tap to unlock' : 'Protected',
        style: TextStyle(
          color: isLocked ? theme.colorScheme.error : null,
        ),
      ),
      trailing: Icon(
        isLocked ? Icons.lock : Icons.check_circle,
        color: isLocked ? theme.colorScheme.error : Colors.green,
      ),
      onTap: isLocked
          ? () => _cubit.attemptUnlock(state.userId, app.packageName)
          : null,
    );
  }

  Widget _buildLockedAppsList(BuildContext context, HomeLoaded state) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.lockedApps.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final app = state.lockedApps[index];
          return _buildLockedAppTile(context, app, state);
        },
      ),
    );
  }

  Widget _buildLockedAppTile(
      BuildContext context, ProtectedApp app, HomeLoaded state) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.errorContainer,
        child: Icon(
          app.iconData,
          color: theme.colorScheme.error,
        ),
      ),
      title: Text(app.displayName),
      subtitle: const Text('Tap to unlock with gait'),
      trailing: const Icon(Icons.lock, color: Colors.red),
      onTap: () => _cubit.attemptUnlock(state.userId, app.packageName),
    );
  }

  Widget _buildNoProtectedApps(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.apps_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Protected Apps',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add apps to protect them with gait authentication',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentIndex = 1),
              icon: const Icon(Icons.add),
              label: const Text('Add Apps'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCalibration(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalibrationScreen()),
    ).then((_) => _cubit.refresh(1));
  }

  void _showLockAllDialog(BuildContext context, int userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock All Apps?'),
        content: const Text(
          'This will lock all protected apps. You will need to authenticate with your gait to unlock them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cubit.lockAllApps(userId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Lock All'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, HomeError state) {
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
              onPressed: () => _cubit.initialize(1),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

    return Card(
      color: isEnabled ? color.withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isEnabled ? color : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isEnabled ? color : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
