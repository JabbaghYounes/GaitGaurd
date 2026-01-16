import '../../data/models/calibration_session.dart';
import 'sensor_service.dart';

/// Comprehensive error handling for calibration operations
class CalibrationErrorHandler {
  /// Analyze calibration error and provide user-friendly message
  static CalibrationErrorInfo analyzeError(dynamic error, CalibrationSession? session) {
    if (error is SensorException) {
      return _analyzeSensorError(error, session);
    }
    
    if (error is CalibrationException) {
      return _analyzeCalibrationException(error, session);
    }
    
    if (error is ArgumentError) {
      return CalibrationErrorInfo(
        errorType: CalibrationErrorType.validationError,
        userMessage: error.message ?? 'Invalid calibration parameters',
        technicalMessage: error.toString(),
        canRetry: true,
        suggestedAction: 'Check calibration settings and try again',
      );
    }
    
    return _analyzeGenericError(error, session);
  }

  /// Get recovery suggestions for error type
  static List<CalibrationRecoveryAction> getRecoveryActions(CalibrationErrorType errorType) {
    switch (errorType) {
      case CalibrationErrorType.sensorUnavailable:
        return [
          CalibrationRecoveryAction(
            title: 'Check Device Permissions',
            description: 'Ensure motion sensors are enabled in device settings',
            actionType: RecoveryActionType.checkPermissions,
          ),
          CalibrationRecoveryAction(
            title: 'Restart App',
            description: 'Close and restart the app to reinitialize sensors',
            actionType: RecoveryActionType.restartApp,
          ),
        ];
        
      case CalibrationErrorType.sensorError:
        return [
          CalibrationRecoveryAction(
            title: 'Wait and Retry',
            description: 'Sensors may be temporarily busy',
            actionType: RecoveryActionType.retry,
          ),
          CalibrationRecoveryAction(
            title: 'Check Device Motion',
            description: 'Ensure device is functioning normally',
            actionType: RecoveryActionType.checkDevice,
          ),
        ];
        
      case CalibrationErrorType.insufficientData:
        return [
          CalibrationRecoveryAction(
            title: 'Extend Duration',
            description: 'Try a longer calibration session',
            actionType: RecoveryActionType.extendDuration,
          ),
          CalibrationRecoveryAction(
            title: 'Improve Walking Pattern',
            description: 'Walk at a steady, natural pace',
            actionType: RecoveryActionType.improveTechnique,
          ),
        ];
        
      case CalibrationErrorType.dataQualityPoor:
        return [
          CalibrationRecoveryAction(
            title: 'Recalibrate',
            description: 'Try calibration again with better walking technique',
            actionType: RecoveryActionType.retry,
          ),
          CalibrationRecoveryAction(
            title: 'Change Environment',
            description: 'Move to a flat, stable surface',
            actionType: RecoveryActionType.changeEnvironment,
          ),
        ];
        
      case CalibrationErrorType.databaseError:
        return [
          CalibrationRecoveryAction(
            title: 'Clear Cache',
            description: 'Clear app data and try again',
            actionType: RecoveryActionType.clearCache,
          ),
          CalibrationRecoveryAction(
            title: 'Restart Device',
            description: 'Restart your device to fix database issues',
            actionType: RecoveryActionType.restartDevice,
          ),
        ];
        
      case CalibrationErrorType.userCancelled:
        return [
          CalibrationRecoveryAction(
            title: 'Resume Calibration',
            description: 'Continue from where you left off',
            actionType: RecoveryActionType.resume,
          ),
        ];
        
      case CalibrationErrorType.validationError:
        return [
          CalibrationRecoveryAction(
            title: 'Check Settings',
            description: 'Verify calibration parameters are valid',
            actionType: RecoveryActionType.checkSettings,
          ),
        ];
        
      default:
        return [
          CalibrationRecoveryAction(
            title: 'Try Again',
            description: 'Restart the calibration process',
            actionType: RecoveryActionType.retry,
          ),
        ];
    }
  }

  /// Check if error is recoverable
  static bool isRecoverable(dynamic error) {
    final errorInfo = analyzeError(error, null);
    return errorInfo.canRetry;
  }

  /// Get error severity level
  static CalibrationErrorSeverity getErrorSeverity(dynamic error) {
    if (error is SensorException) {
      return _getSensorErrorSeverity(error);
    }
    
    if (error is CalibrationException) {
      return _getCalibrationErrorSeverity(error);
    }
    
    return CalibrationErrorSeverity.medium;
  }

  static CalibrationErrorInfo _analyzeSensorError(
    SensorException error, 
    CalibrationSession? session,
  ) {
    if (error.message.contains('not available')) {
      return CalibrationErrorInfo(
        errorType: CalibrationErrorType.sensorUnavailable,
        userMessage: 'Device sensors are not available',
        technicalMessage: error.message,
        canRetry: false,
        suggestedAction: 'Check device compatibility and permissions',
      );
    }
    
    if (error.message.contains('permission')) {
      return CalibrationErrorInfo(
        errorType: CalibrationErrorType.permissionDenied,
        userMessage: 'Sensor permission is required',
        technicalMessage: error.message,
        canRetry: true,
        suggestedAction: 'Grant sensor permissions in device settings',
      );
    }
    
    return CalibrationErrorInfo(
      errorType: CalibrationErrorType.sensorError,
      userMessage: 'Sensor error occurred during calibration',
      technicalMessage: error.message,
      canRetry: true,
      suggestedAction: 'Try calibration again',
    );
  }

  static CalibrationErrorInfo _analyzeCalibrationException(
    CalibrationException error,
    CalibrationSession? session,
  ) {
    final message = error.message.toLowerCase();
    
    if (message.contains('not ready')) {
      return CalibrationErrorInfo(
        errorType: CalibrationErrorType.systemNotReady,
        userMessage: 'Calibration system is not ready',
        technicalMessage: error.message,
        canRetry: true,
        suggestedAction: 'Wait a moment and try again',
      );
    }
    
    if (message.contains('start')) {
      return CalibrationErrorInfo(
        errorType: CalibrationErrorType.startupError,
        userMessage: 'Failed to start calibration',
        technicalMessage: error.message,
        canRetry: true,
        suggestedAction: 'Check sensor availability and retry',
      );
    }
    
    if (message.contains('process')) {
      return CalibrationErrorInfo(
        errorType: CalibrationErrorType.processingError,
        userMessage: 'Error processing sensor data',
        technicalMessage: error.message,
        canRetry: true,
        suggestedAction: 'Try calibration with better walking technique',
      );
    }
    
    return CalibrationErrorInfo(
      errorType: CalibrationErrorType.unknownError,
      userMessage: 'Calibration error occurred',
      technicalMessage: error.message,
      canRetry: true,
      suggestedAction: 'Try calibration again',
    );
  }

  static CalibrationErrorInfo _analyzeGenericError(
    dynamic error,
    CalibrationSession? session,
  ) {
    return CalibrationErrorInfo(
      errorType: CalibrationErrorType.unknownError,
      userMessage: 'An unexpected error occurred',
      technicalMessage: error.toString(),
      canRetry: true,
      suggestedAction: 'Try calibration again or contact support',
    );
  }

  static CalibrationErrorSeverity _getSensorErrorSeverity(SensorException error) {
    final message = error.message.toLowerCase();
    
    if (message.contains('not available') || message.contains('permission')) {
      return CalibrationErrorSeverity.high;
    }
    
    if (message.contains('malfunction')) {
      return CalibrationErrorSeverity.critical;
    }
    
    return CalibrationErrorSeverity.medium;
  }

  static CalibrationErrorSeverity _getCalibrationErrorSeverity(
    CalibrationException error,
  ) {
    final message = error.message.toLowerCase();
    
    if (message.contains('critical')) {
      return CalibrationErrorSeverity.critical;
    }
    
    if (message.contains('failed') || message.contains('error')) {
      return CalibrationErrorSeverity.high;
    }
    
    return CalibrationErrorSeverity.medium;
  }
}

/// Types of calibration errors
enum CalibrationErrorType {
  sensorUnavailable,
  permissionDenied,
  sensorError,
  insufficientData,
  dataQualityPoor,
  databaseError,
  userCancelled,
  validationError,
  startupError,
  processingError,
  systemNotReady,
  unknownError,
}

/// Error severity levels
enum CalibrationErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Recovery action types
enum RecoveryActionType {
  retry,
  checkPermissions,
  restartApp,
  restartDevice,
  clearCache,
  checkDevice,
  extendDuration,
  improveTechnique,
  changeEnvironment,
  resume,
  checkSettings,
}

/// Calibration error information
class CalibrationErrorInfo {
  const CalibrationErrorInfo({
    required this.errorType,
    required this.userMessage,
    required this.technicalMessage,
    required this.canRetry,
    required this.suggestedAction,
  });

  final CalibrationErrorType errorType;
  final String userMessage;
  final String technicalMessage;
  final bool canRetry;
  final String suggestedAction;
}

/// Recovery action for calibration errors
class CalibrationRecoveryAction {
  const CalibrationRecoveryAction({
    required this.title,
    required this.description,
    required this.actionType,
  });

  final String title;
  final String description;
  final RecoveryActionType actionType;
}