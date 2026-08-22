import '../database/local_database.dart';
import '../models/local_prediction.dart';
import 'local_prediction_store.dart';

class SqflitePredictionStore implements LocalPredictionStore {
  static const String tableName = 'local_predictions';

  @override
  Future<int> insertPrediction(LocalPrediction prediction) async {
    final db = await LocalDatabase.instance.database;
    return db.insert(tableName, prediction.toMap());
  }

  @override
  Future<List<LocalPrediction>> getPredictions() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query(tableName, orderBy: 'created_at DESC');
    return result.map(LocalPrediction.fromMap).toList();
  }

  @override
  Future<int> deletePrediction(int id) async {
    final db = await LocalDatabase.instance.database;
    return db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> clearPredictions() async {
    final db = await LocalDatabase.instance.database;
    return db.delete(tableName);
  }

  @override
  Future<int> updateExplanation(int id, String explanation) async {
    final db = await LocalDatabase.instance.database;
    return db.update(
      tableName,
      {'explanation': explanation},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
