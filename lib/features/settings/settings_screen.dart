import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/database_service.dart';
import '../../data/datasources/local/calibration_local_data_source.dart';
import '../../data/repositories/app_lock_repository.dart';
import 'logic/settings_cubit.dart';
import 'logic/settings_state.dart';

/// Settings screen for managing app preferences and data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsCubit _cubit;

  @override
  void initState() {
    super.initState();

    // Create dependencies
    final databaseService = DatabaseService.instance;
    final calibrationRepository = CalibrationRepositoryImpl(databaseService);
    final appLockRepository = AppLockRepositoryImpl(databaseService);

    // Create cubit
    _cubit = SettingsCubit(
      calibrationRepository: calibrationRepository,
      appLockRepository: appLockRepository,
      databaseService: databaseService,
    );

    // Initialize with user ID (hardcoded for demo, would come from auth)
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
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _cubit.refresh(1),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: BlocConsumer<SettingsCubit, SettingsState>(
          listener: (context, state) {
            if (state is SettingsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else if (state is SettingsDataCleared) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is SettingsInitial || state is SettingsLoading) {
              return _buildLoading(state);
            } else if (state is SettingsLoaded) {
              return _buildLoaded(context, state);
            } else if (state is SettingsClearing) {
              return _buildClearing(context, state);
            } else if (state is SettingsError) {
              return _buildError(context, state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLoading(SettingsState state) {
    final message = state is SettingsLoading ? state.message : 'Loading...';
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

  Widget _buildClearing(BuildContext context, SettingsClearing state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(state.message),
        ],
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, SettingsLoaded state) {
    return RefreshIndicator(
      onRefresh: () => _cubit.refresh(state.userId),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Gait Lock Section
          _buildSectionHeader(context, 'Gait Lock'),
          _buildGaitLockCard(context, state),

          const SizedBox(height: 24),

          // Calibration Section
          _buildSectionHeader(context, 'Calibration'),
          _buildCalibrationCard(context, state),

          const SizedBox(height: 24),

          // App Lock Section
          _buildSectionHeader(context, 'App Lock'),
          _buildAppLockCard(context, state),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          _buildAppearanceCard(context, state),

          const SizedBox(height: 24),

          // Account Section
          _buildSectionHeader(context, 'Account'),
          _buildAccountCard(context, state),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildGaitLockCard(BuildContext context, SettingsLoaded state) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: state.gaitLockEnabled,
            onChanged: (value) => _cubit.setGaitLockEnabled(value),
            title: const Text('Enable Gait Lock'),
            subtitle: const Text('Lock apps when gait authentication fails'),
            secondary: Icon(
              state.gaitLockEnabled ? Icons.lock : Icons.lock_open,
              color: state.gaitLockEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Unlock Threshold'),
            subtitle: Text(
              'Confidence required: ${state.thresholdPercentage}',
            ),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: state.unlockThreshold,
                min: 0.5,
                max: 0.95,
                divisions: 9,
                label: state.thresholdPercentage,
                onChanged: state.gaitLockEnabled
                    ? (value) => _cubit.setUnlockThreshold(value)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationCard(BuildContext context, SettingsLoaded state) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              state.hasCalibration
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              color: state.hasCalibration ? Colors.green : theme.colorScheme.error,
            ),
            title: Text(
              state.hasCalibration ? 'Calibration Complete' : 'Not Calibrated',
            ),
            subtitle: Text(
              state.hasCalibration
                  ? 'Quality: ${((state.latestCalibration?.qualityScore ?? 0) * 100).toStringAsFixed(0)}%'
                  : 'Complete calibration to enable gait lock',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Calibration Sessions'),
            subtitle: Text('${state.calibrationCount} session(s) recorded'),
            trailing: state.calibrationCount > 0
                ? TextButton(
                    onPressed: () => _showDeleteCalibrationDialog(context, state),
                    child: const Text('Manage'),
                  )
                : null,
          ),
          if (state.calibrationCount > 0) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Delete All Calibrations',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => _showDeleteAllCalibrationsDialog(context, state.userId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppLockCard(BuildContext context, SettingsLoaded state) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('Protected Apps'),
            subtitle: Text('${state.protectedAppsCount} app(s) protected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to app lock screen
              Navigator.of(context).pushNamed('/app-lock');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_clock),
            title: const Text('Lock Events'),
            subtitle: Text('${state.totalLockEvents} total lock session(s)'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context, SettingsLoaded state) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: state.isDarkMode,
            onChanged: (value) => _cubit.setDarkMode(value),
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark theme'),
            secondary: Icon(
              state.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, SettingsLoaded state) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('User Profile'),
            subtitle: Text('User ID: ${state.userId}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Clear All Data',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Delete all calibrations and app locks'),
            onTap: () => _showClearAllDataDialog(context, state.userId),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Sign Out',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _showSignOutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteCalibrationDialog(
      BuildContext context, SettingsLoaded state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Calibrations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You have ${state.calibrationCount} calibration session(s).',
            ),
            const SizedBox(height: 16),
            if (state.latestCalibration != null) ...[
              Text(
                'Latest: ${state.latestCalibration!.startTime.toString().split('.').first}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllCalibrationsDialog(BuildContext context, int userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Calibrations?'),
        content: const Text(
          'This will delete all your calibration data. You will need to recalibrate to use gait lock features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cubit.deleteAllCalibrations(userId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDataDialog(BuildContext context, int userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your data including calibrations, app lock preferences, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cubit.clearAllData(userId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'Are you sure you want to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement actual sign out logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sign out not implemented in demo'),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, SettingsError state) {
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
