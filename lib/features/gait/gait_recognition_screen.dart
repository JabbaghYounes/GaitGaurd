import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/gait_recognition_cubit.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/gait_features.dart';
import '../../core/services/sensor_service_impl.dart';
import '../../core/services/mock_sensor_service.dart';

/// Gait Recognition UI for biometric authentication.
class GaitRecognitionScreen extends StatefulWidget {
  const GaitRecognitionScreen({super.key});

  @override
  State<GaitRecognitionScreen> createState() => _GaitRecognitionScreenState();
}

class _GaitRecognitionScreenState extends State<GaitRecognitionScreen> {
  late GaitRecognitionCubit _cubit;
  bool _useMockService = true;
  bool _isRealTimeMode = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize with mock service for development
    final sensorService = _useMockService 
        ? MockSensorService(samplingRate: 50.0)
        : SensorServiceImpl(samplingRate: 50.0);
    
    _cubit = GaitRecognitionCubit(
      sensorService,
      null, // Repository will be injected
      null, // ML Pipeline service will be injected
    );
    
    _cubit.initialize(1); // Hardcoded user ID
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
          title: const Text('Gait Recognition'),
          actions: [
            IconButton(
              onPressed: _toggleMockService,
              icon: Icon(_useMockService ? Icons.science : Icons.sensors),
              tooltip: _useMockService ? 'Using Mock Service' : 'Using Real Sensors',
            ),
            IconButton(
              onPressed: _toggleRealtimeMode,
              icon: Icon(_isRealTimeMode ? Icons.timer : Icons.camera),
              tooltip: _isRealTimeMode ? 'Real-time Mode' : 'Batch Mode',
            ),
          ],
        ),
        body: BlocConsumer<GaitRecognitionCubit, GaitRecognitionState>(
          listener: (context, state) {
            if (state is GaitRecognitionError) {
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
                  // Header with status
                  _buildStatusCard(context, state),
                  const SizedBox(height: 16),
                  
                  // Main content based on state
                  if (state is GaitRecognitionReady) ...[
                    _buildReadyUI(context, state),
                  ] else if (state is GaitRecognitionInProgress) ...[
                    _buildInProgressUI(context, state),
                  ] else if (state is GaitRecognitionComplete) ...[
                    _buildCompleteUI(context, state),
                  ] else if (state is GaitRecognitionError) ...[
                    _buildErrorUI(context, state),
                  ] else if (state is GaitRecognitionLoading) ...[
                    _buildLoadingUI(context),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, GaitRecognitionState state) {
    IconData statusIcon;
    Color statusColor;
    String statusText;
    String? subtitle;

    switch (state.runtimeType) {
      case GaitRecognitionReady:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Recognition Ready';
        subtitle = 'Model trained and ready for authentication';
        break;
      case GaitRecognitionInProgress:
        final inProgressState = state as GaitRecognitionInProgress;
        statusIcon = Icons.sensors;
        statusColor = Colors.blue;
        statusText = inProgressState.isRealTime ? 'Real-time Recognition' : 'Processing Recognition';
        subtitle = inProgressState.isRealTime 
            ? 'Analyzing gait patterns in real-time'
            : 'Processing sensor data';
        break;
      case GaitRecognitionComplete:
        statusIcon = Icons.verified;
        statusColor = Colors.purple;
        statusText = 'Recognition Complete';
        subtitle = 'Gait pattern successfully identified';
        break;
      case GaitRecognitionError:
        statusIcon = Icons.error;
        statusColor = Colors.red;
        statusText = 'Recognition Error';
        subtitle = 'An error occurred during recognition';
        break;
      default:
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.grey;
        statusText = 'Initializing';
        subtitle = 'Setting up recognition system';
        break;
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
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

  Widget _buildReadyUI(BuildContext context, GaitRecognitionReady state) {
    return Column(
      children: [
        _buildModelInfoCard(context, state),
        const SizedBox(height: 16),
        _buildRecognitionOptions(context, state),
        const SizedBox(height: 16),
        _buildRecognitionHistoryCard(context, state),
      ],
    );
  }

  Widget _buildModelInfoCard(BuildContext context, GaitRecognitionReady state) {
    final model = state.activeModel;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Active Model',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (model != null) ...[
              _buildInfoRow('Type', model['type'] as String ?? 'Unknown'),
              _buildInfoRow('Version', model['version'] as String ?? '1.0.0'),
              _buildInfoRow('Accuracy', '${((model['accuracy'] as double? ?? 0.0) * 100).toStringAsFixed(1)}%'),
              _buildInfoRow('Performance', model['performance'] as String ?? 'N/A'),
              if (model['createdAt'] != null)
                _buildInfoRow('Created', _formatDate(model['createdAt'] as String)),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.error,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No Model Available',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCalibrationPrompt(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('Calibrate Gait'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildRecognitionOptions(BuildContext context, GaitRecognitionReady state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recognition Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Start recognition button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startRealtimeRecognition(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Real-time Recognition'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Test with readings option
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showBatchRecognitionDialog(context),
                icon: const Icon(Icons.upload),
                label: const Text('Test with Sensor Readings'),
              ),
            ),
            const SizedBox(height: 12),
            
            // Model management
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showModelManagementDialog(context),
                icon: const Icon(Icons.settings),
                label: const Text('Manage Models'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInProgressUI(BuildContext context, GaitRecognitionInProgress state) {
    return Column(
      children: [
        _buildRealtimeStatsCard(context, state),
        const SizedBox(height: 16),
        _buildFeatureVisualization(context, state),
        const SizedBox(height: 16),
        _buildControlsCard(context, state),
      ],
    );
  }

  Widget _buildRealtimeStatsCard(BuildContext context, GaitRecognitionInProgress state) {
    final stats = state.statistics;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Real-time Analysis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.sensors,
                    label: 'Window Size',
                    value: '${stats['windowSize']} samples',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatCard(
                    icon: Icons.trending_up,
                    label: 'Pattern',
                    value: stats['patternType'] ?? 'Unknown',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatCard(
                    icon: Icons.psychology,
                    label: 'Confidence',
                    value: stats['currentConfidence'] != null
                        ? '${((stats['currentConfidence'] as double) * 100).toStringAsFixed(1)}%'
                        : 'N/A',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Real-time indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                color: state.isRealTime 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      state.isRealTime ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: state.isRealTime ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.isRealTime ? 'Analyzing Gait' : 'Processing Data',
                      style: TextStyle(
                        color: state.isRealTime ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureVisualization(BuildContext context, GaitRecognitionInProgress state) {
    if (state.features == null) {
      return const SizedBox.shrink();
    }

    final features = state.features!;
    final featureVector = features.toVector();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feature Analysis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Feature bars
            ...featureVector.asMap().entries.map((entry) {
              final index = entry.key;
              final value = entry.value;
              final featureNames = [
                'Step Frequency',
                'Step Regularity',
                'Acceleration Variance',
                'Gyroscope Variance',
                'Step Intensity',
                'Walking Pattern',
              ];
              
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(featureNames[index]),
                      Text(value.toStringAsFixed(3)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getFeatureColor(value),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard(BuildContext context, GaitRecognitionInProgress state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Recognition Controls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cubit.stopRealtimeRecognition(),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Recognition'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSaveResultsDialog(context, state),
                    icon: const Icon(Icons.save),
                    label: const Text('Save Results'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteUI(BuildContext context, GaitRecognitionComplete state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.verified,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            
            Text(
              state.result.isMatch ? 'Authentication Successful' : 'Authentication Failed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: state.result.isMatch ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            Text(
              'Confidence: ${((state.result.confidence) * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            Text(
              'Pattern: ${state.result.patternType.displayName}',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cubit.initialize(1),
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Recognition'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI(BuildContext context, GaitRecognitionError state) {
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
              'Recognition Failed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
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
                    onPressed: () => _cubit.initialize(1),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cubit.initialize(1),
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
          Text('Initializing recognition system...'),
        ],
      ),
    );
  }

  Widget _buildRecognitionHistoryCard(BuildContext context, GaitRecognitionReady state) {
    final history = state.recognitionHistory;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recognition History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            if (history.isEmpty) ...[
              Text(
                'No recognition history available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ] else ...[
              ...history.take(5).map((entry) => _buildHistoryEntry(context, entry)),
              if (history.length > 5)
                TextButton(
                  onPressed: () => _showFullHistory(context),
                  child: const Text('View All History'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(BuildContext context, Map<String, dynamic> entry) {
    final isMatch = (entry['isMatch'] as int) == 1;
    final confidence = entry['confidence'] as double;
    final timestamp = DateTime.parse(entry['recognitionTimestamp'] as String);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isMatch ? Colors.green : Colors.grey,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle : Icons.cancel,
            color: isMatch ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMatch ? 'Match' : 'No Match',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isMatch ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _formatTime(timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Action handlers

  void _toggleMockService() {
    setState(() {
      _useMockService = !_useMockService;
    });
    
    // Reinitialize with new service
    _cubit.close();
    // Implementation would be similar to initState
  }

  void _toggleRealtimeMode() {
    setState(() {
      _isRealTimeMode = !_isRealTimeMode;
    });
  }

  void _startRealtimeRecognition() {
    _cubit.startRealtimeRecognition();
  }

  void _showCalibrationPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Required'),
        content: const Text(
          'You need to calibrate your gait pattern before recognition. '
          'Would you like to go to the calibration screen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to calibration screen
            },
            child: const Text('Calibrate'),
          ),
        ],
      ),
    );
  }

  void _showBatchRecognitionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch Recognition'),
        content: const Text(
          'Upload sensor data or use a recent calibration for batch recognition.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Would show file picker or calibration selector
            },
            child: const Text('Upload Data'),
          ),
        ],
      ),
    );
  }

  void _showModelManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Management'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose recognition model type:'),
            const SizedBox(height: 16),
            RadioListTile(
              title: const Text('Heuristic'),
              subtitle: const Text('Fast, lightweight analysis'),
              value: 'heuristic',
              groupValue: 'heuristic',
              onChanged: (value) {
                // Would switch recognizer type
                Navigator.of(context).pop();
              },
            ),
            RadioListTile(
              title: const Text('Machine Learning'),
              subtitle: const Text('Advanced AI-based recognition'),
              value: 'ml',
              groupValue: 'heuristic',
              onChanged: (value) {
                // Would switch recognizer type
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSaveResultsDialog(BuildContext context, GaitRecognitionInProgress state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Results'),
        content: const Text(
          'Save current recognition results for analysis or backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Would save results to file or cloud
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFullHistory(BuildContext context) {
    // Would show full history in separate screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full history view coming soon')),
    );
  }

  // Helper methods

  Color _getFeatureColor(double value) {
    if (value >= 0.8) return Colors.green;
    if (value >= 0.6) return Colors.lightGreen;
    if (value >= 0.4) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(String isoString) {
    final date = DateTime.parse(isoString);
    final now = DateTime.now();
    final difference = now.difference(date);

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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
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
      ),
    );
  }
}