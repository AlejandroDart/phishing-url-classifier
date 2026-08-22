import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();

  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('local_phishing_history.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_predictions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        label TEXT NOT NULL,
        probability REAL NOT NULL,
        explanation TEXT,
        model_id TEXT NOT NULL DEFAULT 'random_forest',
        model_name TEXT NOT NULL DEFAULT 'Random Forest Top 25',
        sensitivity_profile TEXT NOT NULL DEFAULT 'balanced',
        base_threshold REAL NOT NULL DEFAULT 0.5,
        effective_threshold REAL NOT NULL DEFAULT 0.5,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE local_predictions ADD COLUMN model_id TEXT NOT NULL DEFAULT 'random_forest'",
      );
      await db.execute(
        "ALTER TABLE local_predictions ADD COLUMN model_name TEXT NOT NULL DEFAULT 'Random Forest Top 25'",
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE local_predictions ADD COLUMN sensitivity_profile TEXT NOT NULL DEFAULT 'balanced'",
      );
      await db.execute(
        "ALTER TABLE local_predictions ADD COLUMN base_threshold REAL NOT NULL DEFAULT 0.5",
      );
      await db.execute(
        "ALTER TABLE local_predictions ADD COLUMN effective_threshold REAL NOT NULL DEFAULT 0.5",
      );
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
