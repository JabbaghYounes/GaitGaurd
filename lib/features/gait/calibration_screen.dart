import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'logic/calibration_cubit.dart';
import '../../data/models/calibration_session.dart';
import '../../core/services/calibration_service.dart';
import '../../core/services/sensor_service_impl.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../core/services/database_service.dart';
import '../../data/datasources/local/calibration_local_data_source.dart';

/// Calibration UI for gait baseline collection.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late CalibrationCubit _cubit;
  bool _useMockService = true;

  @override
  void initState() {
    super.initState();
    
    // For development, use mock service
    final sensorService = _useMockService 
        ? MockSensorService(samplingRate: 50.0)
        : SensorServiceImpl(samplingRate: 50.0);
    
    // Create repository instance (in real app, this would be injected)
    final repository = CalibrationRepositoryImpl(DatabaseService.instance);
    final calibrationService = CalibrationService(sensorService, repository);
    
    _cubit = CalibrationCubit(calibrationService, sensorService);
    
    // Initialize with hardcoded user ID (in real app, get from auth)
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
          title: const Text('Gait Calibration'),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _useMockService = !_useMockService;
                  // Reinitialize with different service
                });
              },
              icon: Icon(_useMockService ? Icons.science : Icons.sensors),
              tooltip: _useMockService ? 'Using Mock Service' : 'Using Real Sensors',
            ),
          ],
        ),
        body: BlocConsumer<CalibrationCubit, CalibrationState>(
          listener: (context, state) {
            if (state is CalibrationError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context, state),
                  const SizedBox(height: 24),
                  
                  // Main content based on state
                  if (state is CalibrationReady) ...[
                    _buildCalibrationSelection(context, state),
                    const SizedBox(height: 24),
                    _buildRecentCalibrations(context, state),
                  ] else if (state is CalibrationInProgress) ...[
                    _buildInProgressUI(context, state),
                  ] else if (state is CalibrationCompleted) ...[
                    _buildCompletedUI(context, state),
                  ] else if (state is CalibrationError) ...[
                    _buildErrorUI(context, state),
                  ],
                  
                  // Loading state
                  if (state is CalibrationLoading)
                    _buildLoadingUI(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CalibrationState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.tune,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gait Calibration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Collect baseline gait patterns for accurate recognition',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  if (_useMockService)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Mock Service Active',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationSelection(BuildContext context, CalibrationReady state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Calibration Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Calibration type options
            ...state.availableTypes.map((type) => _buildCalibrationOption(context, type, state)),
            
            const SizedBox(height: 16),
            
            // Start button
            if (!state.canStartCalibration)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.3)),
                ),
                child: Text(
                  state.errorMessage ?? 'Calibration not available at this time',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationOption(BuildContext context, CalibrationType type, CalibrationReady state) {
    final isSelected = false; // Will be true when user selects

    return InkWell(
      onTap: state.canStartCalibration ? () => _startCalibration(type, state.userId) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCalibrationIcon(type),
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getCalibrationDescription(type),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(type.duration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const Spacer(),
                if (type.duration.inSeconds > 60)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Recommended',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCalibrations(BuildContext context, CalibrationReady state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Calibrations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            if (state.latestCalibration != null)
              _buildCalibrationCard(context, state.latestCalibration!)
            else
              Text(
                'No calibrations completed yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationCard(BuildContext context, CalibrationSession session) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: _getQualityColor(session.quality),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.type.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_formatDateTime(session.startTime)} • ${session.quality.displayName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(session.qualityScore * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _getQualityColor(session.quality),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressUI(BuildContext context, CalibrationInProgress state) {
    return Column(
      children: [
        _buildProgressCard(context, state),
        const SizedBox(height: 16),
        _buildLiveStatsCard(context, state),
        const SizedBox(height: 16),
        _buildControlsCard(context, state),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, CalibrationInProgress state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calibrating ${state.session.type.displayName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Progress bar
            LinearProgressIndicator(
              value: state.currentProgress,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            
            // Progress text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(state.currentProgress * 100).toStringAsFixed(1)}% Complete',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Time remaining: ${_formatDuration(state.estimatedTimeRemaining)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatsCard(BuildContext context, CalibrationInProgress state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.dataset,
                    label: 'Readings',
                    value: '${state.sensorReadings.length}',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.speed,
                    label: 'Sampling',
                    value: '${state.averageSamplingRate.toStringAsFixed(1)} Hz',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.analytics,
                    label: 'Quality',
                    value: '${(state.dataQuality * 100).toStringAsFixed(0)}%',
                    color: _getQualityColorFromScore(state.dataQuality),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard(BuildContext context, CalibrationInProgress state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cubit.cancelCalibration(),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedUI(BuildContext context, CalibrationCompleted state) {
    return Column(
      children: [
        _buildCompletionCard(context, state),
        const SizedBox(height: 16),
        _buildCompletionActions(context, state),
      ],
    );
  }

  Widget _buildCompletionCard(BuildContext context, CalibrationCompleted state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Calibration Complete!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              state.session.type.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Summary stats
            if (state.summary != null)
              ...state.summary!.entries.map((entry) => _buildSummaryRow(
                context, 
                entry.key, 
                entry.value.toString(),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionActions(BuildContext context, CalibrationCompleted state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _cubit.initialize(state.session.userId),
                icon: const Icon(Icons.add),
                label: const Text('New Calibration'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.done),
                label: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI(BuildContext context, CalibrationError state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Calibration Failed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              state.message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cubit.initialize(1), // Hardcoded user ID
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cubit.retryCalibration(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingUI(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing calibration...'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _startCalibration(CalibrationType type, int userId) {
    _cubit.startCalibration(type, userId);
  }

  // Helper methods
  IconData _getCalibrationIcon(CalibrationType type) {
    switch (type) {
      case CalibrationType.fast:
        return Icons.speed;
      case CalibrationType.standard:
        return Icons.timer;
      case CalibrationType.extended:
        return Icons.hourglass_full;
    }
  }

  String _getCalibrationDescription(CalibrationType type) {
    switch (type) {
      case CalibrationType.fast:
        return 'Quick calibration for basic gait detection';
      case CalibrationType.standard:
        return 'Recommended for most accurate results';
      case CalibrationType.extended:
        return 'Maximum accuracy for all walking patterns';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Color _getQualityColor(CalibrationQuality quality) {
    switch (quality) {
      case CalibrationQuality.poor:
        return Colors.red;
      case CalibrationQuality.fair:
        return Colors.orange;
      case CalibrationQuality.good:
        return Colors.lightGreen;
      case CalibrationQuality.excellent:
        return Colors.green;
    }
  }

  Color _getQualityColorFromScore(double score) {
    if (score >= 0.9) return Colors.green;
    if (score >= 0.7) return Colors.lightGreen;
    if (score >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}