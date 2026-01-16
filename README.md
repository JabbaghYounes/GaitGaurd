# GaitGuard

A Flutter-based biometric security application that uses gait recognition to authenticate users and protect sensitive apps. GaitGuard leverages accelerometer and gyroscope sensor data to create a unique walking pattern profile, enabling hands-free authentication.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Local-Only Security Model](#local-only-security-model)
- [Gait ML Pipeline](#gait-ml-pipeline)
- [SQLite Schema](#sqlite-schema)
- [Running the App](#running-the-app)
- [Running Tests](#running-tests)
- [MVP Limitations](#mvp-limitations)
- [Future Improvements](#future-improvements)

---

## Project Overview

GaitGuard is a privacy-focused mobile security application that authenticates users based on their unique walking patterns. Unlike traditional biometrics (fingerprint, face), gait recognition works passively and continuously while the user walks.

### Key Features

| Feature | Description |
|---------|-------------|
| **Gait Calibration** | Three modes: Fast (30s), Standard (2min), Extended (5min) |
| **Real-time Recognition** | Continuous gait pattern matching with confidence scoring |
| **App Locking** | Protect sensitive apps with gait-based authentication |
| **Local Storage** | All data stored on-device; no cloud dependency |
| **Material 3 UI** | Modern, responsive design following Material Design 3 |

### How It Works

1. **Calibration**: User walks naturally while the app collects sensor data
2. **Feature Extraction**: Raw sensor data is processed into gait features (step frequency, regularity, intensity, etc.)
3. **Baseline Creation**: Features are stored as the user's unique gait signature
4. **Recognition**: Subsequent gait data is compared against the baseline for authentication
5. **App Protection**: Protected apps lock/unlock based on gait authentication results

---

## Architecture

GaitGuard follows a clean, layered architecture with BLoC (Business Logic Component) pattern for state management.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│         Screens • Widgets • BLoC/Cubit State Management     │
├─────────────────────────────────────────────────────────────┤
│                   BUSINESS LOGIC LAYER                       │
│    CalibrationService • MLPipelineService • AppLockService  │
│    GaitFeatureExtractor • GaitRecognizer • AuthService      │
├─────────────────────────────────────────────────────────────┤
│                       DATA LAYER                             │
│         Repositories • Data Sources • Models                 │
├─────────────────────────────────────────────────────────────┤
│                     DATABASE LAYER                           │
│              SQLite (DatabaseService Singleton)              │
└─────────────────────────────────────────────────────────────┘
```

### State Management (BLoC/Cubit)

The app uses Flutter BLoC with the Cubit pattern for simplified state management:

| Cubit | Responsibility |
|-------|----------------|
| `AuthCubit` | User registration, login, session management |
| `CalibrationCubit` | Gait calibration sessions, progress tracking |
| `GaitRecognitionCubit` | Real-time recognition, model management |
| `AppLockCubit` | App protection, lock/unlock operations |
| `HomeCubit` | Dashboard state, initialization |

### Design Patterns

- **Repository Pattern**: Abstracts data access (e.g., `AuthRepository`, `CalibrationRepository`)
- **Service Pattern**: Encapsulates business logic (e.g., `CalibrationService`, `MLPipelineService`)
- **Singleton Pattern**: Database connection management (`DatabaseService`)
- **Stream Pattern**: Real-time sensor data and event handling

---

## Folder Structure

```
GaitGaurd/
├── lib/
│   ├── core/                           # Core utilities and services
│   │   ├── services/                   # Business logic services
│   │   │   ├── database_service.dart       # SQLite singleton
│   │   │   ├── sensor_service.dart         # Sensor abstraction
│   │   │   ├── sensor_service_impl.dart    # Real sensor implementation
│   │   │   ├── calibration_service.dart    # Calibration orchestration
│   │   │   ├── gait_feature_extractor.dart # Feature extraction
│   │   │   ├── gait_recognizer.dart        # Recognition engines
│   │   │   ├── ml_pipeline_service.dart    # ML pipeline orchestration
│   │   │   ├── authentication_service.dart # Auth decision logic
│   │   │   └── app_lock_service.dart       # App protection service
│   │   ├── theme/                      # Material 3 theming
│   │   └── utils/                      # Utilities (password hashing, etc.)
│   │
│   ├── data/                           # Data access layer
│   │   ├── datasources/                # Local data sources
│   │   │   └── local/                  # SQLite implementations
│   │   ├── models/                     # Data models (12+ models)
│   │   │   ├── user.dart
│   │   │   ├── calibration_session.dart
│   │   │   ├── calibration_baseline.dart
│   │   │   ├── gait_features.dart
│   │   │   ├── sensor_reading.dart
│   │   │   ├── protected_app.dart
│   │   │   ├── app_lock_session.dart
│   │   │   ├── recognition_result.dart
│   │   │   └── authentication_decision.dart
│   │   └── repositories/               # Repository implementations
│   │
│   ├── features/                       # Feature modules
│   │   ├── auth/                       # Authentication feature
│   │   │   ├── logic/                  # AuthCubit + states
│   │   │   └── ui/                     # Login/Register screens
│   │   ├── gait/                       # Gait recognition feature
│   │   │   ├── logic/                  # Calibration/Recognition cubits
│   │   │   └── ui/                     # Calibration/Recognition screens
│   │   ├── app_lock/                   # App locking feature
│   │   │   ├── logic/                  # AppLockCubit + states
│   │   │   └── ui/                     # AppLock screen
│   │   ├── home/                       # Home/Dashboard
│   │   ├── profile/                    # User profile
│   │   └── settings/                   # App settings
│   │
│   ├── navigation/                     # App routing
│   ├── widgets/                        # Shared UI components
│   └── main.dart                       # App entry point
│
├── test/                               # Test suite
│   ├── auth_repository_test.dart
│   ├── password_hasher_test.dart
│   ├── gait_recognition_test.dart
│   ├── calibration_test.dart
│   └── ...                             # 11 test files total
│
├── android/                            # Android platform code
├── ios/                                # iOS platform code
└── pubspec.yaml                        # Dependencies
```

---

## Local-Only Security Model

GaitGuard is designed with a privacy-first approach. All data remains on the device with no cloud connectivity.

### Password Security

```dart
// Implementation: lib/core/utils/password_hasher.dart

Password Storage:
├── Random salt generation (16 bytes, base64 encoded)
├── SHA-256 hashing (salt + password)
├── Constant-time comparison (timing attack prevention)
└── No plaintext storage
```

### Gait Authentication

```dart
// Configuration: lib/core/services/authentication_service.dart

Security Levels:
┌──────────────┬────────────────────┬─────────────────────┐
│ Level        │ Confidence Thresh  │ Max Calibration Age │
├──────────────┼────────────────────┼─────────────────────┤
│ Production   │ 0.70               │ 90 days             │
│ Lenient      │ 0.50               │ 180 days            │
│ Strict       │ 0.85               │ 30 days             │
└──────────────┴────────────────────┴─────────────────────┘
```

### Baseline Comparison (Weighted Scoring)

| Feature | Weight | Tolerance |
|---------|--------|-----------|
| Step Frequency | 25% | ±0.3 Hz |
| Step Regularity | 20% | ±0.2 |
| Acceleration Variance | 20% | ±0.5 |
| Gyroscope Variance | 15% | ±0.5 |
| Step Intensity | 10% | ±0.2 |
| Walking Pattern | 10% | Exact match |

### Authentication Decision Types

```dart
enum AuthenticationDecisionType {
  success,              // Gait matched, confidence above threshold
  confidenceTooLow,     // Below minimum threshold
  patternNotMatched,    // Different walking pattern detected
  insufficientData,     // Too few sensor readings
  baselineNotFound,     // No calibration baseline exists
  calibrationTooOld,    // Baseline exceeds maximum age
  systemError           // Technical failure
}
```

### Data Storage

- **Credentials**: Salted SHA-256 hashes (never plaintext)
- **Sensor Data**: Raw readings stored locally in SQLite
- **Features**: JSON serialized gait features
- **Recognition History**: Confidence scores and metadata only
- **No PII Transmission**: Zero network calls for user data

---

## Gait ML Pipeline

The gait recognition system is a complete biometric pipeline from sensor data collection to authentication decisions.

### Pipeline Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Sensor Data    │────▶│    Feature      │────▶│   Recognition   │
│  Collection     │     │   Extraction    │     │     Engine      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
   Accelerometer          6 Gait Features         Confidence
   + Gyroscope            + Pattern Type            Score
   (50Hz sampling)                                    │
                                                      ▼
                                              ┌─────────────────┐
                                              │  Authentication │
                                              │    Decision     │
                                              └─────────────────┘
```

### 1. Sensor Data Collection

```dart
// lib/core/services/sensor_service.dart

SensorReading {
  AccelerometerData: x, y, z, magnitude
  GyroscopeData: x, y, z (rotational)
  timestamp: DateTime (synchronized)
}

- Sampling rate: Configurable (default 50Hz)
- Synchronization: Accelerometer + Gyroscope timestamp alignment
- Buffering: Configurable window size (default 5 seconds)
```

### 2. Feature Extraction

```dart
// lib/core/services/gait_feature_extractor.dart

GaitFeatures {
  stepFrequency:        // Steps per second (1.5-2.5 Hz typical)
  stepRegularity:       // Timing consistency (0.0-1.0)
  accelerationVariance: // Movement magnitude variation
  gyroscopeVariance:    // Rotational variation
  stepIntensity:        // Average movement strength
  walkingPattern:       // Classification enum
  windowDuration:       // Analysis window (default 5s)
}
```

**Extraction Algorithm:**
1. **Step Detection**: Peak detection on accelerometer Z-axis
2. **Frequency Calculation**: Steps / time window
3. **Regularity**: Coefficient of variation of step intervals
4. **Variance**: Statistical variance of magnitude readings
5. **Pattern Classification**: Asymmetry detection for walking style

### 3. Recognition Engines

**Heuristic Recognizer (Current)**
```dart
// lib/core/services/gait_recognizer.dart

Scoring Weights:
├── Step Frequency:  25%
├── Step Regularity: 20%
├── Step Intensity:  15%
├── Walking Pattern: 20%
└── Variance Match:  20%

Output: Confidence score (0.0-1.0)
```

**ML Recognizer (Stub for Future)**
```dart
// Placeholder for TensorFlow Lite integration
- Model loading from file path
- Trainable from calibration data
- Higher accuracy potential
```

### 4. Walking Pattern Types

```dart
enum GaitPatternType {
  normal,     // Regular, symmetrical gait
  irregular,  // Inconsistent timing
  limping,    // Asymmetric step pattern
  shuffling,  // Short, dragging steps
  unknown     // Insufficient data
}
```

---

## SQLite Schema

Database: `gait_guard.db` (Version 5)
Location: Application Documents Directory

### Entity Relationship Diagram

```
┌─────────────┐       ┌─────────────────────┐       ┌─────────────────┐
│   USERS     │───┬──▶│ CALIBRATION_SESSIONS│──────▶│CALIBRATION_     │
│             │   │   │                     │       │READINGS         │
└─────────────┘   │   └─────────────────────┘       └─────────────────┘
      │           │
      │           ├──▶┌─────────────────────┐       ┌─────────────────┐
      │           │   │     ML_MODELS       │◀──────│ TRAINING_DATA   │
      │           │   └─────────────────────┘       └─────────────────┘
      │           │           │
      │           │           ▼
      │           │   ┌─────────────────────┐
      │           ├──▶│ RECOGNITION_RESULTS │
      │           │   └─────────────────────┘
      │           │
      │           ├──▶┌─────────────────────┐
      │           │   │   PROTECTED_APPS    │
      │           │   └─────────────────────┘
      │           │
      │           └──▶┌─────────────────────┐
      │               │ APP_LOCK_SESSIONS   │
      │               └─────────────────────┘
      │
      └──────────────▶┌─────────────────────┐
                      │      PROFILES       │
                      └─────────────────────┘
```

### Table Schemas

#### users
```sql
CREATE TABLE users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

#### profiles
```sql
CREATE TABLE profiles(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER UNIQUE NOT NULL,
  first_name TEXT,
  last_name TEXT,
  display_name TEXT,
  bio TEXT,
  phone_number TEXT,
  date_of_birth TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
```

#### calibration_sessions
```sql
CREATE TABLE calibration_sessions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  type TEXT NOT NULL,              -- 'Fast', 'Standard', 'Extended'
  status TEXT NOT NULL,            -- 'active', 'completed', 'error'
  start_time TEXT NOT NULL,
  end_time TEXT,
  expected_duration_ms INTEGER,
  reading_count INTEGER DEFAULT 0,
  quality_score REAL DEFAULT 0.0,
  error_message TEXT,
  metadata TEXT,                   -- JSON blob
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
```

#### calibration_readings
```sql
CREATE TABLE calibration_readings(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  accel_x REAL NOT NULL,
  accel_y REAL NOT NULL,
  accel_z REAL NOT NULL,
  gyro_x REAL NOT NULL,
  gyro_y REAL NOT NULL,
  gyro_z REAL NOT NULL,
  is_synchronized INTEGER DEFAULT 1,
  FOREIGN KEY (session_id) REFERENCES calibration_sessions (id) ON DELETE CASCADE
);
```

#### ml_models
```sql
CREATE TABLE ml_models(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  model_type TEXT NOT NULL,        -- 'heuristic', 'ml'
  model_version TEXT NOT NULL,
  model_path TEXT,
  is_active INTEGER DEFAULT 1,
  accuracy REAL,
  performance REAL,
  metadata TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
```

#### recognition_results
```sql
CREATE TABLE recognition_results(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  model_id INTEGER,
  features TEXT,                   -- JSON serialized GaitFeatures
  is_match INTEGER NOT NULL,
  confidence REAL NOT NULL,
  pattern_type TEXT NOT NULL,
  recognition_timestamp TEXT NOT NULL,
  metadata TEXT,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (model_id) REFERENCES ml_models (id) ON DELETE SET NULL
);
```

#### protected_apps
```sql
CREATE TABLE protected_apps(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  package_name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  icon_code_point INTEGER,
  is_protected INTEGER DEFAULT 0,
  is_locked INTEGER DEFAULT 0,
  last_unlock_time TEXT,
  lock_count INTEGER DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, package_name),
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
```

#### app_lock_sessions
```sql
CREATE TABLE app_lock_sessions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  package_name TEXT NOT NULL,
  lock_status TEXT NOT NULL,       -- 'locked', 'unlocked', 'authenticating'
  locked_at TEXT NOT NULL,
  unlocked_at TEXT,
  unlock_confidence REAL,
  unlock_attempts INTEGER DEFAULT 0,
  metadata TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
```

#### training_data
```sql
CREATE TABLE training_data(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  model_id INTEGER,
  features TEXT NOT NULL,          -- JSON serialized GaitFeatures
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (model_id) REFERENCES ml_models (id) ON DELETE SET NULL
);
```

---

## Running the App

### Prerequisites

- Flutter SDK 3.10.3 or higher
- Android Studio / Xcode (for emulators)
- Physical device recommended (for real sensor data)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd GaitGaurd

# Install dependencies
flutter pub get

# Check Flutter setup
flutter doctor
```

### Running on Device/Emulator

```bash
# List available devices
flutter devices

# Run in debug mode
flutter run

# Run on specific device
flutter run -d <device-id>

# Run in release mode
flutter run --release
```

### Building

```bash
# Android APK
flutter build apk

# Android App Bundle
flutter build appbundle

# iOS (requires macOS)
flutter build ios
```

### Environment Notes

- **Physical Device Recommended**: Sensor data is simulated on emulators
- **Android**: Requires API level 21+ (Android 5.0)
- **iOS**: Requires iOS 12.0+
- **Permissions**: App requests motion sensor permissions on first launch

---

## Running Tests

### Test Suite Overview

The test suite includes unit tests for core functionality:

| Test File | Coverage |
|-----------|----------|
| `auth_repository_test.dart` | Authentication, registration, login |
| `password_hasher_test.dart` | Password hashing, salt generation, verification |
| `gait_recognition_test.dart` | Recognizer scoring, pattern classification |
| `calibration_test.dart` | Session lifecycle, progress tracking |
| `calibration_error_test.dart` | Error handling, recovery actions |
| `gait_collection_test.dart` | Sensor data collection, validation |
| `calibration_performance_test.dart` | Large dataset handling (10k+ readings) |
| `mock_sensor_service_test.dart` | Mock sensor behavior |
| `sensor_stream_integration_test.dart` | Stream handling, cleanup |
| `profile_repository_test.dart` | Profile CRUD operations |

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/auth_repository_test.dart

# Run with coverage
flutter test --coverage

# Run with verbose output
flutter test --reporter expanded
```

### Testing Strategy

- **Unit Tests**: Business logic isolation (repositories, services)
- **Mock Data Sources**: Database-independent testing
- **Stream Testing**: Real-time feature verification
- **Performance Testing**: Large dataset handling
- **Edge Cases**: Error conditions and recovery

---

## MVP Limitations

The current implementation is a Minimum Viable Product with the following limitations:

### Authentication

| Limitation | Description |
|------------|-------------|
| SHA-256 Hashing | Not production-grade; should use bcrypt/Argon2 |
| No Session Tokens | Direct authentication without JWT/session management |
| No Password Reset | Missing password recovery flow |
| No Multi-Factor Auth | Gait-only authentication |

### Gait Recognition

| Limitation | Description |
|------------|-------------|
| Heuristic-Only | No trained ML model; rule-based recognition |
| Single Walking Style | Doesn't adapt to footwear, terrain, or injury |
| No Continuous Auth | Recognition triggered manually, not continuous |
| Fixed Thresholds | Confidence thresholds not user-adaptive |

### App Locking

| Limitation | Description |
|------------|-------------|
| Mock App List | Uses hardcoded app list; no real device app enumeration |
| No Native Integration | Cannot actually lock/unlock real apps |
| No Background Service | Requires app to be in foreground |
| No Accessibility Service | Missing Android accessibility integration |

### Data & Storage

| Limitation | Description |
|------------|-------------|
| No Backup/Export | User data cannot be backed up or transferred |
| No Encryption at Rest | SQLite database is not encrypted |
| No Data Migration | Limited database version migration support |

### Platform

| Limitation | Description |
|------------|-------------|
| Emulator Support | Sensors produce mock data on emulators |
| iOS Limitations | Full implementation focused on Android |
| No Wearable Support | Doesn't integrate with smartwatches |

---

## Future Improvements

### Phase 1: Security Hardening

- [ ] Implement bcrypt/Argon2 for password hashing
- [ ] Add SQLCipher for database encryption
- [ ] Implement secure session tokens with expiration
- [ ] Add biometric fallback (fingerprint/face) for auth failures

### Phase 2: ML Enhancement

- [ ] Integrate TensorFlow Lite for on-device ML
- [ ] Train personalized gait models per user
- [ ] Implement continuous background authentication
- [ ] Add adaptive thresholds based on user history
- [ ] Support multiple gait profiles (walking, running, with bag)

### Phase 3: App Lock Integration

- [ ] Android accessibility service for real app locking
- [ ] Real device app enumeration via platform channels
- [ ] Background service for continuous monitoring
- [ ] Lock screen overlay for protected app access

### Phase 4: Platform Features

- [ ] WearOS/watchOS integration for sensor data
- [ ] Cloud backup with end-to-end encryption
- [ ] Cross-device gait profile sync
- [ ] Widget for quick lock/unlock status

### Phase 5: UX Improvements

- [ ] Onboarding tutorial for gait calibration
- [ ] Real-time gait visualization during calibration
- [ ] Detailed authentication analytics dashboard
- [ ] Customizable security policies per app

### Phase 6: Advanced Recognition

- [ ] Multi-modal biometrics (gait + typing pattern)
- [ ] Context-aware authentication (location, time)
- [ ] Anomaly detection for unusual gait patterns
- [ ] Health monitoring features (gait-based health insights)

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^9.0.0 | State management (BLoC/Cubit) |
| `sqflite` | ^2.3.3+1 | SQLite database |
| `path_provider` | ^2.1.4 | File system access |
| `equatable` | ^2.0.7 | Value equality for states |
| `sensors_plus` | ^6.1.1 | Accelerometer/Gyroscope access |
| `crypto` | ^3.0.6 | SHA-256 password hashing |
| `intl` | ^0.19.0 | Internationalization |

---

## License

[Add your license here]

---

## Contributing

[Add contribution guidelines here]
