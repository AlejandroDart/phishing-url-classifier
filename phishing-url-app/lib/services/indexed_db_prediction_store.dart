import 'package:idb_shim/idb_browser.dart';

import '../models/local_prediction.dart';
import 'local_prediction_store.dart';

class IndexedDbPredictionStore implements LocalPredictionStore {
  static const String databaseName = 'linkshield_local_history';
  static const String storeName = 'local_predictions';
  static const int databaseVersion = 1;

  Database? _database;

  Future<Database> get _db async {
    final current = _database;
    if (current != null) return current;

    final database = await idbFactoryBrowser.open(
      databaseName,
      version: databaseVersion,
      onUpgradeNeeded: (event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(storeName)) {
          db.createObjectStore(
            storeName,
            keyPath: 'id',
            autoIncrement: true,
          );
        }
      },
    );
    _database = database;
    return database;
  }

  @override
  Future<int> insertPrediction(LocalPrediction prediction) async {
    final db = await _db;
    final transaction = db.transaction(storeName, idbModeReadWrite);
    final values = Map<String, dynamic>.from(prediction.toMap())..remove('id');
    final key = await transaction.objectStore(storeName).add(values);
    await transaction.completed;
    return (key as num).toInt();
  }

  @override
  Future<List<LocalPrediction>> getPredictions() async {
    final db = await _db;
    final transaction = db.transaction(storeName, idbModeReadOnly);
    final records = await transaction.objectStore(storeName).getAll();
    await transaction.completed;

    final predictions = records
        .whereType<Map>()
        .map((record) =>
            LocalPrediction.fromMap(Map<String, dynamic>.from(record)))
        .toList();
    predictions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return predictions;
  }

  @override
  Future<int> deletePrediction(int id) async {
    final db = await _db;
    final transaction = db.transaction(storeName, idbModeReadWrite);
    final store = transaction.objectStore(storeName);
    final existing = await store.getObject(id);
    if (existing == null) {
      await transaction.completed;
      return 0;
    }

    await store.delete(id);
    await transaction.completed;
    return 1;
  }

  @override
  Future<int> clearPredictions() async {
    final db = await _db;
    final transaction = db.transaction(storeName, idbModeReadWrite);
    final store = transaction.objectStore(storeName);
    final keys = await store.getAllKeys();
    await store.clear();
    await transaction.completed;
    return keys.length;
  }

  @override
  Future<int> updateExplanation(int id, String explanation) async {
    final db = await _db;
    final transaction = db.transaction(storeName, idbModeReadWrite);
    final store = transaction.objectStore(storeName);
    final existing = await store.getObject(id);
    if (existing is! Map) {
      await transaction.completed;
      return 0;
    }

    final updated = Map<String, dynamic>.from(existing)
      ..['explanation'] = explanation;
    await store.put(updated);
    await transaction.completed;
    return 1;
  }
}
