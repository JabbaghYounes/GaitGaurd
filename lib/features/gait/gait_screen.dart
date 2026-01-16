import 'package:flutter/material.dart';
import 'sensor_collection_screen.dart';
import 'calibration_screen.dart';
import 'gait_recognition_screen.dart';

/// Entry point screen for gait-related flows (calibration, recognition, sensors).
///
/// For the MVP scaffold this only provides navigation hints; actual flows
/// will live under `gait/calibration`, `gait/recognition`, and `gait/sensors`.
class GaitScreen extends StatelessWidget {
  const GaitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gait'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gait engine',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Calibrate, capture, and recognize gait patterns.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Calibration'),
              subtitle: const Text('Set up baseline gait samples.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CalibrationScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text('Recognition'),
              subtitle: const Text('Test recognition against your baseline.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GaitRecognitionScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sensors),
              title: const Text('Sensors'),
              subtitle: const Text('Inspect raw sensor streams.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SensorCollectionScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


