import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Simple singleton wrapper around the app's SQLite database.
///
/// Centralizing the database instance keeps connection management in one place
/// and makes it easier to evolve the schema over time.
class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'gait_guard.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addProfileTable(db);
        }
        if (oldVersion < 3) {
          await _addCalibrationTables(db);
        }
        if (oldVersion < 4) {
          await _addMLModelTables(db);
        }
        if (oldVersion < 5) {
          await _addAppLockTables(db);
        }
      },
    );
  }

  /// Create initial database schema for fresh installs
  Future<void> _createSchema(Database db) async {
    // Users table
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Add all other tables
    await _addProfileTable(db);
    await _addCalibrationTables(db);
    await _addMLModelTables(db);
    await _addAppLockTables(db);
  }

  Future<void> _addCalibrationTables(Database db) async {
    // Calibration sessions table
    await db.execute('''
      CREATE TABLE calibration_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        expected_duration_ms INTEGER,
        reading_count INTEGER DEFAULT 0,
        quality_score REAL DEFAULT 0.0,
        error_message TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Calibration readings table (separate for performance)
    await db.execute('''
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
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_calibration_sessions_user_id ON calibration_sessions(user_id)');
    await db.execute('CREATE INDEX idx_calibration_sessions_status ON calibration_sessions(status)');
    await db.execute('CREATE INDEX idx_calibration_readings_session_id ON calibration_readings(session_id)');
    await db.execute('CREATE INDEX idx_calibration_readings_timestamp ON calibration_readings(timestamp)');
  }

  Future<void> _addProfileTable(Database db) async {
    await db.execute('''
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
      )
    ''');
  }

  Future<void> _addMLModelTables(Database db) async {
    // ML model metadata table
    await db.execute('''
      CREATE TABLE ml_models(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        model_type TEXT NOT NULL,
        model_version TEXT NOT NULL,
        model_path TEXT,
        is_active INTEGER DEFAULT 1,
        accuracy REAL,
        performance REAL,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Recognition results table
    await db.execute('''
      CREATE TABLE recognition_results(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        model_id INTEGER,
        features TEXT,
        is_match INTEGER NOT NULL,
        confidence REAL NOT NULL,
        pattern_type TEXT NOT NULL,
        recognition_timestamp TEXT NOT NULL,
        metadata TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (model_id) REFERENCES ml_models (id) ON DELETE SET NULL
      )
    ''');

    // Training data table
    await db.execute('''
      CREATE TABLE training_data(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        model_id INTEGER,
        features TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (model_id) REFERENCES ml_models (id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_ml_models_user_id ON ml_models(user_id)');
    await db.execute('CREATE INDEX idx_ml_models_user_type ON ml_models(user_id, model_type)');
    await db.execute('CREATE INDEX idx_recognition_results_user_id ON recognition_results(user_id)');
    await db.execute('CREATE INDEX idx_recognition_results_timestamp ON recognition_results(recognition_timestamp)');
    await db.execute('CREATE INDEX idx_training_data_user_id ON training_data(user_id)');
  }

  Future<void> _addAppLockTables(Database db) async {
    // Protected apps table - stores user's app protection preferences
    await db.execute('''
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
      )
    ''');

    // App lock sessions table - tracks lock/unlock events
    await db.execute('''
      CREATE TABLE app_lock_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        package_name TEXT NOT NULL,
        lock_status TEXT NOT NULL,
        locked_at TEXT NOT NULL,
        unlocked_at TEXT,
        unlock_confidence REAL,
        unlock_attempts INTEGER DEFAULT 0,
        metadata TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_protected_apps_user_id ON protected_apps(user_id)');
    await db.execute('CREATE INDEX idx_protected_apps_package ON protected_apps(package_name)');
    await db.execute('CREATE INDEX idx_app_lock_sessions_user_id ON app_lock_sessions(user_id)');
    await db.execute('CREATE INDEX idx_app_lock_sessions_package ON app_lock_sessions(package_name)');
    await db.execute('CREATE INDEX idx_app_lock_sessions_status ON app_lock_sessions(lock_status)');
  }
}


