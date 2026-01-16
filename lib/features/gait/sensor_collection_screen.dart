import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/gait_collection_cubit.dart';
import '../../core/services/sensor_service_impl.dart';
import '../../core/services/mock_sensor_service.dart';

/// Sensor collection UI for gait data recording.
class SensorCollectionScreen extends StatefulWidget {
  const SensorCollectionScreen({super.key});

  @override
  State<SensorCollectionScreen> createState() => _SensorCollectionScreenState();
}

class _SensorCollectionScreenState extends State<SensorCollectionScreen> {
  late GaitCollectionCubit _cubit;
  bool _useMockService = true;

  @override
  void initState() {
    super.initState();
    
    // For development, use mock service. In production, use real service
    final sensorService = _useMockService 
        ? MockSensorService(samplingRate: 50.0)
        : SensorServiceImpl(samplingRate: 50.0);
    
    _cubit = GaitCollectionCubit(sensorService);
    _cubit.initialize();
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
          title: const Text('Sensor Collection'),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _useMockService = !_useMockService;
                  final sensorService = _useMockService 
                      ? MockSensorService(samplingRate: 50.0)
                      : SensorServiceImpl(samplingRate: 50.0);
                  _cubit.close();
                  _cubit = GaitCollectionCubit(sensorService);
                  _cubit.initialize();
                });
              },
              icon: Icon(_useMockService ? Icons.science : Icons.sensors),
              tooltip: _useMockService ? 'Using Mock Service' : 'Using Real Sensors',
            ),
          ],
        ),
        body: BlocConsumer<GaitCollectionCubit, GaitCollectionState>(
          listener: (context, state) {
            if (state is GaitCollectionError) {
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
                  // Status Card
                  _buildStatusCard(state),
                  const SizedBox(height: 16),
                  
                  // Controls Card
                  if (state is GaitCollectionReady || state is GaitCollectionCollecting)
                    _buildControlsCard(state),
                  const SizedBox(height: 16),
                  
                  // Real-time Data Card
                  if (state is GaitCollectionCollecting)
                    _buildRealTimeDataCard(state),
                  const SizedBox(height: 16),
                  
                  // Results Card
                  if (state is GaitCollectionStopped)
                    _buildResultsCard(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(GaitCollectionState state) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (state.runtimeType) {
      case GaitCollectionInitial:
      case GaitCollectionLoading:
        statusColor = Colors.orange;
        statusText = 'Initializing...';
        statusIcon = Icons.hourglass_empty;
        break;
      case GaitCollectionReady:
        final readyState = state as GaitCollectionReady;
        statusColor = readyState.sensorAvailability.allSensorsAvailable 
            ? Colors.green 
            : Colors.red;
        statusText = readyState.sensorAvailability.allSensorsAvailable 
            ? 'Ready to Collect'
            : 'Sensors Not Available';
        statusIcon = readyState.sensorAvailability.allSensorsAvailable 
            ? Icons.check_circle 
            : Icons.error;
        break;
      case GaitCollectionCollecting:
        statusColor = Colors.blue;
        statusText = 'Collecting Data';
        statusIcon = Icons.sensors;
        break;
      case GaitCollectionStopped:
        statusColor = Colors.purple;
        statusText = 'Collection Complete';
        statusIcon = Icons.done_all;
        break;
      case GaitCollectionError:
        statusColor = Colors.red;
        statusText = 'Error';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              statusIcon,
              color: statusColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (state is GaitCollectionReady)
                    Text(
                      state.sensorAvailability.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (state is GaitCollectionCollecting)
                    Text(
                      'Sampling Rate: ${state.samplingRate.toStringAsFixed(1)} Hz',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_useMockService)
                    Text(
                      'Mock Service Active',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
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

  Widget _buildControlsCard(GaitCollectionState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Sampling Rate Control
            if (state is GaitCollectionReady)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sampling Rate: ${state.samplingRate.toStringAsFixed(0)} Hz',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Slider(
                    value: state.samplingRate,
                    min: 10.0,
                    max: 200.0,
                    divisions: 19,
                    label: '${state.samplingRate.toStringAsFixed(0)} Hz',
                    onChanged: (value) {
                      _cubit.setSamplingRate(value);
                    },
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Start/Stop Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state is GaitCollectionReady
                        ? () => _cubit.startCollection()
                        : state is GaitCollectionCollecting
                            ? () => _cubit.stopCollection()
                            : null,
                    icon: Icon(
                      state is GaitCollectionCollecting 
                          ? Icons.stop 
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      state is GaitCollectionCollecting 
                          ? 'Stop Collection' 
                          : 'Start Collection',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state is GaitCollectionCollecting
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (state is GaitCollectionCollecting) ...[
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => _cubit.stopCollection(),
                    icon: const Icon(Icons.stop, color: Colors.red),
                    tooltip: 'Stop Collection',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeDataCard(GaitCollectionCollecting state) {
    final stats = state.statistics;
    
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
            
            // Duration and Reading Count
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: _formatDuration(state.duration),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.dataset,
                    label: 'Readings',
                    value: '${state.readingCount}',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Sampling Rates
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.speed,
                    label: 'Target Rate',
                    value: '${state.samplingRate.toStringAsFixed(1)} Hz',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.trending_up,
                    label: 'Actual Rate',
                    value: '${(stats['actualRate'] as double).toStringAsFixed(1)} Hz',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Sensor Synchronization Status
            Row(
              children: [
                Icon(
                  stats['isSynchronized'] == true 
                      ? Icons.check_circle 
                      : Icons.warning,
                  color: stats['isSynchronized'] == true 
                      ? Colors.green 
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  stats['isSynchronized'] == true 
                      ? 'Sensors Synchronized'
                      : 'Sensor Sync Issues Detected',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: stats['isSynchronized'] == true 
                        ? Colors.green 
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(GaitCollectionStopped state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collection Results',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Summary Statistics
            _ResultRow(
              'Total Duration',
              _formatDuration(state.statistics['duration'] as Duration),
            ),
            _ResultRow(
              'Total Readings',
              '${state.statistics['readingCount']}',
            ),
            _ResultRow(
              'Average Sampling Rate',
              '${(state.statistics['actualRate'] as double).toStringAsFixed(1)} Hz',
            ),
            _ResultRow(
              'Data Synchronized',
              (state.statistics['isSynchronized'] as bool) ? 'Yes' : 'No',
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Export data functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Export functionality coming soon')),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cubit.clearData(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Collection'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else if (seconds > 0) {
      return '${seconds}.${(milliseconds ~/ 100)}s';
    } else {
      return '${milliseconds}ms';
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}