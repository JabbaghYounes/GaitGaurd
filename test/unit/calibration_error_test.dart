import 'package:flutter_test/flutter_test.dart';
import '../../../lib/data/models/calibration_session.dart';
import '../../../lib/core/services/calibration_error_handler.dart';

void main() {
  group('CalibrationErrorHandler Tests', () {
    test('should analyze sensor errors correctly', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.fast,
      );

      final errorInfo = CalibrationErrorHandler.analyzeError(
        const SensorException('Accelerometer not available'),
        session,
      );

      expect(errorInfo.errorType, equals(CalibrationErrorType.sensorUnavailable));
      expect(errorInfo.userMessage, contains('not available'));
      expect(errorInfo.canRetry, isFalse);
    });

    test('should analyze permission errors correctly', () {
      final errorInfo = CalibrationErrorHandler.analyzeError(
        const SensorException('Permission denied for sensors'),
        null,
      );

      expect(errorInfo.errorType, equals(CalibrationErrorType.permissionDenied));
      expect(errorInfo.userMessage, contains('permission'));
      expect(errorInfo.canRetry, isTrue);
    });

    test('should analyze calibration exceptions correctly', () {
      final session = CalibrationSession.create(
        userId: 1,
        type: CalibrationType.standard,
      );

      final errorInfo = CalibrationErrorHandler.analyzeError(
        const CalibrationException('Failed to start calibration'),
        session,
      );

      expect(errorInfo.errorType, equals(CalibrationErrorType.startupError));
      expect(errorInfo.userMessage, contains('start'));
      expect(errorInfo.canRetry, isTrue);
    });

    test('should analyze generic errors correctly', () {
      final errorInfo = CalibrationErrorHandler.analyzeError(
        'Unknown error occurred',
        null,
      );

      expect(errorInfo.errorType, equals(CalibrationErrorType.unknownError));
      expect(errorInfo.userMessage, contains('unexpected'));
      expect(errorInfo.canRetry, isTrue);
    });

    test('should provide recovery actions for sensor errors', () {
      final actions = CalibrationErrorHandler.getRecoveryActions(
        CalibrationErrorType.sensorUnavailable,
      );

      expect(actions.length, equals(2));
      expect(actions[0].actionType, equals(RecoveryActionType.checkPermissions));
      expect(actions[1].actionType, equals(RecoveryActionType.restartApp));
    });

    test('should provide recovery actions for data quality errors', () {
      final actions = CalibrationErrorHandler.getRecoveryActions(
        CalibrationErrorType.dataQualityPoor,
      );

      expect(actions.length, equals(2));
      expect(actions[0].actionType, equals(RecoveryActionType.recalibrate));
      expect(actions[1].actionType, equals(RecoveryActionType.changeEnvironment));
    });

    test('should determine recoverable errors correctly', () {
      expect(
        CalibrationErrorHandler.isRecoverable(
          const SensorException('Temporary sensor error'),
        ),
        isTrue,
      );

      expect(
        CalibrationErrorHandler.isRecoverable(
          const SensorException('Sensors not available'),
        ),
        isFalse,
      );
    });

    test('should determine error severity correctly', () {
      final criticalSeverity = CalibrationErrorHandler.getErrorSeverity(
        const SensorException('Sensor malfunction detected'),
      );

      final highSeverity = CalibrationErrorHandler.getErrorSeverity(
        const SensorException('Permission denied'),
      );

      final mediumSeverity = CalibrationErrorHandler.getErrorSeverity(
        const SensorException('Temporary sensor issue'),
      );

      expect(criticalSeverity, equals(CalibrationErrorSeverity.critical));
      expect(highSeverity, equals(CalibrationErrorSeverity.high));
      expect(mediumSeverity, equals(CalibrationErrorSeverity.medium));
    });
  });

  group('CalibrationErrorInfo Tests', () {
    test('should create error info correctly', () {
      const errorInfo = CalibrationErrorInfo(
        errorType: CalibrationErrorType.sensorUnavailable,
        userMessage: 'Sensors not available',
        technicalMessage: 'Hardware sensors not found',
        canRetry: false,
        suggestedAction: 'Check device compatibility',
      );

      expect(errorInfo.errorType, equals(CalibrationErrorType.sensorUnavailable));
      expect(errorInfo.userMessage, equals('Sensors not available'));
      expect(errorInfo.technicalMessage, equals('Hardware sensors not found'));
      expect(errorInfo.canRetry, isFalse);
      expect(errorInfo.suggestedAction, equals('Check device compatibility'));
    });
  });

  group('CalibrationRecoveryAction Tests', () {
    test('should create recovery action correctly', () {
      const action = CalibrationRecoveryAction(
        title: 'Test Action',
        description: 'Test description',
        actionType: RecoveryActionType.retry,
      );

      expect(action.title, equals('Test Action'));
      expect(action.description, equals('Test description'));
      expect(action.actionType, equals(RecoveryActionType.retry));
    });
  });

  group('Calibration Error Types Tests', () {
    test('should have all required error types', () {
      final types = CalibrationErrorType.values;
      
      expect(types, contains(CalibrationErrorType.sensorUnavailable));
      expect(types, contains(CalibrationErrorType.permissionDenied));
      expect(types, contains(CalibrationErrorType.insufficientData));
      expect(types, contains(CalibrationErrorType.dataQualityPoor));
      expect(types, contains(CalibrationErrorType.databaseError));
      expect(types, contains(CalibrationErrorType.userCancelled));
      expect(types, contains(CalibrationErrorType.validationError));
      expect(types, contains(CalibrationErrorType.unknownError));
    });
  });

  group('Calibration Severity Tests', () {
    test('should have all severity levels', () {
      final severities = CalibrationErrorSeverity.values;
      
      expect(severities, contains(CalibrationErrorSeverity.low));
      expect(severities, contains(CalibrationErrorSeverity.medium));
      expect(severities, contains(CalibrationErrorSeverity.high));
      expect(severities, contains(CalibrationErrorSeverity.critical));
    });
  });

  group('Recovery Action Types Tests', () {
    test('should have all recovery action types', () {
      final actionTypes = RecoveryActionType.values;
      
      expect(actionTypes, contains(RecoveryActionType.retry));
      expect(actionTypes, contains(RecoveryActionType.checkPermissions));
      expect(actionTypes, contains(RecoveryActionType.restartApp));
      expect(actionTypes, contains(RecoveryActionType.restartDevice));
      expect(actionTypes, contains(RecoveryActionType.clearCache));
      expect(actionTypes, contains(RecoveryActionType.checkDevice));
      expect(actionTypes, contains(RecoveryActionType.extendDuration));
      expect(actionTypes, contains(RecoveryActionType.improveTechnique));
      expect(actionTypes, contains(RecoveryActionType.changeEnvironment));
    });
  });

  group('Error Recovery Integration Tests', () {
    test('should handle multiple error types with appropriate recovery', () {
      final testCases = [
        {
          'error': const SensorException('Accelerometer not available'),
          'expectedType': CalibrationErrorType.sensorUnavailable,
          'expectedCanRetry': false,
        },
        {
          'error': const CalibrationException('Insufficient data collected'),
          'expectedType': CalibrationErrorType.insufficientData,
          'expectedCanRetry': true,
        },
        {
          'error': const CalibrationException('Database connection failed'),
          'expectedType': CalibrationErrorType.databaseError,
          'expectedCanRetry': true,
        },
      ];

      for (final testCase in testCases) {
        final errorInfo = CalibrationErrorHandler.analyzeError(
          testCase['error'] as dynamic,
          null,
        );

        expect(errorInfo.errorType, equals(testCase['expectedType']),
            reason: 'Error type mismatch for ${testCase['error']}');
        expect(errorInfo.canRetry, equals(testCase['expectedCanRetry']),
            reason: 'Retry flag mismatch for ${testCase['error']}');

        final recoveryActions = CalibrationErrorHandler.getRecoveryActions(
          errorInfo.errorType,
        );
        expect(recoveryActions, isNotEmpty,
            reason: 'No recovery actions for ${testCase['error']}');
      }
    });

    test('should provide appropriate recovery actions for different scenarios', () {
      final scenarios = {
        CalibrationErrorType.sensorUnavailable: [
          RecoveryActionType.checkPermissions,
          RecoveryActionType.restartApp,
        ],
        CalibrationErrorType.insufficientData: [
          RecoveryActionType.extendDuration,
          RecoveryActionType.improveTechnique,
        ],
        CalibrationErrorType.dataQualityPoor: [
          RecoveryActionType.recalibrate,
          RecoveryActionType.changeEnvironment,
        ],
        CalibrationErrorType.databaseError: [
          RecoveryActionType.clearCache,
          RecoveryActionType.restartDevice,
        ],
      };

      for (final entry in scenarios.entries) {
        final errorType = entry.key;
        final expectedActions = entry.value;
        final actualActions = CalibrationErrorHandler.getRecoveryActions(errorType)
            .map((action) => action.actionType)
            .toList();

        expect(actualActions.length, equals(expectedActions.length),
            reason: 'Action count mismatch for $errorType');

        for (final expectedAction in expectedActions) {
          expect(actualActions, contains(expectedAction),
              reason: 'Missing action $expectedAction for $errorType');
        }
      }
    });
  });
}