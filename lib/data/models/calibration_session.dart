import 'package:meta/meta.dart';
import 'sensor_reading.dart';

/// Types of calibration sessions available.
enum CalibrationType {
  /// Quick calibration session (~30 seconds)
  fast('Fast', Duration(seconds: 30)),
  
  /// Standard calibration session (~2 minutes)
  standard('Standard', Duration(minutes: 2)),
  
  /// Extended calibration session (~5 minutes)
  extended('Extended', Duration(minutes: 5));

  const CalibrationType(this.displayName, this.duration);
  
  final String displayName;
  final Duration duration;
}

/// Status of a calibration session.
enum CalibrationStatus {
  pending('Pending'),
  inProgress('In Progress'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled');

  const CalibrationStatus(this.displayName);
  
  final String displayName;
}

/// Quality rating for calibration data.
enum CalibrationQuality {
  poor('Poor', 0.0),
  fair('Fair', 0.5),
  good('Good', 0.7),
  excellent('Excellent', 0.9);

  const CalibrationQuality(this.displayName, this.threshold);
  
  final String displayName;
  final double threshold;
}

/// Calibration session model for gait baseline collection.
@immutable
class CalibrationSession {
  const CalibrationSession({
    this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.startTime,
    this.endTime,
    this.expectedDuration,
    this.collectedReadings = const [],
    this.readingCount = 0,
    this.qualityScore = 0.0,
    this.errorMessage,
    this.metadata,
  });

  /// Unique identifier for the session
  final int? id;
  
  /// User ID who owns this calibration
  final int userId;
  
  /// Type of calibration (fast, standard, extended)
  final CalibrationType type;
  
  /// Current status of the calibration
  final CalibrationStatus status;
  
  /// When the calibration started
  final DateTime startTime;
  
  /// When the calibration ended (null if in progress)
  final DateTime? endTime;
  
  /// Expected duration for this calibration type
  final Duration? expectedDuration;
  
  /// All collected sensor readings
  final List<SensorReading> collectedReadings;
  
  /// Total number of readings collected
  final int readingCount;
  
  /// Quality score (0.0 to 1.0) based on data quality
  final double qualityScore;
  
  /// Error message if calibration failed
  final String? errorMessage;
  
  /// Additional metadata for the session
  final Map<String, dynamic>? metadata;

  /// Get current duration of the session
  Duration get currentDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Get progress percentage (0.0 to 1.0)
  double get progress {
    if (expectedDuration == null) return 0.0;
    final current = currentDuration.inMilliseconds;
    final expected = expectedDuration!.inMilliseconds;
    return (current / expected).clamp(0.0, 1.0);
  }

  /// Check if the session is currently active
  bool get isActive => status == CalibrationStatus.inProgress;

  /// Check if the session is completed (successfully or not)
  bool get isCompleted => status == CalibrationStatus.completed || 
                          status == CalibrationStatus.failed || 
                          status == CalibrationStatus.cancelled;

  /// Get quality rating based on quality score
  CalibrationQuality get quality {
    if (qualityScore >= CalibrationQuality.excellent.threshold) {
      return CalibrationQuality.excellent;
    } else if (qualityScore >= CalibrationQuality.good.threshold) {
      return CalibrationQuality.good;
    } else if (qualityScore >= CalibrationQuality.fair.threshold) {
      return CalibrationQuality.fair;
    } else {
      return CalibrationQuality.poor;
    }
  }

  /// Get estimated time remaining
  Duration? get estimatedTimeRemaining {
    if (expectedDuration == null || isCompleted) return null;
    final elapsed = currentDuration;
    final remaining = expectedDuration! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get average sampling rate during calibration
  double get averageSamplingRate {
    if (collectedReadings.isEmpty) return 0.0;
    final duration = currentDuration.inSeconds;
    if (duration == 0) return 0.0;
    return collectedReadings.length / duration;
  }

  /// Create a copy with updated values
  CalibrationSession copyWith({
    int? id,
    int? userId,
    CalibrationType? type,
    CalibrationStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    Duration? expectedDuration,
    List<SensorReading>? collectedReadings,
    int? readingCount,
    double? qualityScore,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return CalibrationSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      expectedDuration: expectedDuration ?? this.expectedDuration,
      collectedReadings: collectedReadings ?? this.collectedReadings,
      readingCount: readingCount ?? this.readingCount,
      qualityScore: qualityScore ?? this.qualityScore,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create a new session ready to start
  factory CalibrationSession.create({
    required int userId,
    required CalibrationType type,
  }) {
    return CalibrationSession(
      userId: userId,
      type: type,
      status: CalibrationStatus.pending,
      startTime: DateTime.now(),
      expectedDuration: type.duration,
    );
  }

  /// Start the calibration session
  CalibrationSession startCalibration() {
    return copyWith(status: CalibrationStatus.inProgress);
  }

  /// Add sensor reading to the session
  CalibrationSession addReading(SensorReading reading) {
    final newReadings = [...collectedReadings, reading];
    return copyWith(
      collectedReadings: newReadings,
      readingCount: newReadings.length,
    );
  }

  /// Complete the calibration successfully
  CalibrationSession complete({double? qualityScore}) {
    return copyWith(
      status: CalibrationStatus.completed,
      endTime: DateTime.now(),
      qualityScore: qualityScore ?? this.qualityScore,
    );
  }

  /// Mark calibration as failed
  CalibrationSession fail(String errorMessage) {
    return copyWith(
      status: CalibrationStatus.failed,
      endTime: DateTime.now(),
      errorMessage: errorMessage,
    );
  }

  /// Cancel the calibration
  CalibrationSession cancel() {
    return copyWith(
      status: CalibrationStatus.cancelled,
      endTime: DateTime.now(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'status': status.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'expectedDuration': expectedDuration?.inMilliseconds,
      'readingCount': readingCount,
      'qualityScore': qualityScore,
      'quality': quality.name,
      'errorMessage': errorMessage,
      'metadata': metadata,
      'currentDuration': currentDuration.inMilliseconds,
      'progress': progress,
      'averageSamplingRate': averageSamplingRate,
      'estimatedTimeRemaining': estimatedTimeRemaining?.inMilliseconds,
    };
  }

  /// Create from JSON
  factory CalibrationSession.fromJson(Map<String, dynamic> json) {
    return CalibrationSession(
      id: json['id'] as int?,
      userId: json['userId'] as int,
      type: CalibrationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CalibrationType.standard,
      ),
      status: CalibrationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CalibrationStatus.pending,
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String)
          : null,
      expectedDuration: json['expectedDuration'] != null
          ? Duration(milliseconds: json['expectedDuration'] as int)
          : null,
      readingCount: json['readingCount'] as int? ?? 0,
      qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.0,
      errorMessage: json['errorMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to database map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.name,
      'status': status.name,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'expected_duration_ms': expectedDuration?.inMilliseconds,
      'reading_count': readingCount,
      'quality_score': qualityScore,
      'error_message': errorMessage,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  /// Create from database map
  factory CalibrationSession.fromMap(Map<String, Object?> map) {
    return CalibrationSession(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      type: CalibrationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CalibrationType.standard,
      ),
      status: CalibrationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CalibrationStatus.pending,
      ),
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      expectedDuration: map['expected_duration_ms'] != null
          ? Duration(milliseconds: map['expected_duration_ms'] as int)
          : null,
      readingCount: map['reading_count'] as int? ?? 0,
      qualityScore: (map['quality_score'] as num?)?.toDouble() ?? 0.0,
      errorMessage: map['error_message'] as String?,
      metadata: map['metadata'] != null
          ? _decodeMetadata(map['metadata'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalibrationSession &&
        other.id == id &&
        other.userId == userId &&
        other.type == type &&
        other.status == status &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.readingCount == readingCount &&
        other.qualityScore == qualityScore;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      type,
      status,
      startTime,
      endTime,
      readingCount,
      qualityScore,
    );
  }

  @override
  String toString() {
    return 'CalibrationSession('
        'id: $id, '
        'type: $type, '
        'status: $status, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'quality: ${quality.displayName})';
  }

  // Helper methods for metadata encoding/decoding
  static String _encodeMetadata(Map<String, dynamic> metadata) {
    // Simple JSON encoding - in production, use dart:convert
    return metadata.toString();
  }

  static Map<String, dynamic> _decodeMetadata(String encoded) {
    // Simple JSON decoding - in production, use dart:convert
    // For now, return empty map as placeholder
    return {};
  }
}